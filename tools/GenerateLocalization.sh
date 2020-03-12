#!/bin/sh

swift -swift-version 4 tools/GenerateLocalization.swift Telegram/Telegram-iOS/en.lproj/Localizable.strings submodules/TelegramPresentationData/Sources/PresentationStrings.swift submodules/TelegramUI/Resources/PresentationStrings.mapping

mkdir -p submodules/WalletUI/Resources
swift -swift-version 4 tools/GenerateLocalization.swift Telegram/Telegram-iOS/en.lproj/Localizable.strings submodules/WalletUI/Sources/WalletStrings.swift submodules/WalletUI/Resources/WalletStrings.mapping "Wallet."

wallet_strings_path="Wallet/Strings"
strings_name="Localizable.strings"
rm -rf "$wallet_strings_path"

for f in $(basename $(find "Telegram/Telegram-iOS" -name "*.lproj")); do
	mkdir -p "$wallet_strings_path/$f"
	if [ -f "Telegram/Telegram-iOS/$f/$strings_name" ]; then
		cat "Telegram/Telegram-iOS/$f/$strings_name" | grep -E '^"Wallet\..*?$' > "$wallet_strings_path/$f/$strings_name"
	fi
done
