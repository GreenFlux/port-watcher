SCHEME = PortWatcher
PROJECT = PortWatcher.xcodeproj
BUILD_DIR = build
APP_NAME = PortWatcher.app
INSTALL_DIR = /Applications

.PHONY: build install uninstall clean run

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
	rm -rf $(BUILD_DIR)

run: install
	open "$(INSTALL_DIR)/$(APP_NAME)"
