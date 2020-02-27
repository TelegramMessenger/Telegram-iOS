#!/bin/bash

set -e

FASTLANE="$(which fastlane)"

EXPECTED_VARIABLES=(\
    APPLE_ID \
    BASE_BUNDLE_ID \
    APP_NAME \
    TEAM_ID \
    PROVISIONING_DIRECTORY \
)

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

if [ ! -d "$PROVISIONING_DIRECTORY" ]; then
    echo "Directory $PROVISIONING_DIRECTORY does not exist"
    exit 1
fi

BASE_DIR=$(mktemp -d)
FASTLANE_DIR="$BASE_DIR/fastlane"
mkdir "$FASTLANE_DIR"
FASTFILE="$FASTLANE_DIR/Fastfile"

touch "$FASTFILE"

CREDENTIALS=(\
    --username "$APPLE_ID" \
    --team_id "$TEAM_ID" \
)
export FASTLANE_SKIP_UPDATE_CHECK=1

APP_EXTENSIONS=(\
    Share \
    SiriIntents \
    NotificationContent \
    NotificationService \
    Widget \
)

echo "lane :manage_app do" >> "$FASTFILE"
echo "  produce(" >> "$FASTFILE"
echo "      username: '$APPLE_ID'," >> "$FASTFILE"
echo "      app_identifier: '${BASE_BUNDLE_ID}'," >> "$FASTFILE"
echo "      app_name: '$APP_NAME'," >> "$FASTFILE"
echo "      language: 'English'," >> "$FASTFILE"
echo "      app_version: '1.0'," >> "$FASTFILE"
echo "      team_id: '$TEAM_ID'," >> "$FASTFILE"
echo "      skip_itc: true," >> "$FASTFILE"
echo "  )" >> "$FASTFILE"

echo "  produce(" >> "$FASTFILE"
echo "      username: '$APPLE_ID'," >> "$FASTFILE"
echo "      app_identifier: '${BASE_BUNDLE_ID}.watchkitapp'," >> "$FASTFILE"
echo "      app_name: '$APP_NAME Watch App'," >> "$FASTFILE"
echo "      language: 'English'," >> "$FASTFILE"
echo "      app_version: '1.0'," >> "$FASTFILE"
echo "      team_id: '$TEAM_ID'," >> "$FASTFILE"
echo "      skip_itc: true," >> "$FASTFILE"
echo "  )" >> "$FASTFILE"

echo "  produce(" >> "$FASTFILE"
echo "      username: '$APPLE_ID'," >> "$FASTFILE"
echo "      app_identifier: '${BASE_BUNDLE_ID}.watchkitapp.watchkitextension'," >> "$FASTFILE"
echo "      app_name: '$APP_NAME Watch App Extension'," >> "$FASTFILE"
echo "      language: 'English'," >> "$FASTFILE"
echo "      app_version: '1.0'," >> "$FASTFILE"
echo "      team_id: '$TEAM_ID'," >> "$FASTFILE"
echo "      skip_itc: true," >> "$FASTFILE"
echo "  )" >> "$FASTFILE"

for EXTENSION in ${APP_EXTENSIONS[@]}; do
    echo "  produce(" >> "$FASTFILE"
    echo "      username: '$APPLE_ID'," >> "$FASTFILE"
    echo "      app_identifier: '${BASE_BUNDLE_ID}.${EXTENSION}'," >> "$FASTFILE"
    echo "      app_name: '${APP_NAME} ${EXTENSION}'," >> "$FASTFILE"
    echo "      language: 'English'," >> "$FASTFILE"
    echo "      app_version: '1.0'," >> "$FASTFILE"
    echo "      team_id: '$TEAM_ID'," >> "$FASTFILE"
    echo "      skip_itc: true," >> "$FASTFILE"
    echo "  )" >> "$FASTFILE"
done

echo "end" >> "$FASTFILE"

pushd "$BASE_DIR"

fastlane cert ${CREDENTIALS[@]} --development

fastlane manage_app

fastlane produce group -g "group.$BASE_BUNDLE_ID" -n "$APP_NAME Group" ${CREDENTIALS[@]}

fastlane produce enable_services -a "$BASE_BUNDLE_ID" ${CREDENTIALS[@]} \
    --app-group \
    --push-notification \
    --sirikit

fastlane produce associate_group -a "$BASE_BUNDLE_ID" "group.$BASE_BUNDLE_ID" ${CREDENTIALS[@]}
for EXTENSION in ${APP_EXTENSIONS[@]}; do
    fastlane produce enable_services -a "${BASE_BUNDLE_ID}.${EXTENSION}" ${CREDENTIALS[@]} \
        --app-group

    fastlane produce associate_group -a "${BASE_BUNDLE_ID}.${EXTENSION}" "group.$BASE_BUNDLE_ID" ${CREDENTIALS[@]}
done

for DEVELOPMENT_FLAG in "--development"; do
    fastlane sigh -a "$BASE_BUNDLE_ID" ${CREDENTIALS[@]} -o "$PROVISIONING_DIRECTORY" $DEVELOPMENT_FLAG \
        --skip_install
    for EXTENSION in ${APP_EXTENSIONS[@]}; do
        fastlane sigh -a "${BASE_BUNDLE_ID}.${EXTENSION}" ${CREDENTIALS[@]} -o "$PROVISIONING_DIRECTORY" $DEVELOPMENT_FLAG \
            --skip_install
    done
done

popd

rm -rf "$BASE_DIR"
