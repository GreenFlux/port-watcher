SCHEME = PortWatcher
PROJECT = PortWatcher.xcodeproj
BUILD_DIR = build
DIST_DIR = dist
APP_NAME = PortWatcher.app
INSTALL_DIR = /Applications

# Notarization config — override on the command line or via env:
#   make release NOTARY_PROFILE=portwatcher-notary
NOTARY_PROFILE ?= portwatcher-notary
TEAM_ID ?= R83AAQ27AZ

.PHONY: build install uninstall clean run notarize release verify

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release -derivedDataPath $(BUILD_DIR) build

install: build
	@[ -d "$(INSTALL_DIR)/$(APP_NAME)" ] && echo "Replacing existing install..." || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME)" "$(INSTALL_DIR)/$(APP_NAME)"
	xattr -cr "$(INSTALL_DIR)/$(APP_NAME)"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME)"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME)"
	@echo "Uninstalled $(APP_NAME)"

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)

run: install
	open "$(INSTALL_DIR)/$(APP_NAME)"

# Produce a notarized, stapled zip ready for GitHub Release upload.
# Prerequisite: one-time keychain setup (see docs/RELEASING.md)
#   xcrun notarytool store-credentials $(NOTARY_PROFILE) \
#       --apple-id YOUR_APPLE_ID --team-id $(TEAM_ID) --password APP_SPECIFIC_PW
release: build
	@mkdir -p $(DIST_DIR)
	@APP="$(BUILD_DIR)/Build/Products/Release/$(APP_NAME)"; \
	ZIP="$(DIST_DIR)/PortWatcher.zip"; \
	echo "→ Verifying signature..."; \
	codesign --verify --deep --strict --verbose=2 "$$APP"; \
	echo "→ Zipping for notarization..."; \
	rm -f "$$ZIP"; \
	/usr/bin/ditto -c -k --keepParent "$$APP" "$$ZIP"; \
	echo "→ Submitting to notary service (this can take a few minutes)..."; \
	xcrun notarytool submit "$$ZIP" --keychain-profile "$(NOTARY_PROFILE)" --wait; \
	echo "→ Stapling ticket..."; \
	xcrun stapler staple "$$APP"; \
	echo "→ Re-zipping stapled app..."; \
	rm -f "$$ZIP"; \
	/usr/bin/ditto -c -k --keepParent "$$APP" "$$ZIP"; \
	echo "→ Verifying Gatekeeper acceptance..."; \
	spctl --assess --type execute --verbose=2 "$$APP" || true; \
	shasum -a 256 "$$ZIP"; \
	echo "✓ Release artifact ready: $$ZIP"

# Verify an existing built app is properly signed for distribution.
verify:
	@APP="$(BUILD_DIR)/Build/Products/Release/$(APP_NAME)"; \
	codesign --verify --deep --strict --verbose=2 "$$APP"; \
	codesign -dvv "$$APP" 2>&1 | grep -E "Authority|TeamIdentifier|Runtime"; \
	spctl --assess --type execute --verbose=2 "$$APP" || true
