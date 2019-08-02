#!/bin/sh

swift -swift-version 4 tools/GenerateLocalization.swift Telegram-iOS/en.lproj/Localizable.strings submodules/TelegramPresentationData/Sources/PresentationStrings.swift submodules/TelegramUI/TelegramUI/Resources/PresentationStrings.mapping
