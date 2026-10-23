#!/bin/bash
# Prints the UDID of an available iPhone simulator on the newest installed iOS runtime.
# Used by the workflows so they don't depend on a specific device name being installed.
set -euo pipefail

xcrun simctl list devices available -j | python3 -c '
import json, sys

runtimes = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in runtimes.items():
    if "iOS" not in runtime:
        continue
    version = tuple(int(p) for p in runtime.split("iOS-")[-1].split("-") if p.isdigit())
    for device in devices:
        name = device["name"]
        if not device.get("isAvailable", True) or not name.startswith("iPhone"):
            continue
        # Prefer plain, regular-size phones over SE / mini / Plus / Max / Air variants.
        penalty = sum(word in name for word in ("SE", "mini", "Plus", "Max", "Air"))
        penalty = 0 if name.replace("iPhone ", "").replace(" Pro", "").strip().isdigit() else penalty + 1
        key = (version, -penalty)
        if best is None or key > best[0]:
            best = (key, device["udid"], name, runtime)
if best is None:
    sys.exit("no iPhone simulator available")
print(best[1])
print("Using simulator: %s (%s)" % (best[2], best[3]), file=sys.stderr)
'
