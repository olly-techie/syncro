# SYNCRO

### Wireless Android → Linux Screen Mirroring

Build **SYNCRO**, a lightweight open-source Linux CLI utility that makes wireless Android screen mirroring ridiculously simple.

SYNCRO should be built **on top of `scrcpy`**, not by reinventing Android screen capture or video streaming.

The goal of V1 is simple:

> **Connect an Android phone to a Linux PC over Wi-Fi and mirror it with one command.**

---

## 1. V1 SCOPE

### Supported

- Android → Linux
- Wireless ADB
- Automatic Android device detection
- First-time wireless setup
- Remember known devices
- Automatic reconnection
- Multiple-device detection and selection
- Basic quality presets
- FPS presets
- Fullscreen mode
- Clean CLI interface
- Safe, understandable errors
- Linux compatibility
- Dry-run mode

### NOT in V1

Do **not** implement:

- Audio forwarding
- File transfer
- Clipboard synchronization
- iPhone/iOS support
- Miracast
- Cloud/Internet streaming
- Remote access over the Internet
- Multiple simultaneous mirrors
- Custom video encoder
- Custom Android screen-capture engine
- Large GUI
- Unnecessary background services

Keep V1 focused.

---

# 2. COMMAND

The primary command must be:

```bash
syncro
```

Examples:

```bash
syncro
syncro --list
syncro --device <device>
syncro --quality low
syncro --quality balanced
syncro --quality high
syncro --fps 30
syncro --fps 60
syncro --fullscreen
syncro --dry-run
syncro --help
syncro --version
```

### Expected experience

Running:

```bash
syncro
```

should:

1. Check whether `adb` is installed.
2. Check whether `scrcpy` is installed.
3. Detect available Android devices.
4. Detect whether a device is connected through USB or Wi-Fi.
5. If the device has already been configured for wireless ADB, reconnect automatically.
6. If first-time setup is required and USB is available, guide the user through setup.
7. Establish the wireless ADB connection.
8. Verify the connection.
9. Launch `scrcpy`.
10. Mirror the phone.

The user should not need to understand ADB internals.

---

# 3. PROJECT STRUCTURE

Use this structure:

```text
syncro/
├── bin/
│   └── syncro
│
├── lib/
│   ├── adb.sh
│   ├── device.sh
│   ├── network.sh
│   ├── scrcpy.sh
│   ├── config.sh
│   └── ui.sh
│
├── tests/
│   ├── test_args.sh
│   ├── test_device.sh
│   ├── test_config.sh
│   └── test_network.sh
│
├── docs/
│   ├── architecture.md
│   └── troubleshooting.md
│
├── install.sh
├── uninstall.sh
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── CHANGELOG.md
└── VERSION
```

---

# 4. INSTALLATION

SYNCRO should install without requiring root for normal usage.

Install user-local files into:

```text
~/.local/bin/syncro
~/.local/share/syncro/
```

Configuration:

```text
~/.config/syncro/
```

Runtime state and logs:

```text
~/.local/state/syncro/
```

Do **not** automatically modify:

```text
~/.bashrc
~/.zshrc
~/.profile
```

unless absolutely necessary.

The installer should be:

- idempotent
- safe to rerun
- shellcheck-friendly
- explicit about what it installs
- safe to uninstall

The uninstaller must only remove files owned by SYNCRO.

---

# 5. DEPENDENCIES

Required:

```text
adb
scrcpy
```

SYNCRO must **not silently install dependencies**.

If either dependency is missing, display:

- what is missing
- why it is required
- appropriate installation guidance for the user's Linux distribution

Support common distributions including:

- Fedora
- Debian
- Ubuntu
- Arch Linux

Do not assume a particular package manager.

---

# 6. ADB WORKFLOW

SYNCRO should abstract the wireless ADB workflow.

Typical first-time workflow:

