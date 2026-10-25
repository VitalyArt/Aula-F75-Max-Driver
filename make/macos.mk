.PHONY: macos-build macos-app macos-dmg macos-run macos-test macos-appcast
macos-build:
	@scripts/macos/macos-build.sh

macos-app: macos-build
	@scripts/macos/macos-app.sh

macos-dmg: macos-app
	@scripts/macos/macos-dmg.sh

macos-run: macos-app
	@scripts/macos/macos-run.sh

macos-test:
	@swift test

macos-appcast:
	@python3 scripts/macos/macos-appcast.py "$(or $(BUILD_DIR),build)/Aula F75 Max Driver.dmg" --sign-tool .build/artifacts/sparkle/Sparkle/bin/sign_update --output "$(or $(BUILD_DIR),build)/macos.appcast.xml"
