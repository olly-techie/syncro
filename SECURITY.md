# Security Policy

## Supported versions
V1 MVP (`0.1.0`) is the only supported line right now. Security fixes go here first.

## Principles (enforced in code)
- Local-network only: no cloud, no internet streaming, no remote-access server.
- Never expose ADB to the public internet; default port 5555 on LAN only.
- No `0.0.0.0` binds, no arbitrary network scans, no killing unrelated processes.
- No `eval` on user input; all CLI args validated; shell variables quoted.
- No root required for normal use; installer never touches shell rc files.
- Minimal stored data: `~/.config/syncro/known_devices` holds only
  `serial|address|model` for reconnection — no credentials, no media.

## Reporting a vulnerability
Open a GitHub issue with `[SECURITY]` prefix or contact the maintainers
privately. Include distro, version (`syncro --version`), and steps to
reproduce. Do not publish exploits before a fix is released.

## Hardening notes for users
- Keep phone + PC on a trusted LAN; disable router AP isolation if needed,
  but never port-forward ADB (5555) to the internet.
- Revoke stale authorizations via Android: Developer options → Revoke USB
  debugging authorizations.
- Use `syncro --dry-run` to preview actions before connecting.