```text
Android USB debugging enabled
        ↓
Connect phone through USB
        ↓
Verify ADB authorization
        ↓
Determine phone network address
        ↓
Configure ADB for TCP/IP
        ↓
Connect to phone over LAN
        ↓
Verify wireless connection
        ↓
Launch scrcpy
```

Do not require the user to manually memorize ADB commands.

SYNCRO should handle the normal workflow automatically where Android/device capabilities permit it.

Do not perform arbitrary network scanning.

Only use the device/network information required for the connection.

---

# 7. DEVICE MANAGEMENT

SYNCRO must detect:

- device serial
- device model
- connection type
- connection status

Handle:

```text
device connected
device unauthorized
device offline
device disconnected
multiple devices
no devices
```

If multiple devices are available, do not randomly select one.

Provide a clear selection mechanism.

Example:

```text
SYNCRO

Available devices:

[1] TECNO KM4
    USB
    authorized

[2] Pixel 8
    Wi-Fi
    authorized

Select device:
```

Allow:

```bash
syncro --device <device>
```

for explicit selection.

---

# 8. KNOWN DEVICES

SYNCRO should remember previously configured devices.

Store only the minimum information required for reconnection.

Configuration/state should live under:

```text
~/.config/syncro/
~/.local/state/syncro/
```

Do not store unnecessary sensitive Android data.

On future launches:

```bash
syncro
```

should attempt to reconnect to a known device when appropriate.

If the device is unavailable, fail gracefully and explain what happened.

---

# 9. QUALITY PRESETS

Provide three presets:

### Low

Optimized for weaker Wi-Fi or older hardware.

Approximate target:

```text
720p
30 FPS
lower bitrate
```

### Balanced

Default.

Approximate target:

```text
1080p
30–60 FPS
moderate bitrate
```

### High

For stronger systems and networks.

Approximate target:

```text
1080p
60 FPS
higher bitrate
```

Do not promise capabilities that the Android device, network, or scrcpy version cannot provide.

All actual encoding/mirroring should be delegated to scrcpy.

---

# 10. FPS

Support:

```bash
syncro --fps 30
syncro --fps 60
```

Validate the value.

Reject unsupported or invalid values with a clear error.

---

# 11. FULLSCREEN

Support:

```bash
syncro --fullscreen
```

This should launch scrcpy in fullscreen mode.

---

# 12. DRY RUN

Support:

```bash
syncro --dry-run
```

Dry-run must never make connection or system changes.

It should explain what SYNCRO would do.

Example:

```text
SYNCRO DRY RUN

Dependency check:
✓ adb
✓ scrcpy

Device:
TECNO KM4

Connection:
USB → Wi-Fi ADB

Quality:
Balanced

FPS:
60

Actions:
→ configure wireless ADB
→ connect to device
→ verify connection
→ launch scrcpy
```

---

# 13. CLI UX

The CLI should feel polished but lightweight.

Example:

```text
SYNCRO

Wireless Android → Linux

✓ ADB detected
✓ scrcpy detected
✓ Device found: TECNO KM4
✓ Wireless connection established

Launching mirror...
```

Errors should be human-readable.

Avoid exposing unnecessary raw shell errors.

Provide useful recovery instructions.

---

# 14. ARCHITECTURE

Keep responsibilities separated.

### `bin/syncro`

Main entry point.

Responsible for:

- argument parsing
- initialization
- orchestration
- exit codes

### `lib/adb.sh`

Responsible for:

- ADB detection
- ADB commands
- device listing
- connection
- authorization/status handling

### `lib/device.sh`

Responsible for:

- device identification
- device selection
- known-device handling

### `lib/network.sh`

Responsible for:

- determining network information
- wireless connection logic
- connection validation

Do not implement arbitrary network scanning.

### `lib/scrcpy.sh`

Responsible for:

- scrcpy detection
- command construction
- quality presets
- FPS
- fullscreen
- launching scrcpy

### `lib/config.sh`

Responsible for:

- configuration
- known devices
- state
- validation

