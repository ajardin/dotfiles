# My Dotfiles

The easiest way to use the content of this repository is to clone it on your local machine (e.g. `~/.dotfiles`), and
then run the various setup scripts provided by the `Makefile`. It contains scripts that make it user-friendly. :wink:

> Keep in mind, that these are my personal settings, and you should check that they suit your needs first.

## macOS 
* [macos/Brewfile](/macos/Brewfile) - describes the list of everything I install on my Mac thanks to Homebrew
* [macos/configure.sh](/macos/configure.sh) - triggers the **whole** configuration of my Mac
* [macos/configure_core.sh](/macos/configure_core.sh) - triggers **only the general** configuration of my Mac
* [macos/configure_dock.sh](/macos/configure_dock.sh) - triggers **only the Dock** configuration of my Mac
* [macos/configure_finder.sh](/macos/configure_finder.sh) - triggers **only the Finder** configuration of my Mac

:point_right: If you want to configure everything the same way I did, you can use the `configure.sh` script. Otherwise,
you can still run the `configure_core.sh`, `configure_dock.sh`, or `configure_finder.sh` manually.

## Configuration files
* [git/.gitconfig](/git/.gitconfig) - general settings for Git
* [git/.gitconfig-opensource](/git/.gitconfig-opensource) - open source settings for Git
* [git/.gitconfig-corporate](https://github.com/ajardin/dotfiles) - corporate settings for Git, created as an empty file if not present
* [git/.gitignore](/git/.gitignore) - files and directories that I systematically ignore in my projects
* [oh-my-zsh/.zshrc](/oh-my-zsh/.zshrc) - configuration for ZSH
* [oh-my-zsh/aliases.zsh](/oh-my-zsh/aliases.zsh) - the aliases I use in my terminal
* [oh-my-zsh/theme.zsh](/oh-my-zsh/theme.zsh) - the theme I use in my terminal
* [oh-my-zsh/variables.zsh](/oh-my-zsh/variables.zsh) - variables, with placeholders for sensitive data

:point_right: If you want to use the same configuration as me, you can use the `Makefile` target. Otherwise, you can
just copy the files you want.
