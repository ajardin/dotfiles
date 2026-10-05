function self-upgrade
   brew update && brew upgrade --no-ask && brew autoremove && brew cleanup
end
