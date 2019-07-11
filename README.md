# Telegram iOS Source Code Compilation Guide

1. Install the brew package manager, if you haven’t already.
2. Install the packages pkg-config, yasm:
```
brew install pkg-config yasm
```
3. Clone the project from GitHub:

```
git clone --recursive https://github.com/peter-iakovlev/Telegram-iOS.git
```
4. Open Telegram-iOS.workspace.
5. Open the `Telegram-iOS-Fork` scheme.
6. Create `DebugFork` configuration by duplicating `DebugAppStoreLLC` configuration for each project in the workspace if it doesn't exist.
7. Change the `APP_CONFIG_API_ID` and `APP_CONFIG_API_HASH` in `Config-Fork.xcconfig` to the values obtained from Telegram Core website (https://my.telegram.org/apps); register your App ID if you haven't done so.
8. Start the compilation process.
9. To run the app on your device, you will need to set the correct values for the signature, .entitlements files and package IDs in accordance with your developer account values.
