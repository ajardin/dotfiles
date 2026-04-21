function wipe
    git fp
    set default_branch (git symbolic-ref --short refs/remotes/origin/HEAD | string replace 'origin/' '')
    git switch $default_branch
    git reset --hard origin/$default_branch
end
