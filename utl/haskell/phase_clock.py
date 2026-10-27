#!/usr/bin/env python3
"""Read one monotonic clock; unavailable or invalid elapsed samples stay unknown."""

import json
import re
import sys
import time


def elapsed(start: str, end: str) -> str:
    if not all(re.fullmatch(r"[0-9]+", sample) for sample in (start, end)):
        return "UNKNOWN"
    difference = int(end) - int(start)
    if difference < 0:
        return "UNKNOWN"
    seconds, nanoseconds = divmod(difference, 1_000_000_000)
    return f"{seconds}.{nanoseconds:09d}"


def main(arguments: list[str]) -> int:
    if arguments == ["now"]:
        clock = time.get_clock_info("monotonic")
        if not clock.monotonic or clock.adjustable:
            raise RuntimeError("a non-adjustable monotonic clock is required")
        print(time.monotonic_ns())
    elif arguments == ["info"]:
        clock = time.get_clock_info("monotonic")
        print("[o2i|info] Haskell phase clock: " + json.dumps({
            "clock": "monotonic_ns", "implementation": clock.implementation,
            "monotonic": clock.monotonic, "adjustable": clock.adjustable,
            "resolution_seconds": clock.resolution,
        }, sort_keys=True))
    elif len(arguments) == 3 and arguments[0] == "elapsed":
        print(elapsed(arguments[1], arguments[2]))
    else:
        print("Usage: phase_clock.py now|info|elapsed START END", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, RuntimeError, ValueError):
        print("UNKNOWN")
        sys.exit(1)
