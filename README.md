# Route10 Suricata Runner

This project provides a robust, automated solution for managing Suricata on Route10. It is specifically optimized for the Route10's 1GB RAM and offers flexible operation modes, including a custom high-performance Vectorscan runtime.

- **Aggressive ET rule pruning**: Optimized for constrained hardware.
- **Automatic switching**: Seamlessly toggles between `IDS + reactive blocking` and `inline IPS`.
- **Custom high-performance runtime**: Packaged under `vectorscan-runtime.tar.xz` with:
  - `Suricata 8.0.4`
  - `Vectorscan 5.4.12`
  - `nDPI 5.0`

## Features

- **`runner.sh` CLI**: A canonical interface for all operations (setup, status, updates).
- **Flexible Operation Modes**:
  - **Pure CLI Mode (Recommended)**: Run Suricata independently with the Web UI **Disabled** for maximum stability.
  - **Optimized UI Mode**: Keep Suricata **Enabled** in the Web UI while benefiting from memory optimizations and rule pruning.
- **Automated Updates**: Daily automated script and rule updates via GitHub with atomic rollback protection. Schedule is configurable in `ips-policy.conf`.
- **UCI Version Validation**: System-level tracking of Runner, Suricata, Vectorscan, and nDPI versions via OpenWrt's UCI database.
- **Automatic Patching**: Patches the system's `suricatad.sh` and `suricata-update.sh` to prevent memory-heavy redundant update cycles (saving ~800MB RAM spikes).
- **Runtime Hardening**: Disables crash-prone and memory-heavy Suricata outputs like `file-store` and `pcap-log`.
- **Boot Integration**: Seamlessly integrates with the router's boot process via `/cfg/post-cfg.sh` (Enabled by default).

## Installation

Upload the project files to your router (e.g., to `/cfg/suricata-runner/`):

### Required Files

- `runner.sh`
- `setup.sh`
- `ips-policy.conf`
- `vectorscan-runtime.tar.xz`
- `rules/route10-websocket.rules.template`
- `rules/route10-ndpi-bypass.rules.template`
- `rules/route10-ndpi-security.rules.template`
- `scripts/start.sh`
- `scripts/boot-prune.sh`
- `scripts/ips-rule-policy.sh`
- `scripts/post-update-prune.sh`
- `scripts/stream-fix.sh`
- `scripts/suricata-update.sh`
- `scripts/updater.sh`
- `scripts/vectorscan-runtime.sh`
- `scripts/version.sh`

### 1. Set Permissions

```bash
cd /cfg/suricata-runner
chmod 700 *.sh scripts/*.sh 2>/dev/null || chmod 700 *.sh
```

### 2. Run Setup

```bash
/bin/ash setup.sh
```

This will:

1. Extract `vectorscan-runtime.tar.xz` into `/a/suricata-vectorscan`.
2. Patch system scripts to fix memory spike bugs.
3. Install/update the managed startup hook in `/cfg/post-cfg.sh` (**Enabled by default**).
4. Canonicalize nightly Suricata and Runner update cron entries.
5. Initialize local `.rules` files from `.template` if they don't already exist.
6. Synchronize all version info (Runner, Suricata, nDPI, Vectorscan) to UCI.
7. Trigger the initial rule pruning and start Suricata.

## Rule Management & Persistence

The rule management system is designed to protect your local customizations while providing a stable, versioned baseline:

- **Initialization Options**:
  - **Automatic (Recommended)**: Running `setup.sh` will automatically detect any missing `.rules` files in the `rules/` directory and create them from the corresponding `.rules.template` reference.
  - **Manual**: You can manually copy any `rules/*.rules.template` to `rules/*.rules` if you wish to seed them before the initial setup.

- **Custom Rules**: Once the `.rules` file exists, you should perform all your custom rule additions directly in that file. Use standard Suricata rule syntax.

- **Update Safety**: Since these files aren't in the project repo, a `runner.sh update` will **never** overwrite your custom rule definitions. The update package only contains the `.template` references.

