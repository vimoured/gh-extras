let s:open_query = 'query($owner: String!, $name: String!, $count: Int!) {'
      \ . ' repository(owner: $owner, name: $name) {'
      \ . ' pullRequests(states: OPEN, first: $count,'
      \ . ' orderBy: {field: UPDATED_AT, direction: DESC}) {'
      \ . ' nodes { number title headRefName author { login }'
      \ . ' isDraft updatedAt reviewDecision } } } }'
" Merged PRs are searched for, so the search terms filter them. GitHub can't
" order by merge time; updated time is close, and the fetched PRs are sorted
" by mergedAt
let s:merged_query = 'query($search: String!, $count: Int!) {'
      \ . ' search(query: $search, type: ISSUE, first: $count) {'
      \ . ' nodes { ... on PullRequest { number title headRefName author { login }'
      \ . ' mergedAt mergeCommit { oid } } } } }'

let s:states = {'APPROVED': 'approved', 'CHANGES_REQUESTED': 'changes',
      \ 'REVIEW_REQUIRED': 'review'}

" Cut or padded to width screen cells: printf counts bytes, and names aren't
" all ASCII
function! s:pad(text, width) abort
  let l:text = a:text
  while strdisplaywidth(l:text) > a:width
    let l:text = strcharpart(l:text, 0, strchars(l:text) - 1)
  endwhile
  return l:text . repeat(' ', a:width - strdisplaywidth(l:text))
endfunction

" Who, title and branch are what you filter on, so they come first after the
" number; their widths fit the fetched PRs, so the columns stay put while
" filtering. Age is last: the order already tells it
function! s:format(widths, num, who, title, branch, state, age) abort
  return printf('%-6s %s  %s  %s  %-8s %s', a:num, s:pad(a:who, a:widths[0]),
        \ s:pad(a:title, a:widths[1]), s:pad(a:branch, a:widths[2]), a:state, a:age)
endfunction

" [name, login] for each name:login line of the authors file
function! s:authors() abort
  let l:authors = []
  let l:file = expand(get(g:, 'gh_extras_pr_authors', '~/.config/gh-pr-authors.txt'))
  for l:line in filereadable(l:file) ? readfile(l:file) : []
    let l:m = matchlist(l:line, '^\s*\([^:#[:space:]][^:]\{-}\)\s*:\s*\([^:[:space:]]\+\)\s*$')
    if !empty(l:m)
      call add(l:authors, l:m[1:2])
    endif
  endfor
  return l:authors
endfunction

