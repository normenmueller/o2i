#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path


INDEX_STATE = re.compile(r"^\s*index-state:\s*(?:\S+\s+)?(\S+)\s*$", re.MULTILINE)
PIN = re.compile(r"(?:^|[,\s])(?:any\.)?([A-Za-z0-9][A-Za-z0-9-]*)\s*==\s*([^,\s]+)")
ALLOW_NEWER = re.compile(r"^\s*allow-newer\s*:", re.MULTILINE)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def cabal_code(source: str) -> str:
    return "\n".join(line.partition("--")[0] for line in source.splitlines())


def index_state(path: Path, source: str) -> str:
    matches = INDEX_STATE.findall(source)
    if len(matches) != 1:
        raise ValueError(f"{path}: expected exactly one index-state")
    return matches[0]


def frozen_versions(path: Path, source: str) -> dict[str, str]:
    versions: dict[str, str] = {}
    for name, version in PIN.findall(source):
        previous = versions.setdefault(name, version)
        if previous != version:
            raise ValueError(f"{path}: conflicting pins for {name}")
    if not versions:
        raise ValueError(f"{path}: no exact package pins found")
    return versions


def solved_versions(path: Path) -> dict[str, str]:
    value = json.loads(read_text(path))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: plan root is not an object")
    install_plan = value.get("install-plan")
    if not isinstance(install_plan, list):
        raise ValueError(f"{path}: missing install-plan")

    versions: dict[str, str] = {}
    for entry in install_plan:
        if not isinstance(entry, dict):
            raise ValueError(f"{path}: malformed plan entry")
        if entry.get("style") == "local":
            continue
        name = entry.get("pkg-name")
        version = entry.get("pkg-version")
        if not isinstance(name, str) or not isinstance(version, str):
            raise ValueError(f"{path}: malformed non-local plan entry")
        previous = versions.setdefault(name, version)
        if previous != version:
            raise ValueError(f"{path}: multiple solved versions for {name}")
    if not versions:
        raise ValueError(f"{path}: no non-local package versions found")
    return versions


def check(project: Path, freeze: Path, plan: Path) -> None:
    project_text = cabal_code(read_text(project))
    freeze_text = cabal_code(read_text(freeze))
    for path, source in ((project, project_text), (freeze, freeze_text)):
        if ALLOW_NEWER.search(source):
            raise ValueError(f"{path}: allow-newer is forbidden")

    project_state = index_state(project, project_text)
    freeze_state = index_state(freeze, freeze_text)
    if project_state != freeze_state:
        raise ValueError(
            f"index-state mismatch: project={project_state}, freeze={freeze_state}"
        )

    frozen = frozen_versions(freeze, freeze_text)
    solved = solved_versions(plan)
    names = frozen.keys() | solved.keys()
    drift = {
        name: (frozen.get(name), solved.get(name))
        for name in names
        if frozen.get(name) != solved.get(name)
    }
    if drift:
        details = ", ".join(
            f"{name}: frozen={expected or 'missing'}, "
            f"solved={actual or 'missing'}"
            for name, (expected, actual) in sorted(drift.items())
        )
        raise ValueError(f"dependency-plan drift: {details}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--freeze", type=Path, required=True)
    parser.add_argument("--plan", type=Path, required=True)
    arguments = parser.parse_args()

    try:
        check(arguments.project, arguments.freeze, arguments.plan)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
