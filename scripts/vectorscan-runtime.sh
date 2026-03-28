#!/bin/ash

resolve_remote_dir() {
    local self_dir
    self_dir="$(cd "$(dirname "$1")" && pwd)"
    if [ "$(basename "$self_dir")" = "scripts" ]; then
        dirname "$self_dir"
    else
        echo "$self_dir"
    fi
}

find_vectorscan_helper_archive() {
    local remote_dir="$1"
    local candidate

    for candidate in \
        "${remote_dir}/vectorscan-runtime.tar.xz" \
        "${remote_dir}/vectorscan/vectorscan-runtime.tar.xz" \
        "${remote_dir}/vectorscan-runtime.zip" \
        "${remote_dir}/vectorscan/vectorscan-runtime.zip"
    do
        [ -f "$candidate" ] && {
            echo "$candidate"
            return 0
        }
    done

    return 1
}

ensure_vectorscan_runtime_from_archive() {
    link_latest_lib() {
        local lib_dir="$1"
        local glob="$2"
        local direct_link="$3"
        local major_link="$4"
        local real_name=""

        real_name="$(basename "$(ls -1 ${lib_dir}/${glob} 2>/dev/null | sort | tail -n 1)")"
        [ -n "${real_name:-}" ] || return 0
        [ -f "${lib_dir}/${real_name}" ] || return 0

        if [ -n "$major_link" ]; then
            ln -sf "$real_name" "${lib_dir}/${major_link}"
            ln -sf "$major_link" "${lib_dir}/${direct_link}"
        else
            ln -sf "$real_name" "${lib_dir}/${direct_link}"
        fi
    }

    local remote_dir="$1"
    local runtime_root="${2:-/a/suricata-vectorscan}"
    local archive_path tmp_dir lib_dir py_bin ndpi_real ndpi_major

    archive_path="$(find_vectorscan_helper_archive "$remote_dir")" || {
        echo "ERROR: Missing Vectorscan runtime archive (zip or tar.xz)." >&2
        return 1
    }

    tmp_dir="${runtime_root}.tmp"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir" || {
        echo "ERROR: Failed to create temporary runtime directory $tmp_dir" >&2
        return 1
    }

    case "$archive_path" in
        *.tar.xz)
            if command -v tar >/dev/null 2>&1 && command -v xz >/dev/null 2>&1; then
                xz -dc "$archive_path" | tar -xf - -C "$tmp_dir" || {
                    rm -rf "$tmp_dir"
                    echo "ERROR: Failed to extract $archive_path with tar/xz" >&2
                    return 1
                }
            else
                rm -rf "$tmp_dir"
                echo "ERROR: xz or tar not found for $archive_path" >&2
                return 1
            fi
            ;;
        *.zip)
            if command -v unzip >/dev/null 2>&1; then
                unzip -oq "$archive_path" -d "$tmp_dir" || {
                    rm -rf "$tmp_dir"
                    echo "ERROR: Failed to extract $archive_path with unzip" >&2
                    return 1
                }
            else
                py_bin="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
                [ -n "$py_bin" ] || {
                    rm -rf "$tmp_dir"
                    echo "ERROR: Neither unzip nor python is available to extract $archive_path" >&2
                    return 1
                }
                "$py_bin" - "$archive_path" "$tmp_dir" <<'PYEOF' || {
import sys
import zipfile

zip_path = sys.argv[1]
dest_dir = sys.argv[2]

with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(dest_dir)
PYEOF
                    rm -rf "$tmp_dir"
                    echo "ERROR: Failed to extract $archive_path with python" >&2
                    return 1
                }
            fi
            ;;
    esac

    [ -x "${tmp_dir}/bin/suricata" ] || chmod 755 "${tmp_dir}/bin/"* 2>/dev/null || true
    lib_dir="${tmp_dir}/lib"
    link_latest_lib "$lib_dir" 'libhs.so.5.*' 'libhs.so' 'libhs.so.5'
    link_latest_lib "$lib_dir" 'libhs_runtime.so.5.*' 'libhs_runtime.so' 'libhs_runtime.so.5'
    if [ -f "${lib_dir}/libstdc++.so.6.0.30" ]; then
        ln -sf libstdc++.so.6.0.30 "${lib_dir}/libstdc++.so.6"
    fi
    ndpi_real="$(basename "$(ls -1 "${lib_dir}"/libndpi.so.* 2>/dev/null | sort | tail -n 1)")"
    if [ -n "${ndpi_real:-}" ] && [ -f "${lib_dir}/${ndpi_real}" ]; then
        ndpi_major="$(printf '%s' "$ndpi_real" | sed -n 's/^libndpi\.so\.\([0-9][0-9]*\)\..*/\1/p')"
        if [ -n "${ndpi_major:-}" ]; then
            ln -sf "$ndpi_real" "${lib_dir}/libndpi.so.${ndpi_major}"
            ln -sf "libndpi.so.${ndpi_major}" "${lib_dir}/libndpi.so"
        else
            ln -sf "$ndpi_real" "${lib_dir}/libndpi.so"
        fi
    fi

    rm -rf "$runtime_root"
    mv "$tmp_dir" "$runtime_root" || {
        rm -rf "$tmp_dir"
        echo "ERROR: Failed to activate Vectorscan runtime at $runtime_root" >&2
        return 1
    }

    ln -snf "$runtime_root" "${remote_dir}/vectorscan"
    return 0
}
