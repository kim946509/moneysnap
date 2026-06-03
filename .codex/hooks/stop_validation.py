#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path


def main() -> int:
    package_json = Path("package.json")
    if not package_json.exists():
        return 0

    try:
        package = json.loads(package_json.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print("package.json 파싱에 실패했습니다.", file=sys.stderr)
        return 1

    scripts = package.get("scripts") or {}
    for script in ("lint", "build", "test"):
        if script not in scripts:
            continue
        result = subprocess.run(["npm", "run", script], text=True)
        if result.returncode != 0:
            return result.returncode

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
