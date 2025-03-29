# AutoAssignIDs Plugin for Godot 4.4

This plugin automatically assigns unique IDs to your `class_name ItemData` resources.

**Note:** Each `.tres` item file must have `@export var ID: int = -1` for the plugin to work.

## Features

- **Automatic ID Assignment:** Detects and fixes duplicate/missing IDs.
- **Manual & Auto Refresh:** Trigger refresh manually or set a configurable check interval.
- **Folder Management:** Easily add/remove folders to scan for `.tres` files.
- **Options:**
  - **Refresh Item IDs:** Resets only IDs that are lower than 0.
  - **Reset ALL IDs:** Resets all IDs.
- **Scanning:** Folders are scanned recursively, sorted alphabetically, and prioritized.

[Visit GitHub page for more visuals](https://github.com/CyrylSz/godot-auto-assign-IDs)

## Installation

1. Place the plugin folder in your project's `res://addons/` directory.
2. Enable it in **Project Settings > Plugins**.