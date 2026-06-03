#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


IGNORED_PATTERNS = (
    re.compile(r"(^|[/\\])(__tests__|tests?)([/\\]|$)", re.IGNORECASE),
    re.compile(r"\.(test|spec)\.(ts|tsx|js|jsx)$", re.IGNORECASE),
    re.compile(r"\.(json|css|scss|md|yml|yaml)$", re.IGNORECASE),
    re.compile(r"\.env", re.IGNORECASE),
    re.compile(r"\.config\.", re.IGNORECASE),
    re.compile(r"(tailwind|postcss|next\.config|tsconfig)", re.IGNORECASE),
    re.compile(r"(^|[/\\])types([/\\]|$)", re.IGNORECASE),
    re.compile(r"(^|[/\\])types\.ts$", re.IGNORECASE),
    re.compile(r"\.d\.ts$", re.IGNORECASE),
    re.compile(r"[/\\](layout|page|loading|error|not-found)\.tsx?$", re.IGNORECASE),
    re.compile(r"[/\\]globals\.css$", re.IGNORECASE),
)


def deny(reason: str) -> int:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))
    return 0


def extract_paths(payload: dict) -> list[tuple[str, str]]:
    tool_input = payload.get("tool_input") or {}
    items: list[tuple[str, str]] = []

    for key in ("file_path", "path", "filename"):
        value = tool_input.get(key)
        if isinstance(value, str) and value:
            items.append(("update", value))

    command = tool_input.get("command") or tool_input.get("cmd") or ""
    if isinstance(command, str):
        for line in command.splitlines():
            match = re.match(r"^\*\*\* (Add|Update|Delete) File: (.+)$", line)
            if match:
                items.append((match.group(1).lower(), match.group(2).strip()))
                continue
            match = re.match(r"^\*\*\* Move to: (.+)$", line)
            if match:
                items.append(("update", match.group(1).strip()))

    deduped = []
    seen = set()
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        deduped.append(item)
    return deduped


def should_ignore(path: str) -> bool:
    normalized = path.replace("\\", "/")
    return any(pattern.search(normalized) for pattern in IGNORED_PATTERNS)


def test_exists_for(project_root: Path, file_path: str) -> bool:
    path = Path(file_path)
    stem = re.sub(r"\.(ts|tsx|js|jsx)$", "", path.name, flags=re.IGNORECASE)
    directory = project_root / path.parent
    parent = directory.parent

    candidates = []
    for ext in ("ts", "tsx", "js", "jsx"):
        candidates.extend([
            directory / f"{stem}.test.{ext}",
            directory / f"{stem}.spec.{ext}",
            directory / "__tests__" / f"{stem}.test.{ext}",
            directory / "__tests__" / f"{stem}.spec.{ext}",
            parent / "__tests__" / f"{stem}.test.{ext}",
            parent / "__tests__" / f"{stem}.spec.{ext}",
            project_root / "src" / "__tests__" / f"{stem}.test.{ext}",
            project_root / "src" / "__tests__" / f"{stem}.spec.{ext}",
        ])
    return any(candidate.exists() for candidate in candidates)


def main() -> int:
    raw = sys.stdin.read()
    if not raw.strip():
        return 0

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return 0

    project_root = Path.cwd()
    for action, file_path in extract_paths(payload):
        if action == "delete" or not file_path:
            continue
        if should_ignore(file_path):
            continue
        if not re.search(r"\.(ts|tsx|js|jsx)$", file_path, re.IGNORECASE):
            continue
        if not test_exists_for(project_root, file_path):
            stem = re.sub(r"\.(ts|tsx|js|jsx)$", "", Path(file_path).name, flags=re.IGNORECASE)
            return deny(
                f"TDD GUARD: no test file exists for '{stem}'. "
                f"Write a test before editing implementation code. "
                f"Example: {stem}.test.ts"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
