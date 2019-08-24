.PHONY : install_buck build targets audit project clean

BUCK=/Users/peter/build/buck/buck-out/gen/programs/buck.pex

log:
	echo "Make"

install_buck:
	curl https://jitpack.io/com/github/airbnb/buck/457ebb73fcd8f86be0112dc74948d022b6969dbd/buck-457ebb73fcd8f86be0112dc74948d022b6969dbd.pex --output tools/buck
	chmod u+x tools/buck

build_buck:
	sh build_buck.sh

build:
	$(BUCK) build //App:AppPackage

build_verbose:
	$(BUCK) build //App:AppPackage --verbose 8

targets:
	$(BUCK) targets //...

audit:
	$(BUCK) audit rules BUCK > Config/Gen/App-BUCK.py

kill_xcode:
	killall Xcode || true
	killall Simulator || true

clean: kill_xcode
	sh clean.sh

project: clean
	$(BUCK) project //App:workspace --config custom.mode=project
	open App/App.xcworkspace

next_project: clean
	/Users/peter/build/buck-next/buck/buck-out/gen/programs/buck.pex project //App:workspace --config custom.mode=project
	#open App/App.xcworkspace
