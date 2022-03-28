#!/usr/bin/env bash

# Close any open System Preferences panes, to prevent them from overriding settings we are about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Trigger the initialization scripts
directory_path="$(dirname "${BASH_SOURCE[0]}")"
bash "${directory_path}/configure_core.sh"
bash "${directory_path}/configure_dock.sh"
bash "${directory_path}/configure_finder.sh"
