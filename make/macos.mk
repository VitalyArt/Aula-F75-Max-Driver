macos-build:
	@scripts/macos-build.sh

macos-app: macos-build
	@scripts/macos-app.sh

macos-dmg: macos-app
	@scripts/macos-dmg.sh

macos-run: macos-app
	@scripts/macos-run.sh
