#!/usr/bin/env python3
"""Writes manifest.json and SHA256SUMS for a nightly release.

    write-manifest.py <dist-dir> --tag <tag> --repository <owner/repo>

The manifest is the one file a consumer needs to know about: it names the commits the release was
built from and lists every asset with its checksum, so a binding pins a tag and verifies what it
downloads against it.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

NATIVE_RE = re.compile(r"^opendaq-native-(?P<triple>[\w-]+)\.tar\.gz$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset(path: Path) -> dict:
    return {"file": path.name, "sha256": sha256(path), "size": path.stat().st_size}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dist", type=Path)
    ap.add_argument("--tag", required=True)
    ap.add_argument("--repository", required=True, help="owner/repo the release is published in")
    args = ap.parse_args()

    info = dict(
        line.split("=", 1)
        for line in (args.dist / "source-info.env").read_text().splitlines()
        if "=" in line
    )
    spec_path = args.dist / "opendaq.json"
    spec = json.loads(spec_path.read_text())

    natives = {}
    for path in sorted(args.dist.iterdir()):
        m = NATIVE_RE.match(path.name)
        if m:
            natives[m.group("triple")] = asset(path)
    if not natives:
        raise SystemExit(f"no opendaq-native-*.tar.gz in {args.dist}")

    manifest = {
        "schema": "opendaq-bindings-nightly/1",
        "tag": args.tag,
        "base_url": f"https://github.com/{args.repository}/releases/download/{args.tag}/",
        "upstream": {"repo": info["UPSTREAM_REPO"], "ref": info["UPSTREAM_REF"], "sha": info["UPSTREAM_SHA"]},
        "spec": {**asset(spec_path), "schema": spec.get("schema")},
        "c_headers": asset(args.dist / "opendaq-c-headers.tar.gz"),
        "natives": natives,
    }
    if info.get("OVERLAY_SHA"):
        manifest["overlay"] = {
            "repo": info["OVERLAY_REPO"],
            "ref": info["OVERLAY_REF"],
            "sha": info["OVERLAY_SHA"],
            "patch": asset(args.dist / "bindings-overlay.patch"),
        }

    (args.dist / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    listed = [spec_path, args.dist / "opendaq-c-headers.tar.gz", args.dist / "bindings-overlay.patch"]
    listed += [args.dist / entry["file"] for entry in natives.values()]
    lines = [f"{sha256(p)}  {p.name}" for p in listed if p.exists()]
    (args.dist / "SHA256SUMS").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
