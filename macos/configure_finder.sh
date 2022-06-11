#!/usr/bin/env bash

# Set HOME as the default location for new Finder windows
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Use list view in all Finder windows by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Allow quitting Finder via ⌘ + Q; doing so will also hide desktop icons
defaults write com.apple.finder QuitMenuItem -bool true

# Disable the warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

for view in 'Desktop' 'FK_Standard' 'Standard'; do
  # Item info near icons
  /usr/libexec/PlistBuddy -c "Set :${view}ViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist

  # Item info to right of icons
  /usr/libexec/PlistBuddy -c "Set :${view}ViewSettings:IconViewSettings:labelOnBottom false" ~/Library/Preferences/com.apple.finder.plist

  # Snap-to-grid for icons
  /usr/libexec/PlistBuddy -c "Set :${view}ViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

  # Grid spacing for icons
  /usr/libexec/PlistBuddy -c "Set :${view}ViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist

  # Icon size
  /usr/libexec/PlistBuddy -c "Set :${view}ViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist
done

for view in 'FK_Standard' 'Standard'; do
    # Sort items by name
    /usr/libexec/PlistBuddy -c "Set :${view}ViewSettings:ListViewSettings:sortColumn name" ~/Library/Preferences/com.apple.finder.plist
done

killall -9 Finder
