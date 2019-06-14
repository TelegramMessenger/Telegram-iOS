# Telegram iOS Source Code Compilation Guide

1. Install the brew package manager, if you haven’t already.
2. Install the packages pkg-config, yasm:
brew install pkg-config yasm
3. Clone the project from GitHub:

git clone --recursive https://github.com/peter-iakovlev/Telegram-iOS.git

4. Open Telegram-iOS.workspace.
5. Open the Telegram-iOS-Fork scheme.
6. Replace the contents of Config-Fork.xcconfig with
APP_NAME=Telegram Fork
APP_BUNDLE_ID=fork.telegram.Fork
APP_SPECIFIC_URL_SCHEME=tgfork

GLOBAL_CONSTANTS = APP_CONFIG_IS_INTERNAL_BUILD=false APP_CONFIG_IS_APPSTORE_BUILD=true APP_CONFIG_APPSTORE_ID=0 APP_SPECIFIC_URL_SCHEME="\"$(APP_SPECIFIC_URL_SCHEME)\""
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) $(GLOBAL_CONSTANTS)

GCC_PREPROCESSOR_DEFINITIONS = $(inherited) APP_CONFIG_API_ID=8 APP_CONFIG_API_HASH="\"7245de8e747a0d6fbe11f7cc14fcc0bb\"" APP_CONFIG_HOCKEYAPP_ID="\"\""
7. Replace group ID in Telegram-iOS-Fork.entitlements with group.fork.telegram.Fork.
8. Start the compilation process.
9. To run the app on your device, you will need to set the correct values for the signature, .entitlements files and package IDs in accordance with your developer account values.
