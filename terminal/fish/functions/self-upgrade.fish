function self-upgrade
   softwareupdate --install --all
   brew update && brew upgrade && brew autoremove && brew cleanup
   composer global update --optimize-autoloader --classmap-authoritative
end
