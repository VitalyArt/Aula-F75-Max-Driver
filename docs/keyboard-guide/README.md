# Keyboard guide

`catalog.json` is the source for all three native catalogs and their seven-language
translations. After editing it, run:

```sh
python3 scripts/checks/generate_keyboard_guide.py
python3 scripts/checks/generate_keyboard_guide.py --check
```

The check also runs in CI. Generated files carry a header; edit the catalog rather
than editing their guide entries or translation blocks directly. Untranslated
standard key names (for example, `Home` and `F1`) are literal key names, not app
navigation labels.

## Source and deliberate omissions

The entries were visually checked against page 2 of the English
[EPOMAKER AULA F75 MAX manual](https://powerspikepc.com/wp-content/uploads/EPOMAKER_AULA_F75_MAX_manual.pdf).
A preserved copy is checked in at `site/aula-f75-max-manual.pdf`. Apps and the
website link to the [project-hosted copy](https://vitalyart.github.io/Aula-F75-Max-Driver/aula-f75-max-manual.pdf)
using `manualURL` in the catalog. `source` retains the download provenance. The
manufacturer's original URL is
https://epomaker.com/cdn/shop/files/EPOMAKER_AULA_F75_MAX_manual.pdf.

Both speed directions on that page are printed as **Fn + →**. Neither direction
is included until a corrected manual or hardware verification establishes the
mapping. Do not infer **Fn + ←** from another F75 model. Bluetooth and receiver
entries describe the documented three-second pairing gesture, not an inferred
short-press action. Reset remains a reference entry, with no device action.

The Windows/Mac picker changes only the guide's F-row reference. It does not send
a device command or infer the connected keyboard's current mode. The default is
Windows on every platform. Media and OS actions describe the keyboard's documented
mapping; the guide does not promise that Linux or Android implements each action.

Desktop navigation preserves Command/Ctrl+1 through 7; Command/Ctrl+8 opens the
guide even though its sidebar row appears before the advanced pages.
