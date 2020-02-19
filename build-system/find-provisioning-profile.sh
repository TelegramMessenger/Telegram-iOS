#!/bin/bash

if [ "$PROVISIONING_PROFILE_SEARCH_PATH" = "" ]; then
	>&2 echo "PROVISIONING_PROFILE_SEARCH_PATH not defined"
	exit 1
fi

SEARCH_NAME="$1"

if [ "$SEARCH_NAME" == "" ]; then
	>&2 echo "Usage: sh find-provisioning-profile.sh name"
	exit 1
fi

FOUND_PROFILE=""

for PROFILE in `find "$PROVISIONING_PROFILE_SEARCH_PATH" -type f -name "*.mobileprovision"`; do
	PROFILE_DATA=$(security cms -D -i "$PROFILE")
	PROFILE_NAME=$(/usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin <<< $(echo $PROFILE_DATA))
	if [ "$PROFILE_NAME" == "$SEARCH_NAME" ]; then
		if [ "$FOUND_PROFILE" == "" ]; then
			FOUND_PROFILE="$PROFILE"
		else
			>&2 echo "Found multiple profiles with name \"$SEARCH_NAME\""
			exit 1
		fi
	fi
done

if [ "$FOUND_PROFILE" == "" ]; then
	>&2 echo "Profile \"$SEARCH_NAME\" not found"
	exit 1
fi

cat "$FOUND_PROFILE" | gzip | zcat | base64
