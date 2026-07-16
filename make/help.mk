help:
	@printf '%s\n' \
		'Targets:' \
		'  macos-build   Build the macOS SwiftUI app binary' \
		'  macos-app     Package build/Aula F75 Max Driver.app' \
		'  macos-dmg     Package the macOS DMG installer' \
		'  macos-run     Build and open the macOS app bundle' \
		'  linux-build   Build the native Linux GTK app' \
		'  linux-deb     Build a Debian/Ubuntu installer package' \
		'  linux-package Package a legacy Linux tar.gz artifact into build/' \
		'  linux-install-udev Install Linux hidraw udev access rule' \
		'  linux-run     Run the native Linux GTK app' \
		'  release-package Rename release artifacts for a tag' \
		'  clean         Remove generated build output' \
		'' \
		'Compatibility aliases: all/build/app/dmg/run map to macOS targets.'

all: macos-app

build: macos-build

app: macos-app

dmg: macos-dmg

run: macos-run
