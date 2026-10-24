#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/clang-cache}"

# Some Command Line Tools SDKs ship SwiftUI interfaces without their macro
# plugin. Check the actual toolchain/SDK pair before building the whole app.
probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/aula-sdk.XXXXXX")"
trap 'rm -rf "$probe_dir"' EXIT
cat > "$probe_dir/Probe.swift" <<'SWIFT'
import SwiftUI
struct SDKProbe: View {
    @State private var enabled = false
    var body: some View { Toggle("Probe", isOn: $enabled) }
}
SWIFT

sdk="${MACOS_SDKROOT:-${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}}"
check_sdk() {
    xcrun swiftc -typecheck -target arm64-apple-macosx14.0 -sdk "$1" \
        "$probe_dir/Probe.swift" > "$probe_dir/diagnostics" 2>&1
}
if ! check_sdk "$sdk"; then
    compatible_sdk=""
    # An explicitly selected SDK should fail visibly rather than be overridden.
    if [[ -z "${MACOS_SDKROOT:-}${SDKROOT:-}" ]]; then
        while IFS= read -r candidate; do
            if [[ "$candidate" != "$sdk" ]] && check_sdk "$candidate"; then
                compatible_sdk="$candidate"
                break
            fi
        done < <(python3 - "$sdk" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1]).parent
selected = pathlib.Path(sys.argv[1]).resolve()
sdks = {p.resolve() for p in root.glob('MacOSX*.sdk')} - {selected}
def version(path):
    return tuple(int(n) for n in re.findall(r'\d+', path.name))
for path in sorted(sdks, key=version, reverse=True):
    print(path)
PY
)
    fi
    if [[ -z "$compatible_sdk" ]]; then
        cat "$probe_dir/diagnostics" >&2
        printf '%s\n' 'No compatible SwiftUI SDK found. Install matching Xcode/Command Line Tools or set MACOS_SDKROOT.' >&2
        exit 1
    fi
    sdk="$compatible_sdk"
    printf 'Using compatible macOS SDK: %s\n' "$sdk"
fi

# Use the portable SwiftPM backend with the explicitly checked SDK.
swift build --build-system native --sdk "$sdk" -c "${CONFIGURATION}" --arch arm64
