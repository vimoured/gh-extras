# gh-extras

GitHub pull requests from Vim, through [gh](https://cli.github.com):

- List and check out open PRs
- Look back through merged PRs
- Read and answer review threads
- Post review comments as a pending review

**Vim or Neovim:** tested on Vim 9.1 and newer. It's plain Vimscript, so it may
work on Neovim, but that's untested.

## Install

Needs [gh](https://cli.github.com), installed and logged in,
[vim-fugitive](https://github.com/tpope/vim-fugitive) and
[vim-lists](https://github.com/vimoured/vim-lists).

```vim
Plug 'tpope/vim-fugitive'
Plug 'vimoured/vim-lists'
Plug 'vimoured/gh-extras'
```

Optional features:

| Feature | What you get | Also needs |
| --- | --- | --- |
| Draft replies | `:ReplyDraft` | [vim-draft](https://github.com/vimoured/vim-draft) |
| Review comments | `:CommentsSubmit`, and a warning about unsaved comments when checking out a PR | [fugitive-extras](https://github.com/vimoured/fugitive-extras), [vim-place](https://github.com/vimoured/vim-place) |
| Saved reviews | Submit a review saved earlier (`:CommentsLoad`, then `:CommentsSubmit`) | fugitive-extras, vim-place, [vim-review](https://github.com/vimoured/vim-review) |

## Use

### Pull requests

| Command | What it does |
| --- | --- |
| `:PRs [count]` | Open pull requests, most recently updated first. |
| `:MergedPRs [terms]` | Merged pull requests, most recently merged first, that the terms find. |

`:MergedPRs` sends its terms to GitHub's search, so they filter what's fetched,
not only what's shown:

- `@who`: by that author. `who` is a login, or a name from [the authors
  file](#author-names), in any case: the whole name without its spaces
  (`@miradev`), or a first name only one author there has (`@mira`).
- `>2026-10-01`, `<2026-10-31` (also `>=`, `<=`): merged after or before that
  date.
- A number: how many to fetch (default 50, at most 100).
- Anything else as typed: words to find in the PR, `"a phrase"`, or
  any of GitHub's own qualifiers (`label:bug`, `base:main`, `-author:bot`).

```vim
:MergedPRs @mira >2026-10-01 login
```

Keys in the PR lists:

| Key | What it does |
| --- | --- |
| `<CR>` | `:PRs`: check the PR out. `:MergedPRs`: open its merge commit. |
| `t` | Show its review threads. |
| `o` | Open it in the browser. |
| `/` | Filter as you type. |
| `r` / `q` | Refresh / close. |

### Review threads

| Command | What it does |
| --- | --- |
| `:Thread [number]` | Review threads on the branch's PR, or PR `number`. |
| `:Threads` | Threads you're in across the repo's open PRs. |
| `:Reply [text]` | In a thread list: reply to the thread under the cursor. |
| `:ReplyDraft [text]` | In a thread list: write the reply in a draft; closing it posts it. |

Keys in the thread lists:

| Key | What it does |
| --- | --- |
| `<CR>` | Open the file at the thread's line. |
| `=` | Open or close the conversation. |
| `x` | Resolve or unresolve. |
| `R` | Show or hide resolved threads. |
| `o` | Open the PR in the browser. |
| `/` | Filter as you type. |
| `r` / `q` | Refresh / close. |

Bind replying to keys in thread lists:

```vim
autocmd BufEnter gh-extras://thread* nmap <buffer> <leader>cc <Plug>(gh-extras-reply)
autocmd BufEnter gh-extras://thread* nmap <buffer> <leader>cd <Plug>(gh-extras-reply-draft)
```

### Review comments

`:CommentsSubmit [number]` posts fugitive-extras' comments as one pending review
of `HEAD`.

## Configuration

### Author names

The PR lists show each author's GitHub login. To show a name instead, add it to
`~/.config/gh-pr-authors.txt`, one `name:login` per line:

```text
Mira Dev: mira-d
Sam Lee: sam
# A line starting with # is skipped
```

Logins match in any case, and an author who isn't in the file keeps their login.
`:MergedPRs @who` finds authors by these names too.
To keep the file somewhere else:

```vim
let g:gh_extras_pr_authors = '~/notes/pr-authors.txt'
```

## Tests

The specs in [vim-suite](https://github.com/vimoured/vim-suite) define what it
does: `test/gh-extras.vim`.
