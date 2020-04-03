# Test Gram Wallet (iOS)

This is the source code and build instructions for a TON Testnet Wallet implementation for iOS.

1. Install Xcode 11.4
```
https://apps.apple.com/app/xcode/id497799835
```

Make sure to launch Xcode at least once and set up command-line tools paths (Xcode — Preferences — Locations — Command Line Tools)

2. Build the app (IPA)

Note:
It is recommended to use an artifact cache to optimize build speed. Prepend any of the following commands with
```
BAZEL_CACHE_DIR="path/to/existing/directory"
```

```
sh wallet_env.sh make wallet_app
```

3. If needed, generate Xcode project
```
sh wallet_env.sh make wallet_project
```
