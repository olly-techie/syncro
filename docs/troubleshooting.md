# SYNCRO Troubleshooting

Practical fixes. Run `syncro --dry-run` first to preview, and
`adb devices -l` to see raw device state.

## ADB not found (exit 3)
`syncro` prints a distro-specific hint and never auto-installs.
- Fedora: `sudo dnf install android-tools`
- Debian/Ubuntu: `sudo apt update && sudo apt install adb`
- Arch: `sudo pacman -S android-tools`
- Then: `adb version` should succeed; re-run `syncro`.

## scrcpy not found (exit 3)
- Fedora: `sudo dnf copr enable zeno/scrcpy && sudo dnf install scrcpy`
  (not in default repos; `zeno/scrcpy` is the upstream-documented COPR)
- Debian/Ubuntu: `sudo apt update && sudo apt install scrcpy`
- Arch: `sudo pacman -S scrcpy`
- Then: `scrcpy --version`; re-run `syncro`.

## USB debugging disabled / no devices
1. Phone: Settings → About → tap Build number 7× → Developer options → enable **USB debugging**.
2. Plug in via USB, run `adb devices` — expect `<serial> device`.
3. If empty: try another cable/port (charge-only cables fail), `adb kill-server; adb start-server` (only restarts adb, kills nothing else).

## Device unauthorized
`adb devices` shows `<serial> unauthorized`.
1. Unplug/replug USB.
2. On the phone accept **Allow USB debugging** (enable *Always allow*).
3. Re-run `syncro`. Still stuck? Phone → Developer options → **Revoke USB debugging authorizations**, then retry.

## Device offline
Shows `<serial> offline`.
1. Unplug/replug, or `adb reconnect`.
2. `adb kill-server; adb start-server`, then `syncro --list`.
3. Try another cable/port.

## Wi-Fi ADB connection failed
`syncro` did `ip route → tcpip 5555 → connect → verify` and it failed.
- Keep USB plugged in during first setup.
- Phone + PC must share the same Wi-Fi (same SSID/band); disable VPN on both.
- Router **AP/client isolation** must be off.
- Retry `syncro`. Manual check: `adb shell ip route` should show `src 192.168.x.x`; then `adb connect 192.168.x.x:5555`.
- Some work/campus networks block device-to-device traffic — use a phone hotspot or home router instead.

## Phone and laptop on different networks
Symptom: `adb connect` hangs or `failed to connect`, IP looks like `10.x` vs `192.168.x`.
Fix: join both to the same LAN. No internet/cloud relay exists in V1 by design.

## Multiple devices
`syncro` refuses to guess. It lists:
```text
[1] TECNO KM4 ...
[2] Pixel 8 ...
```
Pick interactively, or non-interactively: `syncro --list`, then `syncro --device <serial|address|model>`.

## Connection drops mid-mirror
1. Stay close to the router; prefer 5 GHz; stop large downloads.
2. Drop quality: `syncro --quality low --fps 30`.
3. Re-run `syncro` — known devices reconnect automatically.
4. `adb devices` should still show `192.168.x.x:5555 device`; if not, `adb connect` again.

## Poor performance / lag
- `syncro --quality low --fps 30` (weak Wi-Fi/old GPU).
- Default is `--quality balanced` (1080p class, 30 FPS); `--quality high` needs strong LAN+PC.
- Close other video apps; use `--fullscreen` only if the GPU keeps up.
- scrcpy caps apply — syncro never promises more than device+network+scrcpy allow.

## Still stuck?
Collect: distro, `syncro --version`, `adb version`, `scrcpy --version`,
`adb devices -l`, and `tail ~/.local/state/syncro/syncro.log`, then file an issue.
