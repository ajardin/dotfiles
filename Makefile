##
## ----------------------------------------------------------------------------
##   DOTFILES
## ----------------------------------------------------------------------------
##

makefile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
makefile_directory := $(realpath $(dir $(makefile_path)))

git: ## Deploys the Git configuration files
	ln -sf "${makefile_directory}/git/.gitconfig" "${HOME}/.gitconfig"
	ln -sf "${makefile_directory}/git/.gitconfig-opensource" "${HOME}/.gitconfig-opensource"
	touch "${HOME}/.gitconfig-corporate"
	ln -sf "${makefile_directory}/git/.gitignore" "${HOME}/.gitignore"
.PHONY: git

homebrew: ## Installs Homebrew and the latest version of its packages
	@command -v brew > /dev/null || /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
	export HOMEBREW_REPOSITORY="" && \
	eval "$$(/opt/homebrew/bin/brew shellenv)" && \
	brew update && \
	brew bundle install --file="${makefile_directory}/macos/Brewfile" --verbose
.PHONY: homebrew

macos: ## Installs all required software and some tweaks for macOS
	xcode-select --print-path > /dev/null || xcode-select --install
	softwareupdate --install-rosetta
	bash "${makefile_directory}/macos/configure.sh"
.PHONY: macos

ohmyzsh: ## Installs Oh My Zsh if needed and deploys its configuration files
	test -d "${HOME}/.oh-my-zsh" || sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	mkdir -p "${HOME}/.oh-my-zsh/custom"
	ln -sf "${makefile_directory}/oh-my-zsh/aliases.zsh" "${HOME}/.oh-my-zsh/custom/aliases.zsh"
	ln -sf "${makefile_directory}/oh-my-zsh/theme.zsh" "${HOME}/.oh-my-zsh/custom/theme.zsh"
	cp -n "${makefile_directory}/oh-my-zsh/variables.zsh" "${HOME}/.oh-my-zsh/custom/variables.zsh" || test -f "${HOME}/.oh-my-zsh/custom/variables.zsh"
.PHONY: ohmyzsh

zsh: ## Deploys the ZSH configuration file
	ln -sf "${makefile_directory}/oh-my-zsh/.zshrc" "${HOME}/.zshrc"
.PHONY: zsh

help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
.DEFAULT_GOAL := help
