SHELL := /bin/bash

APP_NAME := Aula F75 Max Driver
EXECUTABLE_NAME := AulaF75MaxDriver
CONFIGURATION := release
BUILD_DIR := build
LINUX_ARTIFACT := $(BUILD_DIR)/AulaF75MaxDriverLinux.tar.gz
LINUX_DESKTOP_ID := aula-f75-max-driver
LINUX_PACKAGE_NAME := aula-f75-max-driver
LINUX_INSTALL_PREFIX := /opt/$(LINUX_PACKAGE_NAME)
LINUX_DEB ?=
RELEASE_DIR ?= release
RELEASE_TAG ?=
SOURCE_MACOS_DMG ?= $(APP_NAME).dmg
SOURCE_LINUX_ARTIFACT ?= AulaF75MaxDriverLinux.tar.gz
SOURCE_LINUX_DEB ?=
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
DMG_DIR := $(BUILD_DIR)/dmg
DMG_PATH := $(BUILD_DIR)/$(APP_NAME).dmg
DMG_RW_PATH := $(BUILD_DIR)/$(APP_NAME)-rw.dmg
DMG_STYLE_SCRIPT := scripts/style-dmg.applescript
EXECUTABLE := .build/arm64-apple-macosx/$(CONFIGURATION)/$(EXECUTABLE_NAME)

.PHONY: help all build app dmg run macos-build macos-app macos-dmg macos-run linux-check-deps linux-install-udev linux-build linux-package linux-deb linux-run release-package clean

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

linux-check-deps:
	@command -v pkg-config >/dev/null 2>&1 || { \
		printf '%s\n' \
			'Missing Linux build dependency: pkg-config' \
			'Install dependencies on Ubuntu with:' \
			'  sudo apt install libgtk-4-dev libhidapi-dev pkg-config' \
			'Install dependencies on Fedora with:' \
			'  sudo dnf install gtk4-devel hidapi-devel pkgconf-pkg-config'; \
		exit 1; \
	}
	@pkg-config --exists gtk4 hidapi-hidraw || { \
		printf '%s\n' \
			'Missing Linux build dependencies: gtk4 and/or hidapi-hidraw development files' \
			'Install dependencies on Ubuntu with:' \
			'  sudo apt install libgtk-4-dev libhidapi-dev pkg-config' \
			'Install dependencies on Fedora with:' \
			'  sudo dnf install gtk4-devel hidapi-devel pkgconf-pkg-config'; \
		exit 1; \
	}

linux-build: linux-check-deps
	swift build -c $(CONFIGURATION) --product AulaF75MaxDriverLinux

linux-install-udev:
	sudo install -m 0644 packaging/linux/60-aula-f75-max.rules /etc/udev/rules.d/
	sudo udevadm control --reload-rules
	sudo udevadm trigger
	@printf '%s\n' 'udev rule installed. Replug the keyboard and 2.4G receiver before running the app.'

linux-package: linux-build
	rm -rf "$(BUILD_DIR)/linux"
	mkdir -p "$(BUILD_DIR)/linux/share/applications"
	mkdir -p "$(BUILD_DIR)/linux/share/icons/hicolor/256x256/apps"
	mkdir -p "$(BUILD_DIR)/linux/share/udev/rules.d"
	cp ".build/release/AulaF75MaxDriverLinux" "$(BUILD_DIR)/linux/"
	cp "packaging/linux/aula-f75-max-driver.desktop" "$(BUILD_DIR)/linux/share/applications/$(LINUX_DESKTOP_ID).desktop"
	cp "Sources/AulaF75MaxDriver/Resources/AppIcon.png" "$(BUILD_DIR)/linux/share/icons/hicolor/256x256/apps/$(LINUX_DESKTOP_ID).png"
	cp "packaging/linux/60-aula-f75-max.rules" "$(BUILD_DIR)/linux/share/udev/rules.d/"
	tar -C "$(BUILD_DIR)" -czf "$(LINUX_ARTIFACT)" linux

