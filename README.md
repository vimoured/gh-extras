# gh-extras

GitHub pull requests from Vim, through [gh](https://cli.github.com): list and
check out open PRs, look back through merged ones, read and answer review
threads, and post review comments as a pending review.

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

Optional, each for the commands it adds:

| Also needs | Adds |
| --- | --- |
| [vim-draft](https://github.com/vimoured/vim-draft) | `:ReplyDraft` |
| [fugitive-extras](https://github.com/vimoured/fugitive-extras) + [vim-place](https://github.com/vimoured/vim-place) | `:CommentsSubmit`, and a warning about unsaved comments when checking out a PR |
| fugitive-extras + vim-place + [vim-review](https://github.com/vimoured/vim-review) | Submitting a review saved earlier (`:CommentsLoad`, then `:CommentsSubmit`) |

## Use

| Command | What it does |
| --- | --- |
| `:PRs [count]` | Open pull requests, most recently updated first. |
| `:MergedPRs [count]` | Merged pull requests, most recently merged first. |
| `:Thread [number]` | Review threads on the branch's PR, or PR `number`. |
| `:Threads` | Threads you're in across the repo's open PRs. |
| `:Reply [text]` | In a thread list: reply to the thread under the cursor. |
| `:ReplyDraft [text]` | In a thread list: write the reply in a draft; closing it posts it. |
| `:CommentsSubmit [number]` | Post fugitive-extras' comments as one pending review of `HEAD`. |

Keys in the PR lists:

| Key | What it does |
| --- | --- |
| `<CR>` | `:PRs`: check the PR out. `:MergedPRs`: open its merge commit. |
| `t` | Show its review threads. |
| `o` | Open it in the browser. |
| `/` | Filter as you type. |
| `r` / `q` | Refresh / close. |

Keys in the thread lists:

| Key | What it does |
| --- | --- |
| `<CR>` | Open the file at the thread's line. |
| `=` | Open or close the conversation. |
| `x` | Resolve or unresolve. |
| `u` | Show or hide resolved threads. |
| `o` | Open the PR in the browser. |
| `/` | Filter as you type. |
| `r` / `q` | Refresh / close. |

Bind replying to keys in thread lists:

```vim
autocmd BufEnter gh-extras://thread* nmap <buffer> <leader>cc <Plug>(gh-extras-reply)
autocmd BufEnter gh-extras://thread* nmap <buffer> <leader>cd <Plug>(gh-extras-reply-draft)
```

To show readable names in the lists, point `g:gh_extras_pr_authors` at a file of
`name:login` lines (default `~/.config/gh-pr-authors.txt`).

## Tests

The specs in [vim-suite](https://github.com/vimoured/vim-suite) define what it
does: `test/gh-extras.vim`.
