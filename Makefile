.PHONY : build build_arm64 build_verbose targets project kill_xcode clean

BUCK=/Users/peter/build/buck-next/buck/buck-out/gen/programs/buck.pex

build:
	$(BUCK) build //App:AppPackage#iphoneos-arm64,iphoneos-armv7
	sh package_app.sh $(BUCK) iphoneos-arm64,iphoneos-armv7

build_arm64:
	$(BUCK) build //App:AppPackage#iphoneos-arm64
	sh package_app.sh $(BUCK) iphoneos-arm64

build_verbose:
	$(BUCK) build //App:AppPackage#iphoneos-armv7,iphoneos-arm64 --verbose 8

targets:
	$(BUCK) targets //...

kill_xcode:
	killall Xcode || true
	killall Simulator || true

clean: kill_xcode
	sh clean.sh

project: clean
	$(BUCK) project //App:workspace --config custom.mode=project
	open App/App.xcworkspace

