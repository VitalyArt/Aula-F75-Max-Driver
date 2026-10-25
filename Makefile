SHELL := /bin/bash
.DEFAULT_GOAL := help
# Command-line Make variables are also available to standalone build scripts.
.EXPORT_ALL_VARIABLES:
include make/help.mk
include make/macos.mk
include make/linux.mk
include make/android.mk
include make/release.mk
include make/site.mk
include make/clean.mk
