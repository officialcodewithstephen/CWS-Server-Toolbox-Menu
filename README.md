# CWS Server Toolbox Menu

Ready-to-install IW4x GSC administration menu with automatic IW4MAdmin role access.

## Requirements

- IW4x dedicated server
- IW4MAdmin 2026.3 or newer
- Moderator, Administrator, and Owner levels configured in IW4MAdmin
- Dragnet installed in IW4MAdmin only when using the Dragnet menus

## Install

1. Stop the IW4x server and IW4MAdmin.
2. Remove any legacy `_mapvote.gsc` installation, including `userraw/scripts/_mapvote.gsc`. Running both voting systems can create duplicate menus and script errors.
3. Copy `IW4MAdmin/Plugins/CWS.AdminMenu.IW4MAdmin.Plugin.dll` into the `Plugins` directory of your IW4MAdmin installation.
4. Merge the repository's `userraw` directory into the IW4x server's `userraw` directory.
5. Start IW4MAdmin.
6. Start the IW4x server or rotate/restart the current map.

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
            ├── menu_functions.gsc
            └── mapvote.gsc
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
- Themed end-of-match map voting with live voters, configurable timer, and 2-15 choices
- Single-map/24-7 support that turns configured gametypes into voting choices
- Vote and changed-vote notifications for all connected human players
- Delayed restart, rotation, announcements, maintenance, and lockdown events
- Custom themes, colors, fonts, shaders, animations, opacity, position, and binds
- Review and confirmation screens for destructive operations

## Map Voting

![CWS Map Voting preview](docs/images/map-vote-preview.png)

Map Voting is enabled by default and opens for all human players at the end of a match. Options show the source game, map, gametype, current voters, and remaining time. Late joiners are attached while voting is active.

Existing configurations remain compatible through these DVARs:

- `mapvote_small_maps`, `mapvote_med_maps`, and `mapvote_big_maps`
- `mapvote_modes`
- `mapvote_map_timer`
- `mapvote_gamemode_timer` (retained for configuration compatibility)
- `mapvote_optionsCount` (2-15 choices)

If every configured entry resolves to one map, the map stays fixed and players vote between the configured gametypes. Missing DVARs receive safe defaults automatically.

## Safety

The menu uses server-side GSC, IW4MAdmin events, DVARs, and RCON. It does not scan player computers, inject into clients, or read client memory.

## Version

`0.19.0`

## Third-Party Code

The map-vote endgame integration is adapted from
[jakelooker/IW4x-Map-Voting-System](https://github.com/jakelooker/IW4x-Map-Voting-System)
under GPL-3.0. See `THIRD_PARTY.md` and `LICENSES/`.
