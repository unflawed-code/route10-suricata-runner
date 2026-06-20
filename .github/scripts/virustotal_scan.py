#!/usr/bin/env python3
"""Scan selected repository files with VirusTotal.

The script is intentionally dependency-free so GitHub Actions can run it
without installing packages. It first checks VirusTotal by SHA-256 and only
uploads a file when no existing report is available.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


API_BASE = "https://www.virustotal.com/api/v3"
SMALL_UPLOAD_LIMIT = 32 * 1024 * 1024
HARD_UPLOAD_LIMIT = 650 * 1024 * 1024
DEFAULT_RATE_DELAY_SECONDS = 16
DEFAULT_POLL_SECONDS = 30
DEFAULT_MAX_POLLS = 20

ARCHIVE_EXTENSIONS = (
    ".7z",
    ".apk",
    ".deb",
    ".gz",
    ".ipk",
    ".rar",
    ".rpm",
    ".tar",
    ".tar.gz",
    ".tar.xz",
    ".tgz",
    ".txz",
    ".xz",
    ".zip",
    ".zst",
)
SCRIPT_EXTENSIONS = (
    ".ash",
    ".bash",
    ".bat",
    ".cmd",
    ".js",
    ".mjs",
    ".pl",
    ".ps1",
    ".py",
    ".rb",
    ".sh",
    ".ts",
)
EXECUTABLE_EXTENSIONS = (
    ".bin",
    ".dll",
    ".dylib",
    ".elf",
    ".exe",
    ".ko",
    ".o",
    ".so",
)
ALWAYS_SCAN = {
    "vectorscan-runtime.tar.xz",
}


class VirusTotalClient:
    def __init__(self, api_key: str, rate_delay: int) -> None:
        self.api_key = api_key
        self.rate_delay = rate_delay
        self.last_request_at = 0.0

    def request(
        self,
        method: str,
        url: str,
        *,
        data: bytes | None = None,
        headers: dict[str, str] | None = None,
        expected_not_found: bool = False,
    ) -> tuple[int, dict[str, object] | None]:
        self._throttle()
        req_headers = {"x-apikey": self.api_key}
        if headers:
            req_headers.update(headers)
        req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=120) as response:
                body = response.read()
                if not body:
                    return response.status, None
                return response.status, json.loads(body.decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            if exc.code == 404 and expected_not_found:
                return exc.code, None
            if exc.code == 429:
                retry_after = int(exc.headers.get("Retry-After", self.rate_delay))
                print(f"VirusTotal rate limit reached; sleeping {retry_after}s.", flush=True)
                time.sleep(retry_after)
                return self.request(
                    method,
                    url,
                    data=data,
                    headers=headers,
                    expected_not_found=expected_not_found,
                )
            raise RuntimeError(f"VirusTotal HTTP {exc.code}: {body}") from exc

    def get_file_report(self, sha256: str) -> dict[str, object] | None:
        status, payload = self.request(
            "GET",
            f"{API_BASE}/files/{urllib.parse.quote(sha256)}",
            expected_not_found=True,
        )
        if status == 404:
            return None
        return payload

    def upload_file(self, path: Path) -> str:
        upload_url = f"{API_BASE}/files"
        if path.stat().st_size >= SMALL_UPLOAD_LIMIT:
            _, payload = self.request("GET", f"{API_BASE}/files/upload_url")
            upload_url = str(payload["data"])  # type: ignore[index]

        body, content_type = build_multipart_body(path)
        _, payload = self.request(
            "POST",
            upload_url,
            data=body,
            headers={"Content-Type": content_type},
        )
        return str(payload["data"]["id"])  # type: ignore[index]

    def get_analysis(self, analysis_id: str) -> dict[str, object]:
        _, payload = self.request("GET", f"{API_BASE}/analyses/{analysis_id}")
        return payload or {}

    def _throttle(self) -> None:
        elapsed = time.time() - self.last_request_at
        if elapsed < self.rate_delay:
            time.sleep(self.rate_delay - elapsed)
        self.last_request_at = time.time()


def build_multipart_body(path: Path) -> tuple[bytes, str]:
    boundary = f"----route10-vt-{uuid.uuid4().hex}"
    mime_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    head = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
        f"Content-Type: {mime_type}\r\n\r\n"
    ).encode("utf-8")
    tail = f"\r\n--{boundary}--\r\n".encode("utf-8")
    return head + path.read_bytes() + tail, f"multipart/form-data; boundary={boundary}"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def changed_files() -> list[Path]:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    before = ""
    after = os.environ.get("GITHUB_SHA", "HEAD")
    if event_path and Path(event_path).is_file():
        event = json.loads(Path(event_path).read_text(encoding="utf-8"))
        before = event.get("before") or ""
        after = event.get("after") or after

    if before and set(before) != {"0"}:
        diff_range = f"{before}..{after}"
    else:
        diff_range = f"{after}~1..{after}"

    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMRT", diff_range],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        print(result.stderr.strip(), file=sys.stderr)
        return []
    return [Path(line.strip()) for line in result.stdout.splitlines() if line.strip()]


def risky_files() -> list[Path]:
    return [
        path
        for path in Path(".").rglob("*")
        if path.is_file() and ".git" not in path.parts and should_scan(path)
    ]


def release_files() -> list[Path]:
    candidates: list[Path] = []
    for name in ALWAYS_SCAN:
        path = Path(name)
        if path.is_file():
            candidates.append(path)
    for extension in ARCHIVE_EXTENSIONS:
        candidates.extend(Path(".").glob(f"*{extension}"))
    return sorted(set(candidates))


def should_scan(path: Path) -> bool:
    name = path.as_posix().lstrip("./")
    suffixes = "".join(path.suffixes).lower()
    suffix = path.suffix.lower()
    if name in ALWAYS_SCAN:
        return True
    if suffixes.endswith(ARCHIVE_EXTENSIONS):
        return True
    if suffix in SCRIPT_EXTENSIONS or suffix in EXECUTABLE_EXTENSIONS:
        return True
    try:
        with path.open("rb") as handle:
            prefix = handle.read(4)
        return prefix.startswith(b"#!") or prefix == b"\x7fELF"
    except OSError:
        return False


def selected_files(mode: str) -> list[Path]:
    if mode == "changed":
        paths = [path for path in changed_files() if path.is_file() and should_scan(path)]
    elif mode == "release":
        paths = release_files()
    elif mode == "all-risky":
        paths = risky_files()
    else:
        raise ValueError(f"Unknown scan mode: {mode}")
    return sorted(set(paths))


def summarize_stats(payload: dict[str, object]) -> dict[str, int]:
    data = payload.get("data", {})
    attributes = data.get("attributes", {}) if isinstance(data, dict) else {}
    stats = attributes.get("last_analysis_stats") or attributes.get("stats") or {}
    if not isinstance(stats, dict):
        return {}
    return {str(key): int(value) for key, value in stats.items()}


def poll_analysis(
    client: VirusTotalClient,
    analysis_id: str,
    *,
    poll_seconds: int,
    max_polls: int,
) -> dict[str, object]:
    for attempt in range(1, max_polls + 1):
        payload = client.get_analysis(analysis_id)
        data = payload.get("data", {})
        attributes = data.get("attributes", {}) if isinstance(data, dict) else {}
        status = attributes.get("status") if isinstance(attributes, dict) else None
        if status == "completed":
            return payload
        print(f"Analysis {analysis_id} is {status}; poll {attempt}/{max_polls}.", flush=True)
        time.sleep(poll_seconds)
    raise RuntimeError(f"Timed out waiting for VirusTotal analysis {analysis_id}")


def markdown_row(path: Path, sha256: str, stats: dict[str, int], source: str) -> str:
    malicious = stats.get("malicious", 0)
    suspicious = stats.get("suspicious", 0)
    harmless = stats.get("harmless", 0)
    undetected = stats.get("undetected", 0)
    return (
        f"| `{path.as_posix()}` | `{sha256[:12]}` | {source} | "
        f"{malicious} | {suspicious} | {harmless} | {undetected} |"
    )


def write_summary(rows: list[str]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with Path(summary_path).open("a", encoding="utf-8") as handle:
        handle.write("## VirusTotal scan\n\n")
        if not rows:
            handle.write("No matching files were selected for scanning.\n")
            return
        handle.write("| File | SHA-256 | Source | Malicious | Suspicious | Harmless | Undetected |\n")
        handle.write("| --- | --- | --- | ---: | ---: | ---: | ---: |\n")
        for row in rows:
            handle.write(row + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("changed", "release", "all-risky"), required=True)
    parser.add_argument("--max-files", type=int, default=int(os.environ.get("VT_MAX_FILES", "15")))
    parser.add_argument(
        "--rate-delay",
        type=int,
        default=int(os.environ.get("VT_RATE_DELAY_SECONDS", str(DEFAULT_RATE_DELAY_SECONDS))),
    )
    parser.add_argument(
        "--poll-seconds",
        type=int,
        default=int(os.environ.get("VT_POLL_SECONDS", str(DEFAULT_POLL_SECONDS))),
    )
    parser.add_argument(
        "--max-polls",
        type=int,
        default=int(os.environ.get("VT_MAX_POLLS", str(DEFAULT_MAX_POLLS))),
    )
    args = parser.parse_args()

    api_key = os.environ.get("VT_API_KEY")
    if not api_key:
        print("VT_API_KEY is not set.", file=sys.stderr)
        return 2

    files = selected_files(args.mode)
    if len(files) > args.max_files:
        print(
            f"Selected {len(files)} files, which exceeds VT_MAX_FILES={args.max_files}.",
            file=sys.stderr,
        )
        print("Narrow the push or run workflow_dispatch with a higher limit.", file=sys.stderr)
        return 2

    if not files:
        print("No matching files selected for VirusTotal scanning.")
        write_summary([])
        return 0

    client = VirusTotalClient(api_key, args.rate_delay)
    fail_on_suspicious = os.environ.get("VT_FAIL_ON_SUSPICIOUS", "1") == "1"
    failures: list[str] = []
    rows: list[str] = []

    print(f"VirusTotal scan mode: {args.mode}")
    for path in files:
        size = path.stat().st_size
        if size > HARD_UPLOAD_LIMIT:
            failures.append(f"{path}: file is larger than VirusTotal's 650MB upload limit")
            continue

        sha256 = sha256_file(path)
        print(f"Checking {path} ({size} bytes, sha256={sha256})", flush=True)
        report = client.get_file_report(sha256)
        source = "existing"
        if report is None:
            print(f"No existing report for {path}; uploading.", flush=True)
            analysis_id = client.upload_file(path)
            report = poll_analysis(
                client,
                analysis_id,
                poll_seconds=args.poll_seconds,
                max_polls=args.max_polls,
            )
            source = "uploaded"

        stats = summarize_stats(report)
        rows.append(markdown_row(path, sha256, stats, source))
        malicious = stats.get("malicious", 0)
        suspicious = stats.get("suspicious", 0)
        if malicious > 0 or (fail_on_suspicious and suspicious > 0):
            failures.append(
                f"{path}: malicious={malicious}, suspicious={suspicious}, sha256={sha256}"
            )

    write_summary(rows)
    if failures:
        print("VirusTotal detections found:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("VirusTotal scan completed without malicious or suspicious detections.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
