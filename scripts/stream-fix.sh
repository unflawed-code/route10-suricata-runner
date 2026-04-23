#!/bin/ash
# Shared inline IPS compatibility patches for Route10 Suricata runtime YAMLs.

apply_stream_stability_patches() {
    local yaml="$1"

    [ -f "$yaml" ] || return 0

    # NSS/offload can present packets with bad checksums to the CPU path.
    sed -i 's/checksum-validation: yes/checksum-validation: no/' "$yaml"

    # Allow Suricata to attach to already-established connections safely.
    sed -i 's/^#midstream: false/midstream: true/' "$yaml"
    sed -i 's/^[[:space:]]*midstream:[[:space:]]*false/  midstream: true/' "$yaml"

    # Inline mode should ignore engine exceptions instead of silently dropping.
    sed -i 's/^  #memcap-policy: ignore/  memcap-policy: ignore/' "$yaml"
    sed -i 's/^  #midstream-policy: ignore/  midstream-policy: ignore/' "$yaml"
    sed -i 's/    #memcap-policy: ignore/    memcap-policy: ignore/' "$yaml"
    if ! grep -q 'drop-invalid: no' "$yaml"; then
        sed -i '/^  inline: auto/a\  drop-invalid: no' "$yaml"
    fi

    # Keep rule-driven drops visible during troubleshooting.
    sed -i '/- fast:/,/enabled:/ s/enabled: no/enabled: yes/' "$yaml"
}
