# Route10 Suricata Policy Handler & CLI Automation

This project provides a robust, automated solution for managing Suricata on Route10. It is specifically optimized for the Route10's 1GB RAM and offers flexible operation modes.

## Features

- **Flexible Operation Modes**:
  - **Pure CLI Mode (Recommended)**: Run Suricata independently with the Web UI **Disabled**. The script manually starts the `ips` daemon and the `suricata` engine with optimized settings for maximum stability.
  - **Optimized UI Mode**: Keep Suricata **Enabled** in the Web UI. The script detects the system process, prunes the rules, and restarts the engine, allowing the use of the UI for status monitoring while still benefiting from memory optimizations.
- **Configurable Security Categories**: Allows the user to select which security categories to keep active. Includes a recommended preset for home users that balances high protection with low memory usage.
- **Automatic Patching**: Patches the system's `suricatad.sh` and `suricata-update.sh` to prevent memory-heavy redundant update cycles (saving ~800MB RAM spikes).
- **Boot Integration**: Seamlessly integrates with the router's boot process via `/cfg/post-cfg.sh`.
- **Reactive Blocking**: Retains the hardware's "Block Level" reactive firewall integration via the `ips` daemon.
- **Multi-VLAN Support**: Automatically monitors all defined LAN interfaces (`br-lan`, `br-lan_2`, etc.).

## Installation

### 1. Upload Files

Upload the project files to your router (e.g., to `/cfg/suricata-runner/` or any directory of your choice):

- `setup.sh`
- `ips-policy.conf`
- `scripts/boot-prune.sh`
- `scripts/ips-rule-policy.sh`
- `scripts/post-update-prune.sh`
- `scripts/suricata-update.sh`
- `scripts/start.sh`

> **Note**: On the router, all these files can reside in a flat directory or maintain the `scripts/` structure; `setup.sh` will auto-detect their location.

### 2. Set Permissions

Login to your router via SSH, navigate to your upload directory, and set the appropriate permissions:

```bash
cd /path/to/your/upload
chmod 700 *.sh scripts/*.sh 2>/dev/null || chmod 700 *.sh
```

### 3. Run Setup

Execute the setup script from within your upload directory:

```bash
/bin/ash setup.sh
```

This will:

1. Patch `/usr/bin/suricatad.sh` and `/usr/bin/suricata-update.sh` to fix memory spike bugs.
2. Create the `/var/lib/suricata` and `/var/run/suricata` prerequisites.
3. Configure `/cfg/post-cfg.sh` to ensure persistence after reboot.
4. Trigger the initial rule pruning and restart Suricata.

## Verification

After installation, you can verify the system status and determine your active blocking mode.

### 1. Check if Suricata is Running

Run the following command to see the active Suricata engine:

```bash
ps -w | grep Suricata-Main
```

If active, you will see a process line for `suricata`.

### 2. Identify the Active Blocking Mode

The blocking behavior depends on the `IPS_INLINE` setting in `ips-policy.conf`:

#### **Mode A: Reactive Blocking (IPS_INLINE=0)**

*Recommended for Route10 (lowest latency).* Suricata runs as an IDS and sends alerts to the `ips` daemon, which then dynamically blocks the IP in the firewall.

- **Verify Daemon**: `ps -w | grep "/usr/sbin/ips"` should show the reactive daemon running.
- **Verify Connection**: `grep "eve-log output device (unix_dgram) initialized: /var/run/ips.sock" /var/log/suricata/suricata.log` confirms Suricata is talking to the daemon.

#### **Mode B: Inline IPS (IPS_INLINE=1)**

Suricata runs directly in the packet path (AF_PACKET) and drops packets in real-time.

- **Verify Engine Mode**: `grep "NFQ" /var/log/suricata/suricata.log` or checking for `AF_PACKET` in the log confirms inline operation.

### 3. Check for Active Blocks

To see if any IPs are currently blocked by the reactive daemon:

```bash
iptables -L ips -v -n
```

The `ips` chain will list active drops if a threat has been detected and blocked.

## Configuration

All configuration is managed in `/cfg/suricata-runner/ips-policy.conf`.

### Key Settings

- `IPS_ENABLED=1`: Must be set to 1 for the script to run.
- `IPS_INLINE=0`: Set to 0 for IDS mode with Reactive Blocking (recommended for speed).
- `IPS_ALLOWED_CATEGORIES`: Define which threats to track.

## How It Works

1. **Boot**: `/cfg/post-cfg.sh` runs at startup and triggers `boot-prune.sh` with a 120s delay.
2. **Safety Wait**: The script waits for the router to finish its "busy" boot phase.
3. **Symlink Recovery**: It restores volatile symlinks needed for Suricata rules.
4. **Pruning**: `ips-rule-policy.sh` (Python-based) comments out unnecessary rules to save RAM.
5. **Auto-Start/Optimize**:
   - If UI is **Enabled**: It restarts the system wrapper to apply pruned rules.
   - If UI is **Disabled**: It manually starts the `ips` daemon and `suricata` engine directly.

## Troubleshooting

### Check Status

```bash
# Check memory usage
free -m

# Check if Suricata engine is active
ps -w | grep Suricata-Main

# Check rule loading status
grep "rules successfully loaded" /var/log/suricata/suricata.log | tail -n 1
```

### Manual Trigger

If you want to force a re-prune and restart without rebooting:

```bash
/bin/ash /cfg/suricata-runner/boot-prune.sh 1
```

## File Structure (Repository)

```text
/
├── setup.sh               # One-time installation and persistence setup
├── ips-policy.conf        # User configuration (categories, mode)
├── scripts/
│   ├── boot-prune.sh      # Background automation (runs on every boot)
│   ├── ips-rule-policy.sh # Optimized rule pruner (Python3)
│   ├── post-update-prune.sh # Post-update maintenance
│   ├── suricata-update.sh  # Update wrapper
│   └── start.sh           # Boot wrapper for persistence
└── tests/                 # Test suite

```

## License

MIT License
