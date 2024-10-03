# Item Roll Tracker

This addon is a fork of the no-longer-functional [EasyRollTracker](https://github.com/ErythroGuild/EasyRollTracker) addon by Ernest314. Some features I deemed unnecessary have been cut and some added.

A lightweight addon to list `/roll` results in a raid,
with many convenience features. Open the tracking window
with `/rt` or `/rolltrack`.

### Limitations
- Can only handle one roll at a time
- Doesn't show duplicate rolls. Players with multiple rolls for a single item have a blue-coloured roll.
- Specs are fetched one-at-a-time, and subject to server
limits (need to send inspect request and be in range).

### Major features

- Listing and sorting all `/roll` results in group
- Announcing rolled items to group as `/rw`
- Directly trading with players by dragging items on their name.

### Commands

*These can be opened with any of the addon aliases:*
*`/rt`, `/rolltrack`.*

- `/rt`: toggles main window
- `/rt help`, `h`, `?`: prints a list of available commands
- `/rt config`, `opt`, `options`: opens the addon settings
- `/rt close`: closes the current roll
- `/rt clear`: clears the main window
- `/rt reset`: reset all addon data

### Minor features

- Slash command (`/rt`) interface
- Minimap button for quick access
- Displaying spec and role indicators
- Formatting names with class color
- Highlighting out-of-bounds rolls
- Drag-and-drop or shift-click items
- Items can be dragged onto editbox
- Parses valid plaintext to itemlinks
- Option to only allow valid itemlinks
- Tooltip preview of items
- Option to automatically close rolls after a delay
- Export logs of all items/rolls onscreen
- Option to auto-export when history is cleared
- Resizable window
- Maximize by double-clicking titlebar / resize handle

*The project can be found on CurseForge [here][1].*

[1]: https://legacy.curseforge.com/wow/addons/itemrolltracker