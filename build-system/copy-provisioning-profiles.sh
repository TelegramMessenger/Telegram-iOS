#!/bin/zsh

set -e

if [ "$PROVISIONING_PROFILE_SEARCH_PATH" = "" ]; then
	>&2 echo "PROVISIONING_PROFILE_SEARCH_PATH not defined"
	exit 1
fi

touch "build-input/data/BUILD"

OUTPUT_DIRECTORY="build-input/data/provisioning-profiles"
rm -rf "$OUTPUT_DIRECTORY"
mkdir -p "$OUTPUT_DIRECTORY"

BUILD_PATH="$OUTPUT_DIRECTORY/BUILD"
touch "$BUILD_PATH"

echo "exports_files([" >> "$BUILD_PATH"

SEARCH_NAMES=($@)
ELEMENT_COUNT=${#SEARCH_NAMES[@]}
REMAINDER=$(($ELEMENT_COUNT % 2))

if [ $REMAINDER != 0 ]; then
	>&2 echo "Expecting key-value pairs"
	exit 1
fi

declare -A FOUND_PROFILES

for PROFILE in `find "$PROVISIONING_PROFILE_SEARCH_PATH" -type f -name "*.mobileprovision"`; do
	PROFILE_DATA=$(security cms -D -i "$PROFILE")
	PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin <<< $(echo $PROFILE_DATA))
	for (( i=1; i<$ELEMENT_COUNT+1; i=i+2 )); do
		ID=${SEARCH_NAMES[$i]}
		SEARCH_NAME=${SEARCH_NAMES[$(($i + 1))]}
		if [ "$PROFILE_NAME" = "$SEARCH_NAME" ]; then
			if [ "${FOUND_PROFILES[\"$SEARCH_NAME\"]}" = "" ]; then
				FOUND_PROFILES["$SEARCH_NAME"]="$PROFILE"
			else
				>&2 echo "Found multiple profiles with name \"$SEARCH_NAME\""
				exit 1
			fi
		fi
	done
done

for (( i=1; i<$ELEMENT_COUNT+1; i=i+2 )); do
	ID=${SEARCH_NAMES[$i]}
	SEARCH_NAME=${SEARCH_NAMES[$(($i + 1))]}
	FOUND_PROFILE="${FOUND_PROFILES[\"$SEARCH_NAME\"]}"
	if [ "$FOUND_PROFILE" = "" ]; then
		>&2 echo "Profile \"$SEARCH_NAME\" not found"
		exit 1
	fi

	cp "$FOUND_PROFILE" "$OUTPUT_DIRECTORY/$ID.mobileprovision"
	echo "    \"$ID.mobileprovision\"," >> $BUILD_PATH
done

echo "])" >> "$BUILD_PATH"
