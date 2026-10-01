##
## ----------------------------------------------------------------------------
##   DOTFILES
## ----------------------------------------------------------------------------
##

makefile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
makefile_directory := $(realpath $(dir $(makefile_path)))

# Third-party Claude skills installed globally by the skills CLI (see "skills")
skills_cli := skills@1.7.0
skills_mattpocock := improve-codebase-architecture codebase-design diagnosing-bugs grilling writing-for-agents \
                     wait-what
skills_cursor := unslop

check: ## Verifies every deployed symlink, every third-party skill listed for "skills" and RTK.md
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
	verify_skill() { \
		path="${HOME}/.claude/skills/$$2"; \
		source="$$(jq -r --arg skill "$$2" '.skills[$$skill].source // empty' "${HOME}/.agents/.skill-lock.json" 2> /dev/null)"; \
		if [ -L "$$path" ]; then \
			printf "  \033[31mlink\033[0m  %s -> %s\n" "$$path" "$$(readlink "$$path")"; status=1; \
		elif [ -f "$$path/SKILL.md" ] && [ "$$source" = "$$1" ]; then \
			printf "  \033[32mok\033[0m    %s\n" "$$path"; \
		elif [ -f "$$path/SKILL.md" ]; then \
			printf "  \033[31mwrong\033[0m %s (locked source: %s)\n" "$$path" "$${source:-none}"; status=1; \
		else \
			printf "  \033[33mmiss\033[0m  %s\n" "$$path"; status=1; \
		fi; \
	}; \
	verify_file() { \
		if [ -L "$$1" ]; then \
			printf "  \033[31mlink\033[0m  %s -> %s\n" "$$1" "$$(readlink "$$1")"; status=1; \
		elif [ -f "$$1" ]; then \
			printf "  \033[32mok\033[0m    %s\n" "$$1"; \
		else \
			printf "  \033[33mmiss\033[0m  %s\n" "$$1"; status=1; \
		fi; \
	}; \
	verify "${makefile_directory}/claude/settings.json" "${HOME}/.claude/settings.json"; \
	verify "${makefile_directory}/claude/statusline.py" "${HOME}/.claude/statusline.py"; \
	verify "${makefile_directory}/claude/global.md" "${HOME}/.claude/CLAUDE.md"; \
	verify_file "${HOME}/.claude/RTK.md"; \
	verify "${makefile_directory}/claude/hooks/command-history.sh" "${HOME}/.claude/hooks/command-history.sh"; \
	for directory in ${makefile_directory}/claude/skills/*/; do \
		verify "$${directory%/}" "${HOME}/.claude/skills/$$(basename $$directory)"; \
	done; \
	for skill in ${skills_mattpocock}; do verify_skill mattpocock/skills "$$skill"; done; \
	for skill in ${skills_cursor}; do verify_skill cursor/plugins "$$skill"; done; \
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

claude-guard:
	@command -v rtk > /dev/null || { echo "rtk is not installed"; exit 1; }
	@# A real file where a symlink belongs means something wrote to ~/.claude outside this
	@# repository. An in-place write follows the symlink and shows up as a diff here, but an
	@# atomic one (temp file + rename) replaces the link instead, and "ln -sf" below would
	@# discard it before anyone sees it. Stop so that someone reviews it first.
	@targets="settings.json statusline.py CLAUDE.md hooks/command-history.sh"; \
	for directory in ${makefile_directory}/claude/skills/*/; do \
		targets="$$targets skills/$$(basename $$directory)"; \
	done; \
	for target in $$targets; do \
		path="${HOME}/.claude/$$target"; \
		if [ -e "$$path" ] && [ ! -L "$$path" ]; then \
			printf "  \033[31mrefusing\033[0m %s is not a symlink. Review it, then remove it\n" "$$path"; \
			exit 1; \
		fi; \
	done
.PHONY: claude-guard

claude: claude-guard skills ## Deploys the Claude configuration files, the third-party skills and RTK.md
	mkdir -p "${HOME}/.claude/hooks"
	ln -sf "${makefile_directory}/claude/settings.json" "${HOME}/.claude/settings.json"
	ln -sf "${makefile_directory}/claude/statusline.py" "${HOME}/.claude/statusline.py"
	ln -sf "${makefile_directory}/claude/global.md" "${HOME}/.claude/CLAUDE.md"
	ln -sf "${makefile_directory}/claude/hooks/command-history.sh" "${HOME}/.claude/hooks/command-history.sh"
	rm -f "${HOME}/.claude/hooks/rtk-rewrite.sh"
	mkdir -p "${HOME}/.claude/skills"
	for directory in ${makefile_directory}/claude/skills/*/; do \
		ln -sfn "$${directory%/}" "${HOME}/.claude/skills/$$(basename $$directory)"; \
	done
	@# rtk writes RTK.md itself, after the symlinks, so that it finds its hook in settings.json and the "@RTK.md"
	@# import in CLAUDE.md and leaves both files unchanged. RTK.md used to be a symlink into this repository, and rtk
	@# must not write through it.
	@[ ! -L "${HOME}/.claude/RTK.md" ] || rm -f "${HOME}/.claude/RTK.md"
	@# Records the refusal up front, so "rtk init" never stops to ask for telemetry consent.
	rtk telemetry disable > /dev/null
	rtk init --global --auto-patch > /dev/null
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

skills: ## Installs or updates the third-party Claude skills in ~/.claude/skills/
	@command -v npx > /dev/null || { echo "npx is not installed"; exit 1; }
	@# "claude" used to symlink third-party skills from claude/skills/. The CLI must not write through such a link once
	@# its directory is gone, so the loop deletes every dangling link that points there. Real directories and the links
	@# to owned skills, which still resolve, stay.
	@for link in "${HOME}"/.claude/skills/*; do \
		case "$$(readlink "$$link")" in "${makefile_directory}/claude/skills/"*) [ -e "$$link" ] || rm -f "$$link" ;; esac; \
	done
	DISABLE_TELEMETRY=1 npx --yes ${skills_cli} add mattpocock/skills --global --agent claude-code --copy --yes \
		$(addprefix --skill ,${skills_mattpocock})
	DISABLE_TELEMETRY=1 npx --yes ${skills_cli} add cursor/plugins --global --agent claude-code --copy --yes \
		$(addprefix --skill ,${skills_cursor})
	sed -i '' '/^disable-model-invocation: true$$/d' "${HOME}/.claude/skills/unslop/SKILL.md"
.PHONY: skills

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
