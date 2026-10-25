.PHONY: help
help:
	@printf '%s\n' \
		'Targets:' \
		'  macos-build   Build the macOS SwiftUI app binary' \
		'  macos-app     Package build/Aula F75 Max Driver.app' \
		'  macos-dmg     Package the macOS DMG installer' \
		'  macos-run     Build and open the macOS app bundle' \
		'  linux-build   Build the native Linux GTK app' \
		'  linux-deb     Build a Debian/Ubuntu installer package' \
		'  linux-install-udev Install Linux hidraw udev access rule' \
		'  linux-run     Run the native Linux GTK app' \
		'  android-build Build the Android app debug APK' \
		'  android-test  Run Android unit tests' \
		'  android-release Build and verify a signed release APK' \
		'  macos-test / linux-test Run platform tests' \
		'  packaging-test Test release identity, packaging and feeds' \
		'  release-publish Publish installers and signed feed' \
		'  release-package Copy versioned release artifacts (DMG/DEB/APK)' \
		'  site-build    Build the static website into build/site/' \
		'  clean         Remove generated build output'
