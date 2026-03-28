# v2.0.0-rc2

### FEATURES & OPTIMIZATIONS

**nDPI 5.0 Upgrade & Advanced Security**
* **Upgraded nDPI to 5.0 (Stable)**: Provides the latest protocol detection registry and advanced fingerprinting capabilities (including JA4 support).
* **Risk-Based Security Rules**: Added `rules/route10-ndpi-security.rules` leveraging 56 behavioral risk factors (e.g., malware host contact, obfuscated traffic, DNS bypass).
* **Security Library**: Introduced `rules/ndpi-security-library.md` as an authoritative reference for all nDPI risk factors and corresponding Suricata rules.
* **Bypass Library Update**: Completely regenerated `rules/ndpi-bypass-library.md` with accurate, case-sensitive protocol names for nDPI 5.0 compatibility.

**Automation & Intelligence**
* **Dynamic LAN Detection**: Replaced hardcoded interface lists with intelligent auto-detection of LAN bridge interfaces via OpenWrt firewall/network configuration.
* **Robust Protocol Matching**: Fixed case-sensitivity issues in bypass rules (e.g., `AmazonVideo`, `NetFlix`, `YouTube`) to align with the new nDPI 5.0 registry.
* **Enhanced Status Reporting**: Improved `runner.sh status` to accurately detect active rule files regardless of indentation and added nDPI security status reporting.

**Infrastructure & Build**
* **nDPI 5.0 Plugin Compatibility**: Applied critical C-level fixes to the Suricata nDPI plugin (`ndpi.c`) to support the new nDPI 5.0 API.
* **Extreme Archive Compression**: Implemented high-efficiency `tar.xz` packaging, reducing the runtime archive to ~6MB.

---

# v2.0.0 (Release Candidate)

### FEATURES & OPTIMIZATIONS

**Suricata 8.0.4 Runtime & nDPI Support**
* Updated the bundled runtime to **Suricata 8.0.4**, aligned with Vectorscan 5.4.12.
* Introduced **nDPI support**: provides application-aware detection keywords for granular traffic identification.
* Added **Bypass Rules support**: includes managed pass-rules (`rules/route10-ndpi-bypass.rules`) to reduce inspection overhead for trusted or high-volume streams.
* Enabled the **WebSocket app-layer parser** by default in the custom runtime.

**Autonomous Update System**
* Added a Git-independent update mechanism via `scripts/updater.sh` that fetches releases directly from GitHub.
* Implemented **Atomic Rollback protection**: performs full project directory backups before updates, with automatic restoration on failure.
* Utilizes a **redirect-following method** for version checks to bypass GitHub API rate limits.
* Added `ENABLE_AUTO_UPDATE` policy toggle to `ips-policy.conf`.

**System-Level Version Validation**
* Integrated **OpenWrt UCI tracking** for full environment validation (`suricata-runner.system.*`).
* Enhanced `runner.sh status` to detect and report "version drift" between scripts and system state.

**Persistence & Stability**
* Updated `setup.sh` to enable the `/cfg/post-cfg.sh` boot integration by default.
* Optimized memory usage by canonicalizing cron jobs to avoid overlapping cycles.

**CLI Enhancements**
* Added `runner.sh update` and `runner.sh status` commands for lifecycle and operational visibility.
* Standardized execution via the self-contained `setup.sh`.

**Full Changelog**: [v1.1.0...v2.0.0-rc2](https://github.com/unflawed-code/route10-suricata-runner/compare/v1.1.0...v2.0.0-rc2)

---

### BREAKING CHANGES & MIGRATION

**Breaking Changes**
* **CLI Wrapper Removal**: The `runner.sh setup` command has been removed. Use `/bin/ash setup.sh`.
* **UCI Requirement**: A manual run of `setup.sh` is mandatory to initialize version tracking.
* **nDPI Protocol Case-Sensitivity**: Protocol names in rules are now case-sensitive (e.g., must use `AmazonVideo` not `amazon_video`).

**Migration Steps (v1.x.x -> v2.0.0)**
1. **Upload New Files**: Overwrite all files, including `vectorscan-runtime.tar.xz`.
2. **Execute Setup**: 
   ```bash
   /bin/ash setup.sh
   ```
3. **Verify**: Run `runner.sh status` to confirm synchronization.
