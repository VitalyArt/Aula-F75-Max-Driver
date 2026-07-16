#!/usr/bin/env python3
import base64
import io
import sys
import textwrap
from pathlib import Path

from PIL import Image


def control_field(name: str, encoded_png: str) -> str:
    lines = textwrap.wrap(encoded_png, 76)
    continuation = "".join(f" {line}\n" for line in lines[1:])
    return f"{name}: {lines[0]}\n{continuation}"


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: embed-deb-icon.py CONTROL_FILE ICON_FILE", file=sys.stderr)
        return 2

    control_path = Path(sys.argv[1])
    icon_path = Path(sys.argv[2])

    with Image.open(icon_path) as image:
        image = image.resize((64, 64))
        output = io.BytesIO()
        image.save(output, format="PNG")

    encoded_png = base64.b64encode(output.getvalue()).decode("ascii")
    control_path.write_text(
        control_path.read_text()
        + control_field("Icon", encoded_png)
        + control_field("XB-AppInstall-Icon", encoded_png)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
