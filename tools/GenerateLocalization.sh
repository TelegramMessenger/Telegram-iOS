#!/bin/sh

swift -swift-version 4 tools/GenerateLocalization.swift Telegram-iOS/en.lproj/Localizable.strings submodules/TelegramPresentationData/Sources/PresentationStrings.swift submodules/TelegramUI/TelegramUI/Resources/PresentationStrings.mapping

mkdir -p submodules/WalletUI/Resources
swift -swift-version 4 tools/GenerateLocalization.swift Telegram-iOS/en.lproj/Localizable.strings submodules/WalletUI/Sources/WalletStrings.swift submodules/WalletUI/Resources/WalletStrings.mapping "Wallet."

