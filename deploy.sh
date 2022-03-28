#!/usr/bin/env bash

# Ensure Homebrew is in PATH
eval "$(/opt/homebrew/bin/brew shellenv)"

directory_path=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# Install the Git configuration files
ln -sf "${directory_path}/git/.gitconfig" "${HOME}/.gitconfig"
ln -sf "${directory_path}/git/.gitconfig-opensource" "${HOME}/.gitconfig-opensource"
ln -sf "${directory_path}/git/.gitignore" "${HOME}/.gitignore"

# Install the Zsh configuration file
ln -sf "${directory_path}/oh-my-zsh/.zshrc" "${HOME}/.zshrc"

# Install the Oh My Zsh configuration files
mkdir -p "${HOME}/.oh-my-zsh/custom"
ln -sf "${directory_path}/oh-my-zsh/aliases.zsh" "${HOME}/.oh-my-zsh/custom/aliases.zsh"
ln -sf "${directory_path}/oh-my-zsh/theme.zsh" "${HOME}/.oh-my-zsh/custom/theme.zsh"

if [ ! -f "${HOME}/.oh-my-zsh/custom/variables.zsh" ]; then
  cp "${directory_path}/oh-my-zsh/variables.zsh" "${HOME}/.oh-my-zsh/custom/variables.zsh"
fi
