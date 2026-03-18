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

Upload the following files to your router at `/cfg/suricata-custom/`:

- `setup.sh`
- `boot-prune.sh`
- `ips-rule-policy.sh`
- `ips-policy.conf`
- `ips-policy.override.conf`

### 2. Set Permissions

Login to your router via SSH and set the appropriate permissions on the scripts:

```bash
chmod 700 /cfg/suricata-custom/*.sh
```

### 3. Run Setup

Execute the setup script manually to configure symlinks and apply memory patches:

```bash
/bin/ash /cfg/suricata-custom/setup.sh
```

This will:

1. Patch `/usr/bin/suricatad.sh` and `/usr/bin/suricata-update.sh` to fix memory spike bugs.
2. Create the `/var/lib/suricata` and `/var/run/suricata` prerequisites.
3. Configure `/cfg/post-cfg.sh` to ensure persistence after reboot.
4. Trigger the initial rule pruning and restart Suricata.

## Configuration

All configuration is managed in `/cfg/suricata-custom/ips-policy.conf`.

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
/bin/ash /cfg/suricata-custom/boot-prune.sh 1
```

## File Structure

```text
/cfg/suricata-custom/
├── setup.sh               # One-time installation and persistence setup
├── boot-prune.sh          # Background automation (runs on every boot)
├── ips-rule-policy.sh     # Optimized rule pruner (Python3)
├── ips-policy.conf        # User configuration (categories, mode)
└── ips-policy.override.conf # Custom overrides
```

## License

MIT License
