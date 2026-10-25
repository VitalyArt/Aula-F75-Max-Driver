#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

sudo install -m 0644 packaging/linux/60-aula-f75-max.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
printf '%s\n' 'udev rule installed. Replug the keyboard and 2.4G receiver before running the app.'
