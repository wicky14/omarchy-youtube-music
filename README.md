# omakid.youtube-music

<img width="517" height="644" alt="image" src="https://github.com/user-attachments/assets/2315fbd3-0230-4461-890e-6892e769b9e5" />



YouTube Music player for the Omarchy bar. Search, play, and control
music directly from your bar — no browser needed.

Uses `yt-dlp` to search and resolve YouTube Music URLs, and `mpv` for
native audio playback.

## Features

- **Search** — type in the popup search field to find songs on YouTube Music
- **Playback** — play, pause, skip, previous via the popup controls
- **Queue** — manage your play queue, reorder or remove tracks
- **Volume** — slider in the popup or scroll wheel on the bar icon
- **Now Playing** — scrolling title + artist in the bar when music is playing
- **MPRIS** — integrates with Omarchy's built-in media controls automatically
- **Restart-safe playback** — mpv runs detached, so `omarchy restart shell`
  no longer kills your music; playback, queue, and position are restored
  when the bar comes back

## Bar Controls

| Action | Effect |
|--------|--------|
| Left click | Open/close search & control popup |
| Right click | Play / Pause |
| Middle click | Stop playback |
| Scroll wheel | Volume up / down |

## Requirements

- `yt-dlp` — for searching and resolving YouTube Music URLs
- `mpv` — for audio playback with MPRIS support
- `socat` — for IPC communication (optional, for mpv command socket)

## Install

From the Omarchy plugin marketplace:

```bash
omarchy plugin add https://github.com/wicky14/omarchy-youtube-music.git --enable --yes
```

Or install from a local checkout with the bundled script:

```bash
./install.sh              # install plugin + add to bar
./install.sh --no-bar     # install plugin only
```

## Uninstall

```bash
omarchy plugin remove omakid.youtube-music --yes
omarchy-shell shell rescanPlugins
```

Or from a local checkout:

```bash
./install.sh --uninstall  # remove plugin + bar entry + runtime files
./install.sh --remove     # alias for --uninstall
```

## Files

- `manifest.json` — plugin manifest (bar-widget + service)
- `BarWidget.qml` — bar icon with popup dropdown
- `YouTubeMusicService.qml` — backend service (search + playback)
- `SearchModel.js` — search result parsing helpers
- `ytmusic-player` — detached mpv launcher (keeps music alive across restarts)
- `install.sh` — install/uninstall script
- `README.md` — this file