### `lib/ui.sh`

Responsible for:

- output
- prompts
- status indicators
- errors
- formatting

---

# 15. SECURITY

SYNCRO must be conservative.

Requirements:

- No internet transmission.
- No cloud service.
- No remote-access server.
- No intentional exposure of ADB to the public Internet.
- Do not bind ADB services to `0.0.0.0` unnecessarily.
- Do not kill unrelated processes.
- Do not modify unrelated system configuration.
- Never execute arbitrary user input with `eval`.
- Validate all command-line arguments.
- Quote shell variables properly.
- Avoid unnecessary root privileges.
- Do not require root for normal operation.

Wireless communication should remain on the user's local network.

---

# 16. SHELL IMPLEMENTATION

Prefer POSIX-compatible shell where practical.

Code must be:

- shellcheck-friendly
- modular
- readable
- defensive
- properly quoted
- explicit about exit codes

Avoid unnecessary dependencies.

Do not build a massive shell framework.

Keep the implementation lightweight.

---

# 17. TESTING

Provide tests using mocks/stubs rather than requiring a physical Android device.

Test:

### Arguments

```text
--help
--version
--list
--device
--quality
--fps
--fullscreen
--dry-run
invalid arguments
```

### Device states

```text
no device
authorized USB device
authorized Wi-Fi device
unauthorized device
offline device
multiple devices
```

### Configuration

Test:

- first run
- existing configuration
- malformed configuration
- known device
- missing configuration directory

### Network

Test:

- valid connection
- failed connection
- unreachable device
- malformed address

Document real-device integration testing separately.

---

# 18. DOCUMENTATION

README must contain:

- What SYNCRO is
- Features
- Requirements
- Supported platforms
- Installation
- Android setup
- Quick start
- Usage
- CLI options
- Quality presets
- Troubleshooting
- Security notes
- Architecture
- Development
- Testing
- Contributing
- License

Provide practical troubleshooting for:

```text
ADB not found
scrcpy not found
USB debugging disabled
device unauthorized
device offline
Wi-Fi ADB connection failed
phone and laptop on different networks
multiple devices
connection drops
poor performance
```

---

# 19. LICENSE

Use an appropriate open-source license.

SYNCRO is an independent project that uses `scrcpy` as an underlying dependency.

Do not copy large portions of scrcpy's source code into SYNCRO.

Respect scrcpy's licensing requirements and clearly document the dependency.

---

# 20. VERSIONING

Start at:

```text
0.1.0
```

Keep the version in:

```text
VERSION
```

Support:

```bash
syncro --version
```

---

# 21. V1 SUCCESS CRITERIA

V1 is successful when a user on a fresh supported Linux installation with:

```text
adb
scrcpy
```

installed can:

```bash
syncro
```

and receive a wireless Android mirror with minimal manual configuration.

After the first successful setup, a returning user should ideally be able to run:

```bash
syncro
```

and reconnect without repeating the entire setup process.

The experience should feel like:

> **Plug in once. Configure once. Sync whenever you want.**

---

# 22. FUTURE ROADMAP

Do not implement these in V1, but design the architecture so they can eventually be added:

### V2

- Audio forwarding
- Clipboard sync
- Better connection recovery
- More quality controls
- Device profiles

### V3

- File transfer
- Drag-and-drop
- Screenshot capture
- Screen recording

### Future

- GUI
- Multiple-device support
- Better device discovery
- Optional LAN discovery
- Cross-platform clients
- Additional Android management features

The architecture must not make these future features unnecessarily difficult to add.

---

# FINAL PRODUCT DIRECTION

SYNCRO should **not** become another bloated Android-management suite.

Its identity is:

**Fast. Local. Lightweight. Linux-native.**

The core experience should remain:

```bash
syncro
```

→ detect phone  
→ connect over Wi-Fi  
→ launch scrcpy  
→ mirror

Keep the implementation simple, reliable, transparent, and open source.