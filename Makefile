APP_NAME    := ClipboardManager
# ~/Applications, not /Applications: writing to /Applications needs admin
# rights this user does not have. SMAppService registers login items from a
# home-directory bundle just as well.
INSTALL_DIR := $(HOME)/Applications
BUILD_DIR   := build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS    := $(APP_BUNDLE)/Contents
BINARY      := .build/release/$(APP_NAME)

# Minimum macOS the shipped build targets. Must match Package.swift's platform
# floor and Info.plist's LSMinimumSystemVersion.
DEPLOY_TARGET := 14.0
# Note: SPM writes to an unversioned directory even though the triple carries a
# version, so these paths deliberately omit $(DEPLOY_TARGET).
ARM_BINARY  := .build/arm64-apple-macosx/release/$(APP_NAME)
X86_BINARY  := .build/x86_64-apple-macosx/release/$(APP_NAME)
ZIP_PATH    := $(BUILD_DIR)/$(APP_NAME).zip

# Distribution signing. Override on the command line once the company owns an
# Apple Developer Program membership, e.g.
#   make dist SIGN_ID="Developer ID Application: Acme Inc (TEAMID)"
# The default "-" is an ad-hoc signature, which is fine locally but is REJECTED
# by Gatekeeper on any other Mac. See DISTRIBUTION.md.
SIGN_ID     ?= -
# Apple ID, app-specific password, and team id used by `make notarize`.
NOTARY_PROFILE ?= clipboard-notary

.PHONY: all test build app install uninstall clean universal dist notarize

all: app

test:
	swift run ClipTests

build:
	swift build -c release

# Local development bundle: current architecture only, ad-hoc signed.
app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BINARY) $(CONTENTS)/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	codesign --force --sign - $(APP_BUNDLE)
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

# Both architectures, merged with lipo. SPM's own --arch flag needs xcbuild,
# which ships only with full Xcode, so each slice is cross-compiled separately.
universal:
	swift build -c release --triple arm64-apple-macosx$(DEPLOY_TARGET)
	swift build -c release --triple x86_64-apple-macosx$(DEPLOY_TARGET)
	@test -f $(ARM_BINARY) || { echo "missing arm64 slice: $(ARM_BINARY)"; exit 1; }
	@test -f $(X86_BINARY) || { echo "missing x86_64 slice: $(X86_BINARY)"; exit 1; }

# Redistributable bundle: universal, hardened runtime, zipped for sharing.
# Hardened runtime is a prerequisite for notarization.
dist: test universal
	rm -rf $(APP_BUNDLE) $(ZIP_PATH)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	lipo -create -output $(CONTENTS)/MacOS/$(APP_NAME) $(ARM_BINARY) $(X86_BINARY)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	codesign --force --timestamp --options runtime --sign $(SIGN_ID) $(APP_BUNDLE)
	codesign --verify --strict --verbose=2 $(APP_BUNDLE)
	@lipo -archs $(CONTENTS)/MacOS/$(APP_NAME)
	ditto -c -k --keepParent $(APP_BUNDLE) $(ZIP_PATH)
	@echo ""
	@echo "Built $(ZIP_PATH)"
	@if [ "$(SIGN_ID)" = "-" ]; then \
		echo ""; \
		echo "WARNING: ad-hoc signed. Gatekeeper will REJECT this on any other Mac."; \
		echo "Do not share this build. See DISTRIBUTION.md."; \
	else \
		echo "Next: make notarize"; \
	fi

# Submit to Apple, then staple the ticket so Gatekeeper can validate offline.
# Requires a Developer ID signature and a stored notarytool credential profile:
#   xcrun notarytool store-credentials $(NOTARY_PROFILE) \
#       --apple-id you@company.com --team-id TEAMID --password APP-SPECIFIC-PW
notarize:
	@if [ "$(SIGN_ID)" = "-" ]; then \
		echo "Cannot notarize an ad-hoc signed build."; \
		echo "Run: make dist SIGN_ID=\"Developer ID Application: ...\""; \
		exit 1; \
	fi
	xcrun notarytool submit $(ZIP_PATH) --keychain-profile $(NOTARY_PROFILE) --wait
	xcrun stapler staple $(APP_BUNDLE)
	xcrun stapler validate $(APP_BUNDLE)
	rm -f $(ZIP_PATH)
	ditto -c -k --keepParent $(APP_BUNDLE) $(ZIP_PATH)
	@echo ""
	@echo "Notarized and stapled: $(ZIP_PATH) — safe to share."

clean:
	rm -rf $(BUILD_DIR) .build
