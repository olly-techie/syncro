# Contributing to SYNCRO

Thanks for helping keep SYNCRO fast, local, and lightweight.

## Ground rules
- V1 scope only: wireless Android → Linux mirroring via `adb` + `scrcpy`.
- Out of scope for V1: audio forwarding, file transfer, clipboard sync, iOS,
  Miracast, cloud streaming, multi-mirror, custom encoders, GUI, daemons.
- POSIX sh where practical; must be `sh -n` clean and shellcheck-friendly.
- Quote all variables, validate all CLI input, never use `eval`.
- No arbitrary network scanning; LAN-only; no root for normal use.

## Workflow
1. Fork / branch from `main`.
2. Keep changes modular (`bin/` orchestrates, `lib/` owns one concern each).
3. Add or update tests under `tests/` (mocks only — no physical device required).
4. Run before pushing:
   ```sh
   sh -n bin/syncro lib/*.sh install.sh uninstall.sh
   sh tests/test_args.sh
   sh tests/test_device.sh
   sh tests/test_config.sh
   sh tests/test_network.sh
   sh tests/test_os.sh
   ```
   Plus `shellcheck bin/syncro lib/*.sh install.sh uninstall.sh` if available.
5. Update `CHANGELOG.md` and docs when behavior changes.

## Commit style
- Short imperative subject (<72 chars), e.g. `Fix wifi reconnect when adb drops`.
- Reference issues where relevant.

## Reporting bugs
Include: distro, `syncro --version`, `adb version`, `scrcpy --version`,
`adb devices -l` (redact serials if you like), and `~/.local/state/syncro/syncro.log` excerpt.
