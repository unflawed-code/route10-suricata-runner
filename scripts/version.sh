#!/bin/ash

# These are the "Code" versions (what is currently in the scripts)
SURICATA_RUNNER_NAME="Route10 Suricata Runner"
SURICATA_RUNNER_VERSION="2.0.0-rc1"
SURICATA_RUNNER_AUTHOR="https://github.com/unflawed-code"
SURICATA_BUNDLED_VERSION="8.0.4"
VECTORSCAN_BUNDLED_VERSION="5.4.12"
NDPI_BUNDLED_VERSION="4.14"
SURICATA_BUNDLED_ARCH="aarch64"

get_suricata_runner_version() {
    printf '%s' "$SURICATA_RUNNER_VERSION"
}

get_uci_version() {
    # $1 = key (version, suricata, vectorscan, ndpi)
    uci -q get suricata-runner.system."$1" | tr -d '\r[:space:]' || true
}

print_suricata_runner_version() {
    local uci_v uci_s uci_vs uci_n sync_warn=""
    
    uci_v=$(get_uci_version "version")
    uci_s=$(get_uci_version "suricata")
    uci_vs=$(get_uci_version "vectorscan")
    uci_n=$(get_uci_version "ndpi")
    
    # Check for any desync
    if [ -n "$uci_v" ] && { [ "$uci_v" != "$SURICATA_RUNNER_VERSION" ] || \
                         [ "$uci_s" != "$SURICATA_BUNDLED_VERSION" ] || \
                         [ "$uci_vs" != "$VECTORSCAN_BUNDLED_VERSION" ] || \
                         [ "$uci_n" != "$NDPI_BUNDLED_VERSION" ]; }; then
        sync_warn=" (Setup required to sync)"
    fi

    cat <<EOF
------------------------------------    
$SURICATA_RUNNER_NAME v$SURICATA_RUNNER_VERSION$sync_warn
$SURICATA_RUNNER_AUTHOR
------------------------------------
Bundled System: $SURICATA_BUNDLED_ARCH
    Components: Suricata $SURICATA_BUNDLED_VERSION
                nDPI $NDPI_BUNDLED_VERSION
                Vectorscan $VECTORSCAN_BUNDLED_VERSION
------------------------------------        
EOF
    
    if [ -n "$sync_warn" ]; then
        echo "WARNING: Installed UCI state does not match script versions:"
        [ "$uci_v" != "$SURICATA_RUNNER_VERSION" ] && echo " - Runner: $uci_v -> $SURICATA_RUNNER_VERSION"
        [ "$uci_s" != "$SURICATA_BUNDLED_VERSION" ] && echo " - Suricata: $uci_s -> $SURICATA_BUNDLED_VERSION"
        [ "$uci_vs" != "$VECTORSCAN_BUNDLED_VERSION" ] && echo " - Vectorscan: $uci_vs -> $VECTORSCAN_BUNDLED_VERSION"
        [ "$uci_n" != "$NDPI_BUNDLED_VERSION" ] && echo " - nDPI: $uci_n -> $NDPI_BUNDLED_VERSION"
        echo "------------------------------------"
    fi
}
