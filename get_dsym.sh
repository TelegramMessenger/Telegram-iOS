#!/bin/sh

rm -rf "DSYM-out"
mkdir -p "DSYM-out"

PLATFORM="iphonesimulator-x86_64"

for DEPENDENCY in $(buck query "kind('apple_library|apple_binary', deps('//App:App#$PLATFORM', 1))"); do
	case "$DEPENDENCY" in 
		*"#"*)
			;;
		*)
			DEPENDENCY="$DEPENDENCY#$PLATFORM"	
			;;
	esac
	DSYM_PATH="buck-out/gen/$(echo "$DEPENDENCY" | sed -e "s/#/#apple-dsym,/" | sed -e "s#^//##" | sed -e "s#:#/#").dSYM"
	cp -f -r "$DSYM_PATH" "DSYM-out/"
done
