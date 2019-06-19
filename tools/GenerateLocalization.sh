#!/bin/sh

swift tools/GenerateLocalization.swift Telegram-iOS/en.lproj/Localizable.strings submodules/TelegramPresentationData/Sources/PresentationStrings.swift submodules/TelegramUI/TelegramUI/Resources/PresentationStrings.mapping
