#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 5:
        print('usage: render-metainfo.py INPUT OUTPUT VERSION DATE', file=sys.stderr)
        return 2

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    version = sys.argv[3].lstrip('v')
    date = sys.argv[4]

    text = input_path.read_text()
    replacement = f'  <release version="{version}" date="{date}" />'
    text, count = re.subn(r'  <release version="[^"]+" date="[^"]+" />', replacement, text, count=1)
    if count != 1:
        print('failed to locate release entry in metainfo XML', file=sys.stderr)
        return 1

    output_path.write_text(text)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
