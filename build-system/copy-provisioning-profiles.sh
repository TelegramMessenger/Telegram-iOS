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
touch "$OUTPUT_DIRECTORY/BUILD"

SEARCH_NAMES=($@)

declare -A FOUND_PROFILES

for PROFILE in `find "$PROVISIONING_PROFILE_SEARCH_PATH" -type f -name "*.mobileprovision"`; do
	PROFILE_DATA=$(security cms -D -i "$PROFILE")
	PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin <<< $(echo $PROFILE_DATA))
	for SEARCH_NAME in $SEARCH_NAMES; do
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

for SEARCH_NAME in $SEARCH_NAMES; do
	FOUND_PROFILE="${FOUND_PROFILES[\"$SEARCH_NAME\"]}"
	if [ "$FOUND_PROFILE" = "" ]; then
		>&2 echo "Profile \"$SEARCH_NAME\" not found"
		exit 1
	fi

	cp "$FOUND_PROFILE" "$OUTPUT_DIRECTORY/"
done
