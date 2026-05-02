NAME       := Eri
APP        := build/$(NAME).app
INSTALLED  := /Applications/$(NAME).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

ICON_SRC := Resources/AppIcon.png
ICONSET  := build/AppIcon.iconset
ICNS     := build/AppIcon.icns

.PHONY: all build app install register uninstall clean format check test sign notarize release

all: app

build:
	swift build -c release

$(ICNS): $(ICON_SRC)
	@rm -rf $(ICONSET)
	@mkdir -p $(ICONSET)
	sips -z 16 16   $(ICON_SRC) --out $(ICONSET)/icon_16x16.png      > /dev/null
	sips -z 32 32   $(ICON_SRC) --out $(ICONSET)/icon_16x16@2x.png   > /dev/null
	sips -z 32 32   $(ICON_SRC) --out $(ICONSET)/icon_32x32.png      > /dev/null
	sips -z 64 64   $(ICON_SRC) --out $(ICONSET)/icon_32x32@2x.png   > /dev/null
	sips -z 128 128 $(ICON_SRC) --out $(ICONSET)/icon_128x128.png    > /dev/null
	sips -z 256 256 $(ICON_SRC) --out $(ICONSET)/icon_128x128@2x.png > /dev/null
	sips -z 256 256 $(ICON_SRC) --out $(ICONSET)/icon_256x256.png    > /dev/null
	sips -z 512 512 $(ICON_SRC) --out $(ICONSET)/icon_256x256@2x.png > /dev/null
	sips -z 512 512 $(ICON_SRC) --out $(ICONSET)/icon_512x512.png    > /dev/null
	cp $(ICON_SRC) $(ICONSET)/icon_512x512@2x.png
	pngquant --quality=70-95 --strip --force --ext .png --skip-if-larger $(ICONSET)/*.png
	iconutil -c icns $(ICONSET) -o $(ICNS)

app: build $(ICNS)
	@rm -rf $(APP)
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/$(NAME) $(APP)/Contents/MacOS/$(NAME)
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp $(ICNS) $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --deep --sign - $(APP)
	@echo "Built $(APP)"

register: app
	$(LSREGISTER) -f $(APP)
	@echo "Registered $(APP) with LaunchServices"

install: app
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	$(LSREGISTER) -f $(INSTALLED)
	@echo "Installed $(INSTALLED) and registered"
	@echo "Set Eri as default browser via System Settings -> Desktop & Dock."

uninstall:
	rm -rf $(INSTALLED)
	@echo "Removed $(INSTALLED)"

format:
	swift format -i -r Sources Tests

check:
	swift format lint --strict -r Sources Tests

test:
	swift test

# Release / notarization
#
# Auth modes (pick one):
#   A) Stored keychain profile — convenient on a dev machine. One-time setup:
#        xcrun notarytool store-credentials eri-notary \
#          --apple-id you@example.com --team-id TEAMID \
#          --password <app-specific-password>
#      Then:
#        make release DEVELOPER_ID="Developer ID Application: ... (TEAMID)" \
#                     NOTARY_PROFILE=eri-notary
#
#   B) Direct credentials — preferred on CI (GitHub Actions, etc.):
#        make release DEVELOPER_ID="Developer ID Application: ... (TEAMID)" \
#                     APPLE_ID=you@example.com \
#                     APPLE_TEAM_ID=TEAMID \
#                     APPLE_APP_PASSWORD=<app-specific-password>
DEVELOPER_ID       ?=
NOTARY_PROFILE     ?=
APPLE_ID           ?=
APPLE_TEAM_ID      ?=
APPLE_APP_PASSWORD ?=
VERSION            := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
RELEASE_ZIP        := build/$(NAME)-$(VERSION).zip

ifneq ($(NOTARY_PROFILE),)
NOTARY_AUTH := --keychain-profile "$(NOTARY_PROFILE)"
else
NOTARY_AUTH := --apple-id "$(APPLE_ID)" --team-id "$(APPLE_TEAM_ID)" --password "$(APPLE_APP_PASSWORD)"
endif

sign: app
	@if [ -z "$(DEVELOPER_ID)" ]; then \
		echo "ERROR: DEVELOPER_ID is not set."; \
		echo "  e.g. make sign DEVELOPER_ID=\"Developer ID Application: Your Name (TEAMID)\""; \
		echo "  List available identities with: security find-identity -v -p codesigning"; \
		exit 1; \
	fi
	codesign --force --deep --options runtime --timestamp \
		--sign "$(DEVELOPER_ID)" $(APP)
	codesign --verify --deep --strict --verbose=2 $(APP)
	@echo "Signed $(APP) with Developer ID"

notarize: sign
	@if [ -z "$(NOTARY_PROFILE)" ] && \
	    { [ -z "$(APPLE_ID)" ] || [ -z "$(APPLE_TEAM_ID)" ] || [ -z "$(APPLE_APP_PASSWORD)" ]; }; then \
		echo "ERROR: notarization credentials not set."; \
		echo "  Either: NOTARY_PROFILE=<keychain-profile-name>"; \
		echo "  Or:     APPLE_ID=... APPLE_TEAM_ID=... APPLE_APP_PASSWORD=..."; \
		exit 1; \
	fi
	@rm -f $(RELEASE_ZIP)
	/usr/bin/ditto -c -k --keepParent $(APP) $(RELEASE_ZIP)
	xcrun notarytool submit $(RELEASE_ZIP) $(NOTARY_AUTH) --wait
	xcrun stapler staple $(APP)
	@rm -f $(RELEASE_ZIP)
	/usr/bin/ditto -c -k --keepParent $(APP) $(RELEASE_ZIP)
	@echo "Notarized & stapled: $(RELEASE_ZIP)"

release: notarize
	spctl -a -vv -t exec $(APP) || true
	@echo "Release ready: $(RELEASE_ZIP)"

clean:
	rm -rf .build build
