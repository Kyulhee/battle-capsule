class_name BuildInfo
extends RefCounted


const PRODUCT_NAME := "Battle Capsule"
const EXECUTABLE_BASENAME := "BattleCapsule"
const PRODUCT_VERSION := "2.1.0"
const WINDOWS_VERSION := PRODUCT_VERSION + ".0"
const RELEASE_CHANNEL := "demo-dev"
const DISPLAY_VERSION := "v" + PRODUCT_VERSION + "-" + RELEASE_CHANNEL
const PLAYTEST_BUILD := "E-064"
const MENU_VERSION := DISPLAY_VERSION + " | " + PLAYTEST_BUILD
const FILE_DESCRIPTION := "Battle Capsule Windows demo"
const ICON_PATH := "res://icon.svg"

# Keep existing installs on their current user:// path while the visible product
# name changes. Moving this directory requires an explicit save-migration release.
const LEGACY_USER_DIR_NAME := "Godot/app_userdata/BattleRoyalePrototype"
