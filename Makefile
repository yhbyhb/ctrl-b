APP_NAME   = ctrl-b
BUNDLE     = $(APP_NAME).app
BUILD_DIR  = .build/release
BINARY     = $(BUILD_DIR)/CtrlB

.PHONY: build app install test clean lint lint-fix setup

## swift build
build:
	swift build -c release

## Create .app bundle
app: build
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/CtrlB
	strip -S $(BUNDLE)/Contents/MacOS/CtrlB
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	cp -r $(BUILD_DIR)/CtrlB_CtrlB.bundle $(BUNDLE)/ 2>/dev/null || true
	@echo "✓ $(BUNDLE) created"

## Install to /Applications
install: app
	cp -r $(BUNDLE) /Applications/
	@echo "✓ Installed to /Applications/$(BUNDLE)"

## Run unit tests
test:
	swift test

## Clean build artifacts
clean:
	rm -rf .build $(BUNDLE)

## Run SwiftLint
lint:
	swiftlint lint --strict

## Auto-fix SwiftLint violations
lint-fix:
	swiftlint lint --fix

## Initial dev environment setup (git hooks)
setup:
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit
	@echo "✓ Git hooks configured"
