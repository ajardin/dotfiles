##
## ----------------------------------------------------------------------------
##   DOTFILES
## ----------------------------------------------------------------------------
##

makefile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
makefile_directory := $(realpath $(dir $(makefile_path)))

# Upstream of the vendored Claude skills, kept verbatim (see "skills-sync")
skills_repo := https://github.com/mattpocock/skills.git
skills_cache := ${HOME}/.cache/dotfiles/mattpocock-skills
skills_list := engineering/grill-with-docs engineering/domain-modeling \
               engineering/diagnosing-bugs productivity/grilling \
               productivity/writing-for-agents productivity/wait-what

check: ## Verifies that every deployed symlink points back to this repository
	@status=0; \
	verify() { \
		if [ "$$(readlink "$$2" 2> /dev/null)" = "$$1" ]; then \
			printf "  \033[32mok\033[0m    %s\n" "$$2"; \
		elif [ -L "$$2" ]; then \
			printf "  \033[31mwrong\033[0m %s -> %s\n" "$$2" "$$(readlink "$$2")"; status=1; \
		elif [ -e "$$2" ]; then \
			printf "  \033[31mfile\033[0m  %s (not a symlink)\n" "$$2"; status=1; \
		else \
			printf "  \033[33mmiss\033[0m  %s\n" "$$2"; status=1; \
		fi; \
	}; \
	verify "${makefile_directory}/claude/settings.json" "${HOME}/.claude/settings.json"; \
	verify "${makefile_directory}/claude/statusline.py" "${HOME}/.claude/statusline.py"; \
	verify "${makefile_directory}/claude/global.md" "${HOME}/.claude/CLAUDE.md"; \
	verify "${makefile_directory}/claude/RTK.md" "${HOME}/.claude/RTK.md"; \
	verify "${makefile_directory}/claude/hooks/rtk-rewrite.sh" "${HOME}/.claude/hooks/rtk-rewrite.sh"; \
	verify "${makefile_directory}/claude/hooks/command-history.sh" "${HOME}/.claude/hooks/command-history.sh"; \
	for directory in ${makefile_directory}/claude/skills/*/; do \
		verify "$${directory%/}" "${HOME}/.claude/skills/$$(basename $$directory)"; \
	done; \
	verify "${makefile_directory}/git/.gitconfig" "${HOME}/.gitconfig"; \
	verify "${makefile_directory}/git/.gitconfig-opensource" "${HOME}/.gitconfig-opensource"; \
	verify "${makefile_directory}/git/.gitignore" "${HOME}/.gitignore"; \
	verify "${makefile_directory}/terminal/ghostty/config.ghostty" "${HOME}/.config/ghostty/config.ghostty"; \
	verify "${makefile_directory}/terminal/fish/config.fish" "${HOME}/.config/fish/config.fish"; \
	for file in ${makefile_directory}/terminal/fish/functions/*.fish; do \
		verify "$$file" "${HOME}/.config/fish/functions/$$(basename $$file)"; \
	done; \
	verify "${makefile_directory}/terminal/starship/starship.toml" "${HOME}/.config/starship.toml"; \
	if [ -f "${HOME}/.gitconfig-corporate" ]; then \
		printf "  \033[32mok\033[0m    %s\n" "${HOME}/.gitconfig-corporate"; \
	else \
		printf "  \033[33mmiss\033[0m  %s\n" "${HOME}/.gitconfig-corporate"; status=1; \
	fi; \
	exit $$status
.PHONY: check

claude: ## Deploys the Claude configuration files
	mkdir -p "${HOME}/.claude/hooks"
	ln -sf "${makefile_directory}/claude/settings.json" "${HOME}/.claude/settings.json"
	ln -sf "${makefile_directory}/claude/statusline.py" "${HOME}/.claude/statusline.py"
	ln -sf "${makefile_directory}/claude/global.md" "${HOME}/.claude/CLAUDE.md"
	ln -sf "${makefile_directory}/claude/RTK.md" "${HOME}/.claude/RTK.md"
	ln -sf "${makefile_directory}/claude/hooks/rtk-rewrite.sh" "${HOME}/.claude/hooks/rtk-rewrite.sh"
	ln -sf "${makefile_directory}/claude/hooks/command-history.sh" "${HOME}/.claude/hooks/command-history.sh"
	mkdir -p "${HOME}/.claude/skills"
	for directory in ${makefile_directory}/claude/skills/*/; do \
		ln -sfn "$${directory%/}" "${HOME}/.claude/skills/$$(basename $$directory)"; \
	done
.PHONY: claude

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

skills-sync: ## Pulls the latest upstream version of the vendored Claude skills
	@mkdir -p "$$(dirname ${skills_cache})"
	@[ -d "${skills_cache}" ] || git clone --quiet --filter=blob:none --no-checkout "${skills_repo}" "${skills_cache}"
	@git -C "${skills_cache}" fetch --quiet origin main
	@paths=""; for skill in ${skills_list}; do paths="$$paths skills/$$skill"; done; \
	git -C "${skills_cache}" checkout --quiet origin/main -- $$paths; \
	for skill in ${skills_list}; do \
		mkdir -p "${makefile_directory}/claude/skills/$$(basename $$skill)"; \
		rsync --archive --delete --exclude="agents/" \
			"${skills_cache}/skills/$$skill/" \
			"${makefile_directory}/claude/skills/$$(basename $$skill)/"; \
	done
	@printf "Upstream revision: %s\n" "$$(git -C ${skills_cache} rev-parse --short origin/main)"
	@echo "Review before committing: git diff -- claude/skills"
.PHONY: skills-sync

terminal: ## Deploys the configuration of the terminal
	# Ghostty
	mkdir -p "${HOME}/.config/ghostty"
	ln -sf "${makefile_directory}/terminal/ghostty/config.ghostty" "${HOME}/.config/ghostty/config.ghostty"
	# Fish
	mkdir -p "${HOME}/.config/fish"
	ln -sf "${makefile_directory}/terminal/fish/config.fish" "${HOME}/.config/fish/config.fish"
	mkdir -p "${HOME}/.config/fish/functions"
	for file in ${makefile_directory}/terminal/fish/functions/*.fish; do \
		ln -sf "$$file" "${HOME}/.config/fish/functions/$$(basename $$file)"; \
	done
	# Starship
	ln -sf "${makefile_directory}/terminal/starship/starship.toml" "${HOME}/.config/starship.toml"
.PHONY: terminal

help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' \
		| sed -e 's/\[32m##/[33m/'
.DEFAULT_GOAL := help
