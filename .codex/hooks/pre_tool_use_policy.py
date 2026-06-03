#!/usr/bin/env python3
import json
import re
import sys


BLOCKED_PATTERNS = (
    r"rm\s+-rf",
    r"git\s+push\s+--force",
    r"git\s+reset\s+--hard",
    r"DROP\s+TABLE",
)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    tool_input = payload.get("tool_input") or {}
    command = tool_input.get("command") or payload.get("command") or ""

    if any(re.search(pattern, command, re.IGNORECASE) for pattern in BLOCKED_PATTERNS):
        print("BLOCKED: 위험한 명령어가 감지되었습니다.", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
