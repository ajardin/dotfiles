#!/usr/bin/env bash

# Install command line tools without Xcode
xcode-select --install

# Install Rosetta 2
softwareupdate --install-rosetta

# Install Homebrew if not already installed
command -v brew > /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Fetch the newest version of Homebrew and all formulae
brew update

# Install Homebrew packages
directory_path=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
brew bundle install --file="${directory_path}/Brewfile" --verbose

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