" The login @who means, in any case: a login in the authors file, a name there
" without its spaces, or a first name only one there has; else who itself.
" A string with an error when the first name is more than one author's
function! s:login(typed) abort
  let l:who = tolower(a:typed[1:])
  let l:authors = s:authors()
  for l:Same in [{name, login -> tolower(login) ==# l:who},
        \ {name, login -> tolower(substitute(name, '\s', '', 'g')) ==# l:who}]
    let l:found = filter(copy(l:authors), {_, a -> l:Same(a[0], a[1])})
    if !empty(l:found)
      return {'login': l:found[0][1]}
    endif
  endfor
  let l:found = []
  for [l:name, l:login] in l:authors
    if tolower(matchstr(l:name, '^\S\+')) ==# l:who
          \ && index(map(copy(l:found), 'tolower(v:val[1])'), tolower(l:login)) < 0
      call add(l:found, [l:name, l:login])
    endif
  endfor
  if len(l:found) > 1
    let l:each = map(l:found, 'v:val[0] . " (" . v:val[1] . ")"')
    return a:typed . ' is ' . join(l:each[:-2], ', ') . ' or ' . l:each[-1]
  endif
  return {'login': empty(l:found) ? a:typed[1:] : l:found[0][1]}
endfunction

" What :MergedPRs was given: a number is the count, @who is author:, >date
" and <date are merged:, the rest (a "quoted phrase" one term) goes to
" GitHub's search as typed. {'count', 'search', 'typed'}, or a string with an
" error
function! s:terms(args) abort
  let l:count = ''
  let l:search = []
  let l:typed = []
  let l:words = []
  call substitute(a:args, '\%([^[:space:]"]\+\|"[^"]*"\=\)\+',
        \ '\=add(l:words, submatch(0))[-1]', 'g')
  for l:word in l:words
    if l:word =~# '^\d\+$'
      let l:count = l:word
      continue
    elseif l:word =~# '^@.'
      let l:who = s:login(l:word)
      if type(l:who) == v:t_string
        return l:who
      endif
      call add(l:search, 'author:' . l:who.login)
    elseif l:word =~# '^[<>]'
      if l:word !~# '^[<>]=\=\d\{4}-\d\d-\d\d$'
        return l:word . ': a date is YYYY-MM-DD'
      endif
      call add(l:search, 'merged:' . l:word)
    else
      call add(l:search, l:word)
    endif
    call add(l:typed, l:word)
  endfor
  return {'count': l:count, 'search': join(l:search), 'typed': join(l:typed)}
endfunction

function! s:fetch() abort
  if b:gh_extras_merged
    " sort: so the count fetched are the latest, as by UPDATED_AT for :PRs
    let l:args = '-F search=' . shellescape(trim('sort:updated-desc'
          \ . ' repo:{owner}/{repo} is:pr is:merged ' . b:gh_extras_search))
          \ . ' -f query=' . shellescape(s:merged_query)
  else
    let l:args = '-F owner={owner} -F name={repo} -f query=' . shellescape(s:open_query)
  endif
  let l:out = gh_extras#gh(b:gh_extras_worktree, 'api graphql -F count=' . b:gh_extras_count
        \ . ' ' . l:args)
  if l:out is v:null
    return v:null
  endif
  " Parsed here, so jq isn't needed
  let l:data = json_decode(l:out).data
  if b:gh_extras_merged
    let l:prs = l:data.search.nodes
    call sort(l:prs, {a, b -> a.mergedAt <# b.mergedAt ? 1 : a.mergedAt ># b.mergedAt ? -1 : 0})
  else
    let l:prs = l:data.repository.pullRequests.nodes
  endif
  " login -> readable name; keyed lowercase: logins aren't case-sensitive
  let l:names = {}
  for [l:name, l:login] in s:authors()
    let l:names[tolower(l:login)] = l:name
  endfor
  for l:pr in l:prs
    let l:login = type(l:pr.author) == v:t_dict ? l:pr.author.login : 'ghost'
    let l:pr._who = get(l:names, tolower(l:login), l:login)
  endfor
  let b:gh_extras_widths = [
        \ min([20, max([3] + map(copy(l:prs), 'strdisplaywidth(v:val._who)'))]),
        \ min([60, max([5] + map(copy(l:prs), 'strdisplaywidth(v:val.title)'))]),
        \ min([30, max([6] + map(copy(l:prs), 'strdisplaywidth(v:val.headRefName)'))])]
  return l:prs
endfunction

function! s:heading(prs) abort
  let l:merged = b:gh_extras_merged
  return [(l:merged ? 'Merged PRs ' . b:gh_extras_typed : 'Open PRs')
        \   ->trim() . ' (' . len(a:prs) . ')',
        \ s:format(b:gh_extras_widths, '#', 'who', 'title', 'branch',
        \   l:merged ? 'commit' : 'state', l:merged ? 'merged' : 'age')]
endfunction

function! s:rows(prs) abort
  let l:merged = b:gh_extras_merged
  return map(copy(a:prs), {_, pr -> {'item': pr, 'lines': [s:format(b:gh_extras_widths,
        \ '#' . pr.number, pr._who, pr.title, pr.headRefName,
        \ l:merged ? pr.mergeCommit.oid[:6] : pr.isDraft ? 'draft'
        \ : get(s:states, type(pr.reviewDecision) == v:t_string ? pr.reviewDecision : '', '-'),
        \ gh_extras#age(l:merged ? pr.mergedAt : pr.updatedAt))]}})
endfunction

" merged: the merged PRs (default 50) that args, search terms and a count,
" find; else the open ones (default 20), args the count
function! gh_extras#prs#open(args, merged) abort
  let l:worktree = gh_extras#github_worktree(a:merged ? ':MergedPRs' : ':PRs')
  if empty(l:worktree)
    return
  endif
  let l:terms = a:merged ? s:terms(a:args) : {'count': a:args, 'search': '', 'typed': ''}
  if type(l:terms) == v:t_string
    call gh_extras#error(l:terms)
    return
  endif
  call roumail_lists#open('gh-extras://' . (a:merged ? 'merged-prs/' : 'prs/')
        \ . fnamemodify(l:worktree, ':t'), {
        \ 'fetch': function('s:fetch'), 'heading': function('s:heading'),
        \ 'rows': function('s:rows'), 'id': {pr -> pr.number},
        \ 'match': {pr -> pr._who . ' ' . pr.title . ' ' . pr.headRefName},
        \ 'keys': [
        \   {'key': '<CR>', 'hint': a:merged ? 'commit' : 'checkout', 'call': function('s:enter')},
        \   {'key': 't', 'hint': 'threads', 'call': function('s:threads')},
        \   {'key': 'o', 'hint': 'browser', 'call': function('s:browse')}]}, {
        \ 'gh_extras_worktree': l:worktree,
        \ 'gh_extras_gitdir': FugitiveGitDir(),
        \ 'gh_extras_merged': a:merged,
        \ 'gh_extras_search': l:terms.search,
        \ 'gh_extras_typed': l:terms.typed,
        "\ GitHub returns at most 100 at a time
        \ 'gh_extras_count': min([100, empty(l:terms.count) ? (a:merged ? 50 : 20)
        \   : str2nr(l:terms.count)]),
        \ })
endfunction

function! s:number() abort
  return get(roumail_lists#item(), 'number', 0)
endfunction

function! s:enter() abort
  if b:gh_extras_merged
    call s:show_commit()
  else
    call s:checkout()
  endif
endfunction

" The merge commit (or squash commit) in fugitive, in the window above
function! s:show_commit() abort
  let l:pr = roumail_lists#item()
  if empty(l:pr)
    return
  endif
  let l:oid = l:pr.mergeCommit.oid
  call system('git -C ' . shellescape(b:gh_extras_worktree) . ' cat-file -e ' . l:oid . '^{commit}')
  if v:shell_error
    call gh_extras#error('commit ' . l:oid[:6] . ' is not here; :Git fetch first')
    return
  endif
  let l:file = FugitiveFind(l:oid, b:gh_extras_gitdir)
  if winnr('$') == 1
    aboveleft split
  else
    wincmd p
  endif
  execute 'edit' fnameescape(l:file)
endfunction

function! s:checkout() abort
  let l:number = s:number()
  if !l:number
    return
  endif
  let l:worktree = b:gh_extras_worktree
  if gh_extras#gh(l:worktree, 'pr checkout ' . l:number) is v:null
    return
  endif
  call roumail_lists#close()
  checktime
  echo 'Checked out #' . l:number . ' (:BranchDiff, :BranchCommits to review)'
  if gh_extras#installed('fugitive_extras')
    call fugitive_extras#comments#check()
  endif
endfunction

function! s:threads() abort
  let l:number = s:number()
  if l:number
    call gh_extras#threads#open(l:number, b:gh_extras_worktree)
  endif
endfunction

function! s:browse() abort
  let l:number = s:number()
  if l:number
    call gh_extras#gh(b:gh_extras_worktree, 'pr view --web ' . l:number)
  endif
endfunction
