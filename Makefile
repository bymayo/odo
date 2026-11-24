# Odo — build, run and package. Mirrors Cargo's Makefile.
#
#   make run                      build Odo Preview.app and launch it beside the installed Odo
#   make package                  build and wrap in a DMG (unsigned, this Mac only)
#   make package SIGN=1           the same, signed and notarised (reads .env.local)
#   make release VERSION=1.0.1    bump, tag and push — CI builds the rest
#   make icon                     redraw Packaging/AppIcon.icns and .png from OdoMark.swift

APP_NAME   := Odo
INFO_PLIST := Packaging/Info.plist
BUILD      := build
APP        := $(BUILD)/dmg/$(APP_NAME) Preview.app
# The preview build's process name; never the installed Odo's
PREVIEW_PROCESS := OdoPreview

VERSION := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $(INFO_PLIST) 2>/dev/null || echo 0.0.0)
DMG     := $(BUILD)/$(APP_NAME)-$(VERSION).dmg

SIGN_FLAG := $(if $(SIGN),--sign,)

# Signing identity and notarising credentials live outside the repo, in
# .env.local (gitignored): DEVELOPER_ID, TEAM_ID and NOTARY_PROFILE.
-include .env.local
export DEVELOPER_ID
export TEAM_ID
export NOTARY_PROFILE
export APPLE_ID
export APP_PASSWORD

SHELL := /bin/bash

.DEFAULT_GOAL := help
.PHONY: help dev app run stop package release icon clean

help:
	@echo "$(APP_NAME) $(VERSION)"
	@echo
	@echo "  make dev       swift run (bare executable, no Sparkle)"
	@echo "  make app       build $(APP) (ad-hoc signed)"
	@echo "  make run       build, then launch it beside the installed Odo"
	@echo "  make stop      quit the preview build"
	@echo "  make package   build Release and wrap it in $(DMG)"
	@echo "  make clean     remove $(BUILD)/ and .build/"
	@echo
	@echo "  make package SIGN=1           sign and notarise (reads .env.local)"
	@echo "  make release VERSION=1.0.1    bump Info.plist, commit, tag and push"

dev:
	swift run

app:
	@./Scripts/build-dmg.sh "$(VERSION)" --app-only --preview

# Quit first: `open` only raises a copy that's already running.
run: app stop
	@open "$(APP)"
	@echo "Launched $(APP_NAME) Preview $(VERSION) — the menu bar item with the hammer."

stop:
	@pkill -x "$(PREVIEW_PROCESS)" 2>/dev/null || true
	@for i in $$(seq 1 25); do \
		pgrep -x "$(PREVIEW_PROCESS)" >/dev/null || break; \
		sleep 0.2; \
	done

package:
	@./Scripts/build-dmg.sh "$(VERSION)" $(SIGN_FLAG)

# VERSION defaults to Info.plist, so a release needs it passed explicitly —
# otherwise a bare `make release` would re-tag the version that's already out.
release:
	@if [ "$(VERSION)" = "$$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $(INFO_PLIST))" ]; then \
		echo "Pass the new version:  make release VERSION=1.0.1   (current: $(VERSION))"; \
		exit 1; \
	fi
	@./Scripts/prepare-release.sh "$(VERSION)"

icon:
	@mkdir -p .build
	@swiftc Scripts/AppIcon/main.swift Sources/Odo/OdoMark.swift -o .build/appicon
	@.build/appicon Packaging/AppIcon.icns

clean:
	@rm -rf $(BUILD) .build
	@echo "Removed $(BUILD)/ and .build/"
