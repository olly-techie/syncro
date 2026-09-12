# SYNCRO Architecture

V1 MVP. Principle: **SYNCRO orchestrates; `adb` connects; `scrcpy` mirrors.**
No custom capture engine, no encoder, no daemon, no cloud.

## Runtime flow

```text
syncro
  → check adb + scrcpy (never auto-install)
  → init ~/.config/syncro + ~/.local/state/syncro
  → adb devices (read-only detect)
  → resolve target:
      --device given? match serial/address/model
      0 devices? try known_devices reconnect
      1 device? use it
      N devices? interactive select (or require --device)
  → authorize check (device|unauthorized|offline)
  → ensure wireless:
      wifi serial? verify only
      usb serial? known addr reconnect → else ip route → tcpip 5555 → connect → verify
  → save known device (serial|address|model)
  → exec scrcpy --serial … --max-size … --video-bit-rate … --max-fps … [--fullscreen]
```

Dry-run (`--dry-run`) performs only the read-only steps
(`command -v`, `adb devices`, `getprop`) and prints the plan.
It never runs `tcpip`, `connect`, or `scrcpy`.

## Module responsibilities

| File | Owns | Never does |
|---|---|---|
| `bin/syncro` | arg parsing, init, orchestration, exit codes (0 ok, 1 runtime, 2 args, 3 missing dep, 4 device, 5 scrcpy) | device parsing, network math, scrcpy flags |
| `lib/adb.sh` | `ADB_BIN` wrapper, `devices` parsing, status, model, IP via `ip route`/`wlan0`, `tcpip`, `connect`, verify | install advice copy (only missing-help text), UI layout |
| `lib/device.sh` | model/transport/status helpers, exact→address→model-substring match, numbered list, interactive select | connecting, saving state |
| `lib/network.sh` | IPv4/port/address validation, `IP`→`IP:5555` normalize, USB→Wi-Fi setup, known reconnect loop | scanning the LAN (only device-provided IPs) |
| `lib/scrcpy.sh` | detection, `low/balanced/high` → `--max-size/--video-bit-rate`, default FPS (30/30/60), cmd build, `exec` launch | mirroring itself |
| `lib/config.sh` | XDG dirs (`SYNCRO_CONFIG_DIR`, `SYNCRO_STATE_DIR` overridable), `known_devices` (`serial\|address\|model`), quality/FPS validators, state log | anything network/device specific |
| `lib/os.sh` | distro detection (`ID` + `ID_LIKE`, overridable for tests), per-distro `adb`/`scrcpy` setup commands, copy-paste setup plan | installing anything itself |
| `lib/ui.sh` | colors (TTY+NO_COLOR aware), `✓/✗/→` indicators, errors to stderr with hints, prompts | logic |

## State

- `~/.config/syncro/known_devices` — one `serial|address|model` per line, `600` perms. Only data needed to reconnect.
- `~/.local/state/syncro/syncro.log` — append-only run log (best effort).
- Install: `~/.local/bin/syncro` + `~/.local/share/syncro/{lib,VERSION}`.

## Design for V2/V3 (not implemented)

- Audio/clipboard/file-transfer map to extra `scrcpy` flags or new `lib/audio.sh`-style modules; `scrcpy_build_cmd`/`scrcpy_launch` are the single choke points.
- Device profiles = extended `known_devices` columns + per-device quality defaults in `config.sh`.
- GUI = new frontend calling the same `lib/` functions; no orchestration logic lives in UI strings.
- LAN discovery (optional, opt-in) would live in `lib/network.sh` behind a flag — V1 deliberately has none.
