# Route10 Suricata Runner

This project provides a robust, automated solution for managing Suricata on Route10. It is specifically optimized for the Route10's 1GB RAM and offers flexible operation modes, including a custom high-performance Vectorscan runtime.

- **Aggressive ET rule pruning**: Optimized for constrained hardware.
- **Automatic switching**: Seamlessly toggles between `IDS + reactive blocking` and `inline IPS`.
- **Custom high-performance runtime**: Packaged under `vectorscan-runtime.tar.xz` with:
  - `Suricata 8.0.4`
  - `Vectorscan 5.4.12`
  - `nDPI 4.14`

## Features

- **`runner.sh` CLI**: A canonical interface for all operations (setup, status, updates).
- **Flexible Operation Modes**:
  - **Pure CLI Mode (Recommended)**: Run Suricata independently with the Web UI **Disabled** for maximum stability.
  - **Optimized UI Mode**: Keep Suricata **Enabled** in the Web UI while benefiting from memory optimizations and rule pruning.
- **Automated Updates**: Daily automated script and rule updates via GitHub (at 4:30 AM) with atomic rollback protection.
- **UCI Version Validation**: System-level tracking of Runner, Suricata, Vectorscan, and nDPI versions via OpenWrt's UCI database.
- **Automatic Patching**: Patches the system's `suricatad.sh` and `suricata-update.sh` to prevent memory-heavy redundant update cycles (saving ~800MB RAM spikes).
- **Runtime Hardening**: Disables crash-prone and memory-heavy Suricata outputs like `file-store` and `pcap-log`.
- **Boot Integration**: Seamlessly integrates with the router's boot process via `/cfg/post-cfg.sh` (Enabled by default).
- **Inline Performance Tuning**: Optimized settings for NFQUEUE including worker runmode, CPU affinity, and high-detection profiles.
- **Managed Local Rules**: Custom rules for WebSocket inspection and nDPI application-aware bypass.

## Installation

Upload the project files to your router (e.g., to `/cfg/suricata-runner/`):

### Required Files

- `runner.sh`
- `setup.sh`
- `ips-policy.conf`
- `vectorscan-runtime.tar.xz`
- `rules/route10-websocket.rules`
- `rules/route10-ndpi-bypass.rules`
- `scripts/start.sh`
- `scripts/boot-prune.sh`
- `scripts/ips-rule-policy.sh`
- `scripts/post-update-prune.sh`
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
5. Synchronize all version info (Runner, Suricata, nDPI, Vectorscan) to UCI.
6. Trigger the initial rule pruning and start Suricata.

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

Upgrading from v1.x.x to v2.0.0 requires a manual configuration update and a fresh setup run to initialize the UCI version tracking.

1. **Replace files**: Overwrite all files in your project directory with the v2.0.0 versions.
2. **Update Config**: Add `ENABLE_AUTO_UPDATE=0` to your `ips-policy.conf` file.
3. **Execute Setup**:

   ```bash
   /bin/ash setup.sh
   ```

4. **Verify**: Check `runner.sh status` to ensure all components are synced and the new update cron is visible.

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

- `IPS_ENABLED=1`: Global toggle.
- `IPS_INLINE=0`: Reactive Blocking (IDS mode - recommended for speed).
- `IPS_INLINE=1`: Inline IPS (NFQUEUE mode - real-time drops).

### Feature Toggles

- `ENABLE_NDPI=1`: Loads the nDPI application-aware plugin.
- `ENABLE_WEBSOCKET=1`: Enables the WebSocket app-layer parser.
- `ENABLE_AUTO_UPDATE=1`: Enables daily automated updates from GitHub.

## Optimization Results

- **Rule Reduction**: Typically reduces the ruleset from ~65,000 rules down to **~7,000 active rules** (an ~89% reduction).
- **Memory Stability**: Pruning and patching prevents OOM (Out Of Memory) kills common with default settings.
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
