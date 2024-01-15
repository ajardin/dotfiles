function wipe
    git fp
    git switch master
    git reset --hard origin/master
end
