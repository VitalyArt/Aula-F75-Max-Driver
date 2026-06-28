SHELL := /bin/bash

APP_NAME := Aula F75 Max Driver
EXECUTABLE_NAME := AulaF75MaxDriver
CONFIGURATION := release
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
DMG_DIR := $(BUILD_DIR)/dmg
DMG_PATH := $(BUILD_DIR)/$(APP_NAME).dmg
DMG_RW_PATH := $(BUILD_DIR)/$(APP_NAME)-rw.dmg
DMG_STYLE_SCRIPT := scripts/style-dmg.applescript
EXECUTABLE := .build/arm64-apple-macosx/$(CONFIGURATION)/$(EXECUTABLE_NAME)

.PHONY: all build app dmg run clean

all: app

build:
	CLANG_MODULE_CACHE_PATH=/private/tmp/clang-cache swift build -c $(CONFIGURATION) --arch arm64

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp "Sources/AulaF75MaxDriver/Resources/AppIcon.icns" "$(APP_DIR)/Contents/Resources/AppIcon.icns"

dmg: app
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

run: app
	open "$(APP_DIR)"

clean:
	rm -rf .build "$(BUILD_DIR)"
