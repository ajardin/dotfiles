alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules --exclude vendor"
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias ll='ls -Glha'
alias mypath='echo -e ${PATH//:/\\n} | sort --unique'
alias ping='prettyping --nolegend'

self-upgrade() {
    softwareupdate --install --all && \
    brew update && brew upgrade && brew autoremove && brew cleanup && \
    omz update && \
    composer global update --optimize-autoloader --classmap-authoritative && \
    yarn global upgrade
}
