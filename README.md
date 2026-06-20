# CWS Server Toolbox Menu

Ready-to-install IW4x GSC administration menu with automatic IW4MAdmin role access.

## Requirements

- IW4x dedicated server
- IW4MAdmin 2026.3 or newer
- Moderator, Administrator, and Owner levels configured in IW4MAdmin
- Dragnet installed in IW4MAdmin only when using the Dragnet menus

## Install

1. Stop the IW4x server and IW4MAdmin.
2. Copy `IW4MAdmin/Plugins/CWS.AdminMenu.IW4MAdmin.Plugin.dll` into the `Plugins` directory of your IW4MAdmin installation.
3. Merge the repository's `userraw` directory into the IW4x server's `userraw` directory.
4. Start IW4MAdmin.
5. Start the IW4x server or rotate/restart the current map.

The resulting server layout should contain:

```text
IW4MAdmin/
└── Plugins/
    └── CWS.AdminMenu.IW4MAdmin.Plugin.dll

userraw/
├── scripts/
│   └── menu_loader.gsc
└── maps/
    └── mp/
        └── gametypes/
            ├── menu.gsc
            └── menu_functions.gsc
```

## Access

The IW4MAdmin plugin automatically grants the appropriate menu when a Moderator, Administrator, or Owner joins. Access is scoped to the individual player and restored after map restarts and rotations.

The default open bind is shown in game. Personal binds and visual settings are persisted through GUID-scoped DVARs.

## Features

- Role-aware Moderator, Administrator, and Owner menus
- Player moderation, watching, team, movement, and utility controls
- IW4MAdmin history, warning, report, alias, and ban-information views
- Optional Dragnet peer, event, and action menus
- Dynamic installed-map discovery, including custom maps
- Server settings, presets, Bot Warfare controls, and map rotation tools
- Delayed restart, rotation, announcements, maintenance, and lockdown events
- Custom themes, colors, fonts, shaders, animations, opacity, position, and binds
- Review and confirmation screens for destructive operations

## Safety

The menu uses server-side GSC, IW4MAdmin events, DVARs, and RCON. It does not scan player computers, inject into clients, or read client memory.

## Version

`0.18.0`
