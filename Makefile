.PHONY: build run release clean open

APP_NAME = StravaBar
BUILD_DIR = .build

## Build debug binary
build:
	swift build

## Build and run (debug)
run:
	swift run

## Build optimized release binary
release:
	swift build -c release

## Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)

## Build release and launch the app
open: release
	./$(BUILD_DIR)/release/$(APP_NAME)
