#!/bin/sh

swift -swift-version 5 tools/GenerateLocalization.swift Telegram/Telegram-iOS/en.lproj/Localizable.strings submodules/TelegramPresentationData/Sources/PresentationStrings.swift submodules/TelegramUI/Resources/PresentationStrings.mapping

