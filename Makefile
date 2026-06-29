SHELL := /bin/bash

APP_NAME := Aula F75 Max Driver
EXECUTABLE_NAME := AulaF75MaxDriver
CONFIGURATION := release
BUILD_DIR := build
LINUX_ARTIFACT := $(BUILD_DIR)/AulaF75MaxDriverLinux.tar.gz
RELEASE_DIR ?= release
RELEASE_TAG ?=
SOURCE_MACOS_DMG ?= $(APP_NAME).dmg
SOURCE_LINUX_ARTIFACT ?= AulaF75MaxDriverLinux.tar.gz
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
DMG_DIR := $(BUILD_DIR)/dmg
DMG_PATH := $(BUILD_DIR)/$(APP_NAME).dmg
DMG_RW_PATH := $(BUILD_DIR)/$(APP_NAME)-rw.dmg
DMG_STYLE_SCRIPT := scripts/style-dmg.applescript
EXECUTABLE := .build/arm64-apple-macosx/$(CONFIGURATION)/$(EXECUTABLE_NAME)

.PHONY: help all build app dmg run macos-build macos-app macos-dmg macos-run linux-build linux-package linux-run release-package clean

help:
	@printf '%s\n' \
		'Targets:' \
		'  macos-build   Build the macOS SwiftUI app binary' \
		'  macos-app     Package build/Aula F75 Max Driver.app' \
		'  macos-dmg     Package the macOS DMG installer' \
		'  macos-run     Build and open the macOS app bundle' \
		'  linux-build   Build the native Linux GTK app' \
		'  linux-package Package the Linux app and udev rule into build/' \
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

macos-build:
	CLANG_MODULE_CACHE_PATH=/private/tmp/clang-cache swift build -c $(CONFIGURATION) --arch arm64

macos-app: macos-build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp "Sources/AulaF75MaxDriver/Resources/AppIcon.icns" "$(APP_DIR)/Contents/Resources/AppIcon.icns"

macos-dmg: macos-app
	rm -rf "$(DMG_DIR)" "$(DMG_PATH)" "$(DMG_RW_PATH)"
	mkdir -p "$(DMG_DIR)"
	cp -R "$(APP_DIR)" "$(DMG_DIR)/"
	ln -s /Applications "$(DMG_DIR)/Applications"
	hdiutil create \
		-volname "$(APP_NAME)" \
		-srcfolder "$(DMG_DIR)" \
		-ov \
		-fs HFS+ \
		-format UDRW \
		"$(DMG_RW_PATH)"
	@set -euo pipefail; \
		mount_dir="$$(mktemp -d "/tmp/$(APP_NAME)-dmg.XXXXXX")"; \
		device=""; \
		cleanup() { \
			if [ -n "$$device" ]; then hdiutil detach "$$device" >/dev/null 2>&1 || true; fi; \
			rm -rf "$$mount_dir"; \
		}; \
		trap cleanup EXIT; \
		device="$$(hdiutil attach "$(DMG_RW_PATH)" -readwrite -noverify -noautoopen -owners off -mountpoint "$$mount_dir" | awk '/^\/dev\// { print $$1; exit }')"; \
		osascript "$(DMG_STYLE_SCRIPT)" "$$mount_dir" "$(APP_NAME)"; \
		sync; \
		hdiutil detach "$$device"; \
		device=""
	hdiutil convert "$(DMG_RW_PATH)" \
		-format UDZO \
		-imagekey zlib-level=9 \
		-o "$(DMG_PATH)"
	rm -f "$(DMG_RW_PATH)"

macos-run: macos-app
	open "$(APP_DIR)"

linux-build:
	swift build -c $(CONFIGURATION) --product AulaF75MaxDriverLinux

linux-package: linux-build
	rm -rf "$(BUILD_DIR)/linux"
	mkdir -p "$(BUILD_DIR)/linux"
	cp ".build/release/AulaF75MaxDriverLinux" "$(BUILD_DIR)/linux/"
	cp "packaging/linux/60-aula-f75-max.rules" "$(BUILD_DIR)/linux/"
	tar -C "$(BUILD_DIR)" -czf "$(LINUX_ARTIFACT)" linux

linux-run:
	swift run -c $(CONFIGURATION) AulaF75MaxDriverLinux

release-package:
	@test -n "$(RELEASE_TAG)"
	@set -euo pipefail; \
		safe_tag="$$(printf '%s' '$(RELEASE_TAG)' | tr '/' '-')"; \
		mv "$(RELEASE_DIR)/$(SOURCE_MACOS_DMG)" "$(RELEASE_DIR)/$(APP_NAME)-$${safe_tag}.dmg"; \
		mv "$(RELEASE_DIR)/$(SOURCE_LINUX_ARTIFACT)" "$(RELEASE_DIR)/AulaF75MaxDriverLinux-$${safe_tag}.tar.gz"

clean:
	rm -rf .build "$(BUILD_DIR)"
