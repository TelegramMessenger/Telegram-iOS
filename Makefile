
.PHONY : install_buck build targets audit project clean

# Use local version of Buck
BUCK=tools/buck

log:
	echo "Make"

install_buck:
	curl https://jitpack.io/com/github/airbnb/buck/457ebb73fcd8f86be0112dc74948d022b6969dbd/buck-457ebb73fcd8f86be0112dc74948d022b6969dbd.pex --output tools/buck
	chmod u+x tools/buck

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
