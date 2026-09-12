# SYNCRO

**Wireless Android → Linux screen mirroring. One command.**

```sh
syncro
```

SYNCRO is a lightweight open-source Linux CLI that wraps `adb` (wireless setup)
+ `scrcpy` (mirroring). Plug in once, configure once, sync whenever you want.
Fast. Local. Lightweight. Linux-native. No cloud, no daemon, no GUI in V1.

## Features
- One-command wireless mirror: detect → Wi-Fi ADB → `scrcpy`
- Automatic detection (USB vs Wi-Fi), authorization/offline handling
- First-time USB-guided wireless setup; remembers known devices; auto-reconnect
- Multi-device list + `--device` selection (never guesses)
- Quality presets (`low|balanced|high`), `--fps 30|60`, `--fullscreen`
- `--dry-run` (changes nothing), `--list`, clean errors with recovery hints
- User-local install, mock-based tests, POSIX sh, no `eval`, LAN-only

## Requirements
- Linux: Fedora, Debian, Ubuntu, Arch (others work if `adb`+`scrcpy` exist)
- `adb` (Android Platform Tools) + `scrcpy` — SYNCRO never auto-installs them
- Android with USB debugging; USB cable for first-time setup; shared Wi-Fi

## Supported platforms
Android → Linux over Wi-Fi. V1 excludes: audio forwarding, file transfer,
clipboard sync, iOS, Miracast, internet streaming, multi-mirror, custom
encoders, GUI, background services.

## Installation
```sh
git clone <repo> && cd syncro
sh install.sh
# installs ~/.local/bin/syncro + ~/.local/share/syncro/ (idempotent, no root,
# never edits ~/.bashrc ~/.zshrc ~/.profile)
syncro --help
```
Ensure `~/.local/bin` is on `PATH`. Uninstall: `sh uninstall.sh`
(`--purge` also removes config/state). Missing deps produce distro hints:
Fedora `sudo dnf install android-tools scrcpy`,
Debian/Ubuntu `sudo apt update && sudo apt install adb scrcpy`,
Arch `sudo pacman -S android-tools scrcpy`.

## Android setup
1. Settings → About → tap Build number 7× → Developer options → enable **USB debugging**.
2. Plug in USB, accept **Allow USB debugging** on the phone.
3. Join phone + PC to the same Wi-Fi.

## Quick start
```sh
syncro                  # first run: USB → Wi-Fi setup → mirror
syncro                  # later: auto-reconnects known device
syncro --dry-run        # preview without changing anything
syncro --list           # show devices
```

## Usage
```sh
syncro
syncro --list
syncro --device <serial|address|model>
syncro --quality low|balanced|high
syncro --fps 30|60
syncro --fullscreen
syncro --dry-run
syncro --help
syncro --version
```
Exit codes: `0` ok · `1` connection/runtime · `2` bad args · `3` missing dep ·
`4` device error · `5` scrcpy launch failure.

## CLI options
| Flag | Effect |
|---|---|
| (none) | Full flow: check → detect → wireless → verify → mirror |
| `--list` | List devices (`[1] MODEL / USB|Wi-Fi / status`), exit |
| `--device X` | Exact serial/address or model substring match |
| `--quality Q` | `low` 720p-class/4M, `balanced` (default) 1080p-class/8M, `high` 1080p-class/12M |
| `--fps N` | `30`/`60` (default follows quality: low 30, balanced 30, high 60) |
| `--fullscreen` | Pass `--fullscreen` to scrcpy |
| `--dry-run` | Print plan + would-be `scrcpy` command; no `tcpip`/`connect`/`scrcpy` |
| `--help` / `--version` | Help / version from `VERSION` (`0.1.0`) |

## Quality presets
- **Low**: `--max-size 1280 --video-bit-rate 4M --max-fps 30` — weak Wi-Fi/old HW.
- **Balanced** (default): `--max-size 1920 --video-bit-rate 8M --max-fps 30`.
- **High**: `--max-size 1920 --video-bit-rate 12M --max-fps 60` — strong LAN+PC.
All encoding is scrcpy's; flags are caps, not promises.

## Troubleshooting
See `docs/troubleshooting.md`. Quick map:
`adb/scrcpy not found` → install hints (exit 3) · `unauthorized` → accept phone
prompt · `offline` → replug/`adb reconnect` · `Wi-Fi failed` → same LAN, no VPN,
AP isolation off · `multiple` → `syncro --list` + `--device` · `drops/lag` →
`--quality low --fps 30`, move closer to router.

## Security notes
LAN-only, no cloud/remote server, no `0.0.0.0` binds, no network scans, no
`eval`, validated args, quoted vars, no root. Stores only
`~/.config/syncro/known_devices` (`serial|address|model`) + run log in
`~/.local/state/syncro/`. Never port-forward ADB to the internet. Details:
`SECURITY.md`.

## Architecture
`bin/syncro` orchestrates; `lib/adb.sh` (detect/connect), `lib/device.sh`
(identify/select), `lib/network.sh` (validate/wireless), `lib/scrcpy.sh`
(build/`exec`), `lib/config.sh` (XDG+known devices), `lib/ui.sh` (output).
Full diagram: `docs/architecture.md`.

## Development
POSIX sh, shellcheck-friendly, modular. Layout: `bin/ lib/ tests/ docs/
install.sh uninstall.sh VERSION`.
```sh
sh -n bin/syncro lib/*.sh install.sh uninstall.sh
shellcheck bin/syncro lib/*.sh install.sh uninstall.sh  # if available
```

## Testing
No physical device needed (mock `adb`/`scrcpy` in `PATH`):
```sh
sh tests/test_args.sh      # help/version/list/device/quality/fps/fullscreen/dry-run/invalid
sh tests/test_device.sh    # none/usb/wifi/unauthorized/offline/multiple
sh tests/test_config.sh    # first-run/existing/malformed/known/missing-dir
sh tests/test_network.sh   # valid/failed/unreachable/malformed address
```
Real-device integration is manual: fresh Linux + `adb`+`scrcpy`, run `syncro`,
expect a wireless mirror; second run should reconnect without USB.

## Contributing
V1 scope only; see `CONTRIBUTING.md`. Update `CHANGELOG.md` with behavior changes.

## License
MIT — see `LICENSE`. Independent project; invokes `adb`/`scrcpy` at runtime,
bundles neither. Respect their licenses.
