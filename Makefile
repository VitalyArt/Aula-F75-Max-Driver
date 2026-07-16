SHELL := /bin/bash

APP_NAME := Aula F75 Max Driver
RELEASE_BASE_NAME := AulaF75MaxDriver
EXECUTABLE_NAME := AulaF75MaxDriver
CONFIGURATION := release
BUILD_DIR := build

LINUX_PRODUCT := AulaF75MaxDriverLinux
LINUX_ARTIFACT := $(BUILD_DIR)/AulaF75MaxDriverLinux.tar.gz
LINUX_DESKTOP_ID := aula-f75-max-driver
LINUX_APPSTREAM_ID := vitalyart.aula-f75-max-driver
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
CODESIGN_IDENTITY ?=
NOTARYTOOL_PROFILE ?=
NOTARYTOOL_TIMEOUT ?= 30m

export APP_NAME RELEASE_BASE_NAME EXECUTABLE_NAME CONFIGURATION BUILD_DIR
export LINUX_PRODUCT LINUX_ARTIFACT LINUX_DESKTOP_ID LINUX_APPSTREAM_ID
export LINUX_PACKAGE_NAME LINUX_INSTALL_PREFIX LINUX_DEB
export RELEASE_DIR RELEASE_TAG SOURCE_MACOS_DMG SOURCE_LINUX_ARTIFACT SOURCE_LINUX_DEB
export APP_DIR DMG_DIR DMG_PATH DMG_RW_PATH DMG_STYLE_SCRIPT EXECUTABLE
export CODESIGN_IDENTITY NOTARYTOOL_PROFILE NOTARYTOOL_TIMEOUT

.PHONY: help all build app dmg run
.PHONY: macos-build macos-app macos-dmg macos-run
.PHONY: linux-check-deps linux-install-udev linux-build linux-package linux-deb linux-run
.PHONY: release-package clean

include make/help.mk
include make/macos.mk
include make/linux.mk
include make/release.mk
include make/clean.mk
