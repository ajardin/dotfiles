if status is-interactive
    # Commands to run in interactive sessions can go here
end

# System environment variables
set --export HIST_STAMPS "yyyy-mm-dd"
set --export LANG "en_US.UTF-8"
set --export LC_CTYPE "UTF-8"

# Composer environment variables
set --export COMPOSE_HTTP_TIMEOUT 3600
set --export COMPOSER_MEMORY_LIMIT -1

# AWS environment variables
set --export --global AWS_REGION "eu-west-1"

# PATH customization
eval (/opt/homebrew/bin/brew shellenv)
fish_add_path --prepend "$HOME/.local/bin"
fish_add_path --prepend "$HOME/.composer/vendor/bin"
fish_add_path --prepend "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"

# pnpm
set -gx PNPM_HOME "$HOME/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
