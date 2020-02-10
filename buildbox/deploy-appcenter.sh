#!/bin/bash

set -e
set -x

API_HOST="https://api.appcenter.ms"
IPA_PATH="build/artifacts/Telegram.ipa"
DSYM_PATH="build/artifacts/Telegram.DSYMs.zip"

upload_ipa() {
    GROUP_DATA=$(curl \
	    -X GET \
	    --header "X-API-Token: $API_TOKEN" \
	    "$API_HOST/v0.1/apps/$API_USER_NAME/$API_APP_NAME/distribution_groups/Internal" \
    )

    GROUP_ID=$(echo "$GROUP_DATA" | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["id"];')

    UPLOAD_TOKEN=$(curl \
        -X POST \
        --header "Content-Type: application/json" \
        --header "Accept: application/json" \
        --header "X-API-Token: $API_TOKEN" \
        "$API_HOST/v0.1/apps/$API_USER_NAME/$API_APP_NAME/release_uploads" \
      )


    UPLOAD_URL=$(echo "$UPLOAD_TOKEN" | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["upload_url"];') 
    UPLOAD_ID=$(echo "$UPLOAD_TOKEN" | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["upload_id"];')

    curl --progress-bar -F "ipa=@${IPA_PATH}" "$UPLOAD_URL"

    RELEASE_TOKEN=$(curl \
        -X PATCH \
        --header "Content-Type: application/json" \
        --header "Accept: application/json" \
        --header "X-API-Token: $API_TOKEN" \
        -d '{ "status": "committed" }' \
        "$API_HOST/v0.1/apps/$API_USER_NAME/$API_APP_NAME/release_uploads/$UPLOAD_ID" \
    )


    RELEASE_URL=$(echo "$RELEASE_TOKEN" | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["release_url"];')
    RELEASE_ID=$(echo "$RELEASE_TOKEN" | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["release_id"];')

    curl \
        -X POST \
        --header "Content-Type: application/json" \
        --header "Accept: application/json" \
        --header "X-API-Token: $API_TOKEN" \
        -d "{ \"id\": \"$GROUP_ID\", \"mandatory_update\": false, \"notify_testers\": false }" \
        "$API_HOST/$RELEASE_URL/groups"
}

upload_dsym() {
    UPLOAD_DSYM_DATA=$(curl \
        -X POST \
        --header "Content-Type: application/json" \
        --header "Accept: application/json" \
        --header "X-API-Token: $API_TOKEN" \
        -d "{ \"symbol_type\": \"Apple\"}" \
        "$API_HOST/v0.1/apps/$API_USER_NAME/$API_APP_NAME/symbol_uploads" \
    )

    DSYM_UPLOAD_URL=$(echo "$UPLOAD_DSYM_DATA" | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["upload_url"];')
    DSYM_UPLOAD_ID=$(echo "$UPLOAD_DSYM_DATA" | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["symbol_upload_id"];')

    curl \
        --progress-bar \
        --header "x-ms-blob-type: BlockBlob" \
        --upload-file "${DSYM_PATH}" \
        "$DSYM_UPLOAD_URL"

    curl \
        -X PATCH \
        --header "Content-Type: application/json" \
        --header "Accept: application/json" \
        --header "X-API-Token: $API_TOKEN" \
        -d '{ "status": "committed" }' \
    	"$API_HOST/v0.1/apps/$API_USER_NAME/$API_APP_NAME/symbol_uploads/$DSYM_UPLOAD_ID"
}

upload_ipa