> [!TIP]
> To reset a specific rule set (e.g., nDPI bypass) to its original factory state, simply delete the `.rules` file and run `setup.sh` again to re-seed it from the template.

## Uninstallation

To revert all system changes and stop Suricata:

```bash
/bin/ash scripts/uninstall.sh
```

This script will:

- Stop Suricata and the IPS daemon.
- Restore original system scripts and rule policy handlers.
- Remove project cron jobs and the boot persistence hook.
- Clean up custom firewall rules and UCI configuration.
- Delete the Vectorscan runtime at `/a/suricata-vectorscan`.

## Migration (v1.x.x -> v2.0.0)

Upgrading from v1.x.x to v2.0.0 introduces the **Rule Template** system and **UCI Version Tracking**.

1. **Backup Config**: Save a copy of your current `ips-policy.conf`.
2. **Replace Files**: Overwrite all project files.
   - *Note*: Existing `.rules` files in the `rules/` directory are **preserved** by `setup.sh`. You will be responsible for setting your own rules.
3. **Execute Setup**:

   ```bash
   /bin/ash setup.sh
   ```

4. **Merge Config**: Compare your backed-up `ips-policy.conf` with the new one and adjust accordingly.
5. **Verify**: Run `runner.sh status` to ensure all versions are synced to UCI.

## CLI

`runner.sh` is the primary interface for managing the system.

```bash
/bin/ash runner.sh apply         # Re-read policy and restart Suricata
/bin/ash runner.sh status        # View operational summary and version sync
/bin/ash runner.sh update        # Manually check for GitHub updates
/bin/ash runner.sh update --force # Force re-installation of the latest version
/bin/ash runner.sh version       # Show detailed version information
```

## Policy

Configuration is managed in `ips-policy.conf`.

### Core Settings

- `IPS_ENABLED=1`: Default is 1. Global toggle.
- `IPS_INLINE=0`: Reactive Blocking (IDS mode - recommended for speed).
- `IPS_INLINE=1`: Default. Inline NFQUEUE mode.
- `IPS_INLINE_BLOCK=1`: Default. Convert active kept inline `alert` rules to `drop` for real-time blocking.
- `IPS_INLINE_BLOCK=0`: Keep inline NFQUEUE inspection active, but leave active rules as `alert` only.

### Feature Toggles

- `ENABLE_NDPI=1`: Default is 1. Loads the nDPI application-aware plugin.
- `ENABLE_WEBSOCKET=1`: Default is 1. Enables the WebSocket app-layer parser.
- `ENABLE_AUTO_UPDATE=0`: Default is disabled. Set this to 1 to enable daily automated updates from GitHub.
- `RUNNER_UPDATE_CRON="30 4 * * *"`: Cron schedule for `runner.sh update` when auto-update is enabled.
- `SURICATA_UPDATE_CRON="30 3 * * *"`: Cron schedule for nightly `suricata-update`.
- `POST_UPDATE_PRUNE_CRON="32 3 * * *"`: Cron schedule for the post-update prune pass.

## Optimization Results

- **Rule Reduction**: The `ips-policy.conf` allows configuring specific threat categories to load. Activating only a few critical categories can drastically reduce the active ruleset, saving significant memory rather than loading all ~65,000 rules from the Emerging Threats (ET) ruleset.
- **Memory Stability**: Patching Route10's `suricata-update.sh` prevents a redundant update bug that causes ~800MB RAM spikes. Combined with disabling heavy logging features, this prevents OOM (Out Of Memory) crashes on 1GB routers.
- **Performance**: Custom Vectorscan integration provides high-speed pattern matching.

## Verification

Check the system status to verify your active mode and version sync:

```bash
/bin/ash runner.sh status
```

It reports:

- Current project directory.
- Version status (with UCI sync validation).
- Process status (Suricata, IPS daemon).
- Active Matcher (e.g., `mpm-hs active`).
- Plugin and Parser states.
- Cron job wiring and Boot Hook status.

## License

MIT License
