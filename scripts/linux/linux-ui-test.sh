#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
if ! command -v swiftc >/dev/null 2>&1; then
    source "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
fi
# An isolated config and mocked HID keep this check independent of real devices.
test_dir="$(mktemp -d /tmp/aula-ui-test.XXXXXX)"
export AULA_TEST_OUTPUT="$test_dir"
export XDG_CONFIG_HOME="$test_dir/config"
export GSETTINGS_BACKEND=memory GDK_BACKEND=x11 GSK_RENDERER=cairo
mkdir -p "$test_dir/config"
swiftc -emit-library -emit-module -module-name AulaCore Sources/AulaCore/*.swift -o "$test_dir/libAulaCore.so" -emit-module-path "$test_dir/AulaCore.swiftmodule"
read -r -a gtk_cflags <<< "$(pkg-config --cflags gtk4)"
read -r -a gtk_libs <<< "$(pkg-config --libs gtk4)"
cc -c -Wno-deprecated-declarations -I Sources/CAulaLinuxGTK/include "${gtk_cflags[@]}" Tests/LinuxPresentation/PresentationTests.c -o "$test_dir/ui.o"
swiftc -parse-as-library -I "$test_dir" -L "$test_dir" -lAulaCore -Xlinker -rpath -Xlinker "$test_dir" Tests/LinuxPresentation/Support.swift Sources/AulaLinuxApp/PreviewBridge.swift "$test_dir/ui.o" "${gtk_libs[@]}" -o "$test_dir/ui-test"
# Generate small deterministic fixtures without requiring Pillow.
ffmpeg -loglevel error -f lavfi -i 'testsrc=size=256x128:rate=1' -frames:v 1 "$test_dir/still.bmp"
python3 - "$test_dir/animated.gif" <<'PY'
import struct, sys
# Two 1x1 GIF frames, red then blue, with delays of 100 and 200ms.
data = b'GIF89a' + struct.pack('<HH', 1, 1) + b'\x80\x00\x00' + b'\xff\x00\x00\x00\x00\xff'
# Explicit looping keeps GdkPixbuf's last-frame delay finite on all versions.
data += b'\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00'
for color, delay in [(0, 10), (1, 20)]:
    data += b'\x21\xf9\x04\x00' + struct.pack('<H', delay) + b'\x00\x00'
    data += b'\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00'
    data += b'\x02\x02' + bytes([0x44 if color == 0 else 0x4c, 0x01]) + b'\x00'
open(sys.argv[1], 'wb').write(data + b'\x3b')
PY
xvfb-run -a -s '-screen 0 1200x900x24' "$test_dir/ui-test" "$test_dir/still.bmp" "$test_dir/animated.gif"
printf 'Screenshots and test artifacts: %s\n' "$test_dir"
