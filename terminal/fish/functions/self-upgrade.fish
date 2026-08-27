function self-upgrade
   brew update && brew upgrade --no-ask && brew autoremove && brew cleanup
   composer global update --optimize-autoloader --classmap-authoritative
   pnpm self-update
end
