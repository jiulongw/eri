NAME       := Eri
APP        := build/$(NAME).app
INSTALLED  := /Applications/$(NAME).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

ICON_SRC := Resources/AppIcon.png
ICONSET  := build/AppIcon.iconset
ICNS     := build/AppIcon.icns

.PHONY: all build app install register uninstall clean format check test

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

clean:
	rm -rf .build build
