# Test Gram Wallet (iOS)

This is the source code and build instructions for a TON Testnet Wallet implementation for iOS.

1. Install Xcode 11.1
```
https://apps.apple.com/ae/app/xcode/id497799835?mt=12
```

Make sure to launch Xcode at least once and set up command-line tools paths (Xcode — Preferences — Locations — Command Line Tools)

2. Install Homebrew

```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
3. Install the required tools

```
brew tap AdoptOpenJDK/openjdk
brew cask install adoptopenjdk8
brew install cmake ant
```

4. Build Buck

```
mkdir -p $HOME/buck_source
cd tools/buck-build
sh ./prepare_buck_source.sh $HOME/buck_source
```

5. Now you can build Wallet application (IPA)

Note:
It is recommended to use an artifact cache to optimize build speed. Prepend any of the following commands with
```
BUCK_DIR_CACHE="path/to/existing/directory"
```

```
BUCK="$HOME/buck_source/buck/buck-out/gen/programs/buck.pex" \
    BUILD_NUMBER=30 \
    DISTRIBUTION_CODE_SIGN_IDENTITY="iPhone Distribution: XXXXXXX (XXXXXXXXXX)" \
    DEVELOPMENT_TEAM="XXXXXXXXXX" WALLET_BUNDLE_ID="wallet.bundle.id" \
    WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP="wallet distribution provisioning profile name" \
    CODESIGNING_SOURCE_DATA_PATH="$HOME/wallet_codesigning" \
    sh Wallet/example_wallet_env.sh make -f Wallet.makefile wallet_app
```

6. If needed, generate Xcode project
```
BUCK="$HOME/buck_source/buck/buck-out/gen/programs/buck.pex" \
    BUILD_NUMBER=30 \
    DEVELOPMENT_CODE_SIGN_IDENTITY="iPhone Developer: XXXXXXX (XXXXXXXXXX)" \
    DISTRIBUTION_CODE_SIGN_IDENTITY="iPhone Distribution: XXXXXXX (XXXXXXXXXX)" \
    DEVELOPMENT_TEAM="XXXXXXXXXX" WALLET_BUNDLE_ID="wallet.bundle.id" \
    WALLET_DEVELOPMENT_PROVISIONING_PROFILE_APP="wallet development provisioning profile name" \
    WALLET_DISTRIBUTION_PROVISIONING_PROFILE_APP="wallet distribution provisioning profile name" \
    CODESIGNING_SOURCE_DATA_PATH="$HOME/wallet_codesigning" \
    sh Wallet/example_wallet_env.sh make -f Wallet.makefile wallet_project
```

