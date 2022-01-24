DEFAULT_USER="aja"

ZSH_THEME_GIT_PROMPT_PREFIX=" %{$fg_bold[white]%}on%{$fg_bold[yellow]%} "
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg_bold[yellow]%}%{$reset_color%}"

ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY=""

ZSH_THEME_GIT_PROMPT_ADDED=" (%{$fg_bold[green]%}✚%{$reset_color%})"
ZSH_THEME_GIT_PROMPT_AHEAD=" (%{$fg_bold[cyan]%}▲%{$reset_color%})"
ZSH_THEME_GIT_PROMPT_DELETED=" (%{$fg_bold[red]%}✖%{$reset_color%})"
ZSH_THEME_GIT_PROMPT_MODIFIED=" (%{$fg_bold[red]%}△%{$reset_color%})"
ZSH_THEME_GIT_PROMPT_RENAMED=" (%{$fg_bold[green]%}➜%{$reset_color%})"
ZSH_THEME_GIT_PROMPT_UNMERGED=" (%{$fg_bold[cyan]%}§%{$reset_color%})"
ZSH_THEME_GIT_PROMPT_UNTRACKED=" (%{$fg_bold[red]%}◒%{$reset_color%})"

precmd() { echo "" }
get_short_pwd() { echo "%{$fg_bold[blue]%}${PWD/$HOME/~}%{$reset_color%}" }
PROMPT=" \$(get_short_pwd)\$(git_prompt_info)\$(git_prompt_status) %{$fg_bold[blue]%}❯%{$reset_color%} "
