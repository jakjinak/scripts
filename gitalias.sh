alias GS='git status'
alias GA='git add'
alias GC='git commit'
alias GB='git branch'
alias GL='git log --pretty=format:"%C(bold cyan)%H %h%Creset %Cred%ai %C(bold green)%aN%Creset %p%n    %s"'
alias GLsq='git log --pretty=format:"pick %C(bold cyan)%h%Creset %s"'
alias GD='git diff'
alias GUD='function MYGITDIFFTEXT() ( unset GIT_EXTERNAL_DIFF ; git diff "$@" ) ; MYGITDIFFTEXT'
# show changes in a commit (1st arg); either all files in commit or a particular one (2nd+ arg)
alias GDC='function MYGITDIFFCOMMIT() { local commit="$1"; shift; git diff "$commit^" "$commit" "$@"; } ; MYGITDIFFCOMMIT'
alias GUDC='function MYGITDIFFCOMMITEXT() ( unset GIT_EXTERNAL_DIFF ; local commit="$1"; shift; git diff "$commit^" "$commit" "$@" ) ; MYGITDIFFCOMMITEXT'
alias Gco='git checkout'
# checkout a branch and associate it with its remote counterpart: 1st arg is branch, 2nd arg (optional) the remote name (default is origin)
alias Gcorb='function MYGITCHECKOUTREMOTEBRANCH() { local origin=origin ; [ "$2" ] && origin="$2" ; git checkout -b "$1" "remotes/origin/$1" ; } ; MYGITCHECKOUTREMOTEBRANCH'
# pulls remote changes (all by default if no args given) or can be tweaked by parameters, prunes deleted branches
alias Gpul='function MYGITPULL() { git pull "$@" ; git fetch -p ; } ; MYGITPULL'
# pushes current branch to default remote (if no args given) or can be tweaked by parameters
alias Gpus='function MYGITPUSH() { local force="" ; [[ "$1" == "-f" || "$1" == "--force" ]] && force=-f && shift ; if [[ $# -eq 0 ]] ; then git push $force origin "$(git rev-parse --abbrev-ref HEAD)" ; else git push "$@" ; fi ; } ; MYGITPUSH'
# checkouts the previous version of given file (meant to be used for files accidentally deleted but works in other cases too)
alias Grevertdeleted='function MYGITREVERTDELETED() { [[ -z "$1" ]] && return 1 ; git checkout $(git rev-list -n 1 HEAD -- "$1")^ -- "$1" ; } ; MYGITREVERTDELETED'
# invokes the "squash" dialog for given number of recent commits
alias Gsquash='function MYGITSQUASH() { [[ -z "$1" ]] && return 1 ; git rebase -i HEAD~$1 ; } ; MYGITSQUASH'
# invokes git diff for a given list of files (without any additional params to diff)
alias GDF='function MYGITDIFFFILES() { local f ; for f in "$@" ; do git diff "$f" ; done ; } ; MYGITDIFFFILES'
