APP_NAME    := ClipboardManager
# ~/Applications, not /Applications: writing to /Applications needs admin
# rights this user does not have. SMAppService registers login items from a
# home-directory bundle just as well.
INSTALL_DIR := $(HOME)/Applications
BUILD_DIR   := build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS    := $(APP_BUNDLE)/Contents
BINARY      := .build/release/$(APP_NAME)

.PHONY: all test build app install uninstall clean

all: app

test:
	swift run ClipTests

build:
	swift build -c release

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BINARY) $(CONTENTS)/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

install: app
	@echo "Stopping any running copy..."
	-pkill -x $(APP_NAME) || true
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	open $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Installed to $(INSTALL_DIR)."

uninstall:
	-pkill -x $(APP_NAME) || true
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app

clean:
	rm -rf $(BUILD_DIR) .build
