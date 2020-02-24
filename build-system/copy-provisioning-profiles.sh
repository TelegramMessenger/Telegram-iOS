#!/bin/sh

set -e

if [ "$CODESIGNING_DATA_PATH" = "" ]; then
	>&2 echo "CODESIGNING_DATA_PATH not defined"
	exit 1
fi

EXPECTED_VARIABLES=(\
	DEVELOPMENT_PROVISIONING_PROFILE_APP \
	DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_SHARE \
	DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_WIDGET \
	DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONSERVICE \
	DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_NOTIFICATIONCONTENT \
	DEVELOPMENT_PROVISIONING_PROFILE_EXTENSION_INTENTS \
	DEVELOPMENT_PROVISIONING_PROFILE_WATCH_APP \
	DEVELOPMENT_PROVISIONING_PROFILE_WATCH_EXTENSION \
)

EXPECTED_VARIABLE_NAMES=(\
	Telegram \
	Share \
	Widget \
	NotificationService \
	NotificationContent \
	Intents \
	WatchApp \
	WatchExtension \
)

SEARCH_NAMES=()

MISSING_VARIABLES="0"
for VARIABLE_NAME in ${EXPECTED_VARIABLES[@]}; do
	if [ "${!VARIABLE_NAME}" = "" ]; then
		echo "$VARIABLE_NAME not defined"
		MISSING_VARIABLES="1"
	fi
done

if [ "$MISSING_VARIABLES" == "1" ]; then
	exit 1
fi

VARIABLE_COUNT=${#EXPECTED_VARIABLES[@]}
for (( i=0; i<$VARIABLE_COUNT; i=i+1 )); do
	VARIABLE_NAME="${EXPECTED_VARIABLES[$(($i))]}"
	SEARCH_NAMES=("${SEARCH_NAMES[@]}" "${EXPECTED_VARIABLE_NAMES[$i]}" "${!VARIABLE_NAME}")
done

touch "build-input/data/BUILD"

OUTPUT_DIRECTORY="build-input/data/provisioning-profiles"
rm -rf "$OUTPUT_DIRECTORY"
mkdir -p "$OUTPUT_DIRECTORY"

BUILD_PATH="$OUTPUT_DIRECTORY/BUILD"
touch "$BUILD_PATH"

echo "exports_files([" >> "$BUILD_PATH"

ELEMENT_COUNT=${#SEARCH_NAMES[@]}
REMAINDER=$(($ELEMENT_COUNT % 2))

if [ $REMAINDER != 0 ]; then
	>&2 echo "Expecting key-value pairs"
	exit 1
fi

for PROFILE in `find "$CODESIGNING_DATA_PATH" -type f -name "*.mobileprovision"`; do
	PROFILE_DATA=$(security cms -D -i "$PROFILE")
	PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin <<< $(echo $PROFILE_DATA))
	for (( i=0; i<$ELEMENT_COUNT; i=i+2 )); do
		ID=${SEARCH_NAMES[$i]}
		SEARCH_NAME=${SEARCH_NAMES[$(($i + 1))]}
		if [ "$PROFILE_NAME" = "$SEARCH_NAME" ]; then
			VARIABLE_NAME="FOUND_PROFILE_$ID"
			if [ "${!VARIABLE_NAME}" = "" ]; then
				eval "FOUND_PROFILE_$ID=\"$PROFILE\""
			else 
				>&2 echo "Found multiple profiles with name \"$SEARCH_NAME\""
				exit 1
			fi
		fi
	done
done

for (( i=0; i<$ELEMENT_COUNT; i=i+2 )); do
	ID=${SEARCH_NAMES[$i]}
	SEARCH_NAME=${SEARCH_NAMES[$(($i + 1))]}
	VARIABLE_NAME="FOUND_PROFILE_$ID"
	FOUND_PROFILE="${!VARIABLE_NAME}"
	if [ "$FOUND_PROFILE" = "" ]; then
		>&2 echo "Profile \"$SEARCH_NAME\" not found"
		exit 1
	fi

	cp "$FOUND_PROFILE" "$OUTPUT_DIRECTORY/$ID.mobileprovision"
	echo "    \"$ID.mobileprovision\"," >> $BUILD_PATH
done

echo "])" >> "$BUILD_PATH"
