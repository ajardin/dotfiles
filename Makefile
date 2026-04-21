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
	brew bundle install --file="${makefile_directory}/homebrew/Brewfile" --verbose
.PHONY: homebrew

terminal: ## Deploys the configuration of the terminal
	# Fish
	mkdir -p "${HOME}/.config/fish"
	ln -sf "${makefile_directory}/terminal/fish/config.fish" "${HOME}/.config/fish/config.fish"
	mkdir -p "${HOME}/.config/fish/functions"
	for file in ${makefile_directory}/terminal/fish/functions/*.fish; do \
		ln -sf "$$file" "${HOME}/.config/fish/functions/$$(basename $$file)"; \
	done
	# Warp
	mkdir -p "${HOME}/.warp/themes"
	for file in ${makefile_directory}/terminal/warp/themes/*.yaml; do \
		ln -sf "$$file" "${HOME}/.warp/themes/$$(basename $$file)"; \
	done
.PHONY: terminal

help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
.DEFAULT_GOAL := help
