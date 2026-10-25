.PHONY: android-build android-test android-release
android-build:
	@bash scripts/android/gradle.sh assembleDebug
android-test:
	@bash scripts/android/gradle.sh test
android-release:
	@bash scripts/android/release.sh