linux-deb: linux-build
	@command -v dpkg-deb >/dev/null 2>&1 || { \
		printf '%s\n' 'Missing Linux packaging dependency: dpkg-deb'; \
		exit 1; \
	}
	rm -rf "$(BUILD_DIR)/deb-root"
	@set -euo pipefail; \
		arch="$$(dpkg --print-architecture)"; \
		version="$(RELEASE_TAG)"; \
		if [ -z "$$version" ]; then version="0.0.0+local"; fi; \
		version="$${version#v}"; \
		version="$$(printf '%s' "$$version" | tr '/' '-')"; \
		deb_path="$(LINUX_DEB)"; \
		if [ -z "$$deb_path" ]; then deb_path="$(BUILD_DIR)/$(LINUX_PACKAGE_NAME)_$${version}_$${arch}.deb"; fi; \
		root="$(BUILD_DIR)/deb-root"; \
		install_dir="$$root$(LINUX_INSTALL_PREFIX)"; \
		mkdir -p \
			"$$root/DEBIAN" \
			"$$install_dir/lib" \
			"$$root/usr/bin" \
			"$$root/usr/share/applications" \
			"$$root/usr/share/icons/hicolor/256x256/apps" \
			"$$root/etc/udev/rules.d"; \
		install -m 0755 ".build/release/AulaF75MaxDriverLinux" "$$install_dir/AulaF75MaxDriverLinux"; \
		ldd ".build/release/AulaF75MaxDriverLinux" | awk '/libswift.*=>/ { print $$3 }' | while read -r lib; do \
			if [ -n "$$lib" ] && [ -f "$$lib" ]; then install -m 0644 "$$lib" "$$install_dir/lib/"; fi; \
		done; \
		printf '%s\n' \
			'#!/bin/sh' \
			'export LD_LIBRARY_PATH="$(LINUX_INSTALL_PREFIX)/lib:$${LD_LIBRARY_PATH:-}"' \
			'exec "$(LINUX_INSTALL_PREFIX)/AulaF75MaxDriverLinux" "$$@"' \
			> "$$root/usr/bin/AulaF75MaxDriverLinux"; \
		chmod 0755 "$$root/usr/bin/AulaF75MaxDriverLinux"; \
		install -m 0644 "packaging/linux/aula-f75-max-driver.desktop" "$$root/usr/share/applications/$(LINUX_DESKTOP_ID).desktop"; \
		install -m 0644 "Sources/AulaF75MaxDriver/Resources/AppIcon.png" "$$root/usr/share/icons/hicolor/256x256/apps/$(LINUX_DESKTOP_ID).png"; \
		install -m 0644 "packaging/linux/60-aula-f75-max.rules" "$$root/etc/udev/rules.d/"; \
		sed \
			-e "s/@PACKAGE_NAME@/$(LINUX_PACKAGE_NAME)/g" \
			-e "s/@VERSION@/$$version/g" \
			-e "s/@ARCH@/$$arch/g" \
			"packaging/linux/deb-control.in" > "$$root/DEBIAN/control"; \
		install -m 0755 "packaging/linux/deb-postinst" "$$root/DEBIAN/postinst"; \
		install -m 0755 "packaging/linux/deb-postrm" "$$root/DEBIAN/postrm"; \
		mkdir -p "$$(dirname "$$deb_path")"; \
		dpkg-deb --build --root-owner-group "$$root" "$$deb_path"; \
		printf '%s\n' "Built $$deb_path"

linux-run: linux-check-deps
	swift run -c $(CONFIGURATION) AulaF75MaxDriverLinux

release-package:
	@test -n "$(RELEASE_TAG)"
	@set -euo pipefail; \
		safe_tag="$$(printf '%s' '$(RELEASE_TAG)' | tr '/' '-')"; \
		version="$${safe_tag#v}"; \
		mv "$(RELEASE_DIR)/$(SOURCE_MACOS_DMG)" "$(RELEASE_DIR)/$(APP_NAME)-$${safe_tag}.dmg"; \
		if [ -n "$(SOURCE_LINUX_DEB)" ]; then \
			arch="$$(dpkg-deb -f "$(RELEASE_DIR)/$(SOURCE_LINUX_DEB)" Architecture 2>/dev/null || printf '%s' 'amd64')"; \
			mv "$(RELEASE_DIR)/$(SOURCE_LINUX_DEB)" "$(RELEASE_DIR)/$(LINUX_PACKAGE_NAME)_$${version}_$${arch}.deb"; \
		else \
			mv "$(RELEASE_DIR)/$(SOURCE_LINUX_ARTIFACT)" "$(RELEASE_DIR)/AulaF75MaxDriverLinux-$${safe_tag}.tar.gz"; \
		fi

clean:
	rm -rf .build "$(BUILD_DIR)"
