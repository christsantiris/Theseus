#!/usr/bin/env bash
# Export an iOS Xcode project with standard device and simulator architectures.
# Set GODOT=/path/to/godot if the editor is not on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

# Check before exporting so a missing prerequisite leaves the current build alone.
command -v python3 >/dev/null
command -v xcrun >/dev/null
mkdir -p "$ROOT/builds/ios"
"$GODOT" --headless --path "$ROOT" --export-debug iOS "$ROOT/builds/ios/Theseus.zip"

# Godot writes ARM64-only project settings. Its simulator framework metadata can
# also list architectures absent from the binary. Use standard device settings
# and restrict simulator builds to the slices actually shipped in the template.
python3 - "$ROOT/builds/ios/Theseus.xcodeproj/project.pbxproj" <<'PY'
from pathlib import Path
import plistlib
import re
import subprocess
import sys

project = Path(sys.argv[1])
framework = project.parent.with_suffix('.xcframework')
info = plistlib.loads((framework / 'Info.plist').read_bytes())
simulator_archs = set()
for library in info['AvailableLibraries']:
    if library.get('SupportedPlatform') != 'ios' or library.get('SupportedPlatformVariant') != 'simulator':
        continue
    binary = framework / library['LibraryIdentifier'] / library['LibraryPath']
    result = subprocess.run(['xcrun', 'lipo', '-archs', str(binary)], check=True, capture_output=True, text=True)
    simulator_archs.update(result.stdout.split())
simulator_archs &= {'arm64', 'x86_64'}
if not simulator_archs:
    raise SystemExit(f"No supported iOS Simulator slices found in {framework}.")
simulator_archs = ' '.join(sorted(simulator_archs))

source = project.read_text()
# Replace an earlier simulator override if this helper is reapplied.
source = re.sub(r'^[ \t]*"ARCHS\[sdk=iphonesimulator\*\]"[ \t]*=[^;\r\n]+;\r?\n?', '', source, flags=re.MULTILINE)
updated, count = re.subn(
    r'^([ \t]*)ARCHS[ \t]*=[ \t]*[^;\r\n]+;',
    lambda match: match.group(1) + 'ARCHS = "$(ARCHS_STANDARD)";\n'
    + match.group(1) + f'"ARCHS[sdk=iphonesimulator*]" = "{simulator_archs}";',
    source,
    flags=re.MULTILINE,
)
if count == 0:
    raise SystemExit(f"No ARCHS settings found in {project}; review the Godot export template.")
if updated != source:
    project.write_text(updated)
print(f"Configured standard architectures in {count} Xcode build configurations.")
print(f"iOS Simulator architectures available in this template: {simulator_archs}")
print(f"Open in Xcode: {project.parent}")
PY
