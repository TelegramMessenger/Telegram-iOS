import Foundation
import UIKit
import TelegramCore
import TelegramUIPreferences
import Postbox
import SwiftSignalKit

public func selectDateFillStaticColor(theme: PresentationTheme, wallpaper: TelegramWallpaper) -> UIColor {
    if case .color(0xffffff) = wallpaper {
        return theme.chat.serviceMessage.components.withDefaultWallpaper.dateFillStatic
    } else if case .builtin = wallpaper {
        return UIColor(rgb: 0x748391, alpha: 0.45)
    } else {
        return theme.chat.serviceMessage.components.withCustomWallpaper.dateFillStatic
    }
}

public func selectReactionFillStaticColor(theme: PresentationTheme, wallpaper: TelegramWallpaper) -> UIColor {
    if case .color = wallpaper {
        return theme.chat.message.freeform.withoutWallpaper.reactionInactiveBackground
    } else if theme.overallDarkAppearance {
        return theme.chat.message.freeform.withoutWallpaper.reactionInactiveBackground
    } else if case .builtin = wallpaper {
        return UIColor(rgb: 0x748391, alpha: 0.45)
    } else {
        return theme.chat.serviceMessage.components.withCustomWallpaper.dateFillStatic
    }
}

public func dateFillNeedsBlur(theme: PresentationTheme, wallpaper: TelegramWallpaper) -> Bool {
    if case .builtin = wallpaper {
        return false
    } else if case .color = wallpaper {
        return false
    } else if case let .file(file) = wallpaper {
        if file.isPattern, let intensity = file.settings.intensity, intensity < 0 {
            return false
        } else {
            return true
        }
    } else {
        return true
    }
}

public let defaultServiceBackgroundColor = UIColor(rgb: 0x000000, alpha: 0.2)
public let defaultPresentationTheme = makeDefaultDayPresentationTheme(serviceBackgroundColor: defaultServiceBackgroundColor, day: false, preview: false)
public let defaultDayAccentColor = UIColor(rgb: 0x007aff)

public func customizeDefaultDayTheme(theme: PresentationTheme, editing: Bool, title: String?, accentColor: UIColor?, outgoingAccentColor: UIColor?, backgroundColors: [UInt32], bubbleColors: [UInt32], animateBubbleColors: Bool?, wallpaper forcedWallpaper: TelegramWallpaper? = nil, serviceBackgroundColor: UIColor?) -> PresentationTheme {
    if (theme.referenceTheme != .day && theme.referenceTheme != .dayClassic) {
        return theme
    }
    
    let day = theme.referenceTheme == .day
    var intro = theme.intro
    var rootController = theme.rootController
    var list = theme.list
    var chatList = theme.chatList
    var chat = theme.chat
    var actionSheet = theme.actionSheet
    
    var outgoingAccent: UIColor?
    var suggestedWallpaper: TelegramWallpaper?
    
    var bubbleColors = bubbleColors  
    if bubbleColors.isEmpty, editing {
        if day {
            let accentColor = accentColor ?? defaultDayAccentColor
            bubbleColors = [accentColor.withMultiplied(hue: 0.966, saturation: 0.61, brightness: 0.98).rgb, accentColor.rgb]
            outgoingAccent = outgoingAccentColor
        } else {
            if let accentColor = accentColor, !accentColor.alpha.isZero {
                let hsb = accentColor.hsb
                bubbleColors = [UIColor(hue: hsb.0, saturation: (hsb.1 > 0.0 && hsb.2 > 0.0) ? 0.14 : 0.0, brightness: 0.79 + hsb.2 * 0.21, alpha: 1.0).rgb]
                if let outgoingAccentColor = outgoingAccentColor {
                    outgoingAccent = outgoingAccentColor
                } else {
                    if accentColor.lightness > 0.705 {
                        outgoingAccent = UIColor(hue: hsb.0, saturation: min(1.0, hsb.1 * 1.1), brightness: min(hsb.2, 0.6), alpha: 1.0)
                    } else {
                        outgoingAccent = accentColor
                    }
                }

                suggestedWallpaper = .gradient(TelegramWallpaper.Gradient(id: nil, colors: defaultBuiltinWallpaperGradientColors.map(\.rgb), settings: WallpaperSettings()))
            } else {
                bubbleColors = [UIColor(rgb: 0xe1ffc7).rgb]
                suggestedWallpaper = .gradient(TelegramWallpaper.Gradient(id: nil, colors: defaultBuiltinWallpaperGradientColors.map(\.rgb), settings: WallpaperSettings()))
                outgoingAccent = outgoingAccentColor
            }
        }
    } else {
        outgoingAccent = outgoingAccentColor
    }
    
    var accentColor = accentColor
    if let initialAccentColor = accentColor, initialAccentColor.lightness > 0.705 {
        let hsb = initialAccentColor.hsb
        accentColor = UIColor(hue: hsb.0, saturation: min(1.0, hsb.1 * 1.1), brightness: min(hsb.2, 0.6), alpha: 1.0)
    }
    
    if let accentColor = accentColor {
        intro = intro.withUpdated(accentTextColor: accentColor)
        rootController = rootController.withUpdated(
            tabBar: rootController.tabBar.withUpdated(selectedIconColor: accentColor, selectedTextColor: accentColor),
            navigationBar: rootController.navigationBar.withUpdated(buttonColor: accentColor, accentTextColor: accentColor),
            navigationSearchBar: rootController.navigationSearchBar.withUpdated(accentColor: accentColor)
        )
        list = list.withUpdated(
            itemAccentColor: accentColor,
            itemDisclosureActions: list.itemDisclosureActions.withUpdated(accent: list.itemDisclosureActions.accent.withUpdated(fillColor: accentColor)),
            itemCheckColors: list.itemCheckColors.withUpdated(fillColor: accentColor),
            itemBarChart: list.itemBarChart.withUpdated(color1: accentColor)
        )
        chatList = chatList.withUpdated(
            checkmarkColor: day ? accentColor : nil,
            unreadBadgeActiveBackgroundColor: accentColor,
            verifiedIconFillColor: day ? accentColor : nil
        )
        actionSheet = actionSheet.withUpdated(
            standardActionTextColor: accentColor,
            controlAccentColor: accentColor
        )
    }
        
    var incomingBubbleStrokeColor: UIColor?
    var outgoingBubbleFillColors: [UIColor]?
    var outgoingBubbleHighlightedFill: UIColor?
    var outgoingBubbleStrokeColor: UIColor?
    var outgoingPrimaryTextColor: UIColor?
    var outgoingSecondaryTextColor: UIColor?
    var outgoingLinkTextColor: UIColor?
    var outgoingScamColor: UIColor?
    var outgoingAccentTextColor: UIColor?
    var outgoingControlColor: UIColor?
    var outgoingInactiveControlColor: UIColor?
    var outgoingPendingActivityColor: UIColor?
    var outgoingFileTitleColor: UIColor?
    var outgoingFileDescriptionColor: UIColor?
    var outgoingFileDurationColor: UIColor?
    var outgoingMediaPlaceholderColor: UIColor?
    var outgoingPollsButtonColor: UIColor?
    var outgoingPollsProgressColor: UIColor?
    var outgoingSelectionColor: UIColor?
    var outgoingSelectionBaseColor: UIColor?
    var outgoingCheckColor: UIColor?
    
    if !day {
        if let outgoingAccent = outgoingAccent {
            outgoingBubbleStrokeColor = outgoingAccent.withAlphaComponent(0.2)
        } else {
            let bubbleStrokeColor = serviceBackgroundColor?.withMultiplied(hue: 0.999, saturation: 1.667, brightness: 1.1).withAlphaComponent(0.2)
            incomingBubbleStrokeColor = bubbleStrokeColor
            outgoingBubbleStrokeColor = bubbleStrokeColor
        }
    }
    
    if !bubbleColors.isEmpty {
        outgoingBubbleFillColors = bubbleColors.map(UIColor.init(rgb:))

        if day {
            outgoingBubbleStrokeColor = .clear
        }
        
        outgoingBubbleHighlightedFill = outgoingBubbleFillColors?.first?.withMultiplied(hue: 1.00, saturation: 1.589, brightness: 0.96)
        
        let lightnessColor = UIColor.average(of: bubbleColors.map(UIColor.init(rgb:)))
        if lightnessColor.lightness > 0.705 {
            let hueFactor: CGFloat = 0.75
            let saturationFactor: CGFloat = 1.1
            outgoingPrimaryTextColor = UIColor(rgb: 0x000000)
            
            if let outgoingAccent = outgoingAccent {
                outgoingSecondaryTextColor = outgoingAccent
                outgoingAccentTextColor = outgoingAccent
                outgoingLinkTextColor = outgoingAccent
                outgoingScamColor = UIColor(rgb: 0xff3b30)
                outgoingControlColor = outgoingAccent
                outgoingInactiveControlColor = outgoingAccent
                outgoingFileTitleColor = outgoingAccent
                outgoingPollsProgressColor = outgoingControlColor
                outgoingSelectionColor = outgoingAccent.withAlphaComponent(0.2)
                outgoingSelectionBaseColor = outgoingControlColor
                outgoingCheckColor = outgoingAccent
            } else {
                let outgoingBubbleMixedColor = lightnessColor
                outgoingSecondaryTextColor = outgoingBubbleFillColors?.first?.withMultiplied(hue: 1.344 * hueFactor, saturation: 4.554 * saturationFactor, brightness: 0.549).withAlphaComponent(0.8)
                outgoingAccentTextColor = outgoingBubbleMixedColor.withMultiplied(hue: 1.302 * hueFactor, saturation: 4.554 * saturationFactor, brightness: 0.655)
                outgoingLinkTextColor = UIColor(rgb: 0x004bad)
                outgoingScamColor = UIColor(rgb: 0xff3b30)
                outgoingControlColor = outgoingBubbleMixedColor.withMultiplied(hue: 1.283 * hueFactor, saturation: 3.176, brightness: 0.765)
                outgoingInactiveControlColor = outgoingBubbleMixedColor.withMultiplied(hue: 1.207 * hueFactor, saturation: 1.721, brightness: 0.851)
                outgoingFileTitleColor = outgoingBubbleMixedColor.withMultiplied(hue: 1.285 * hueFactor, saturation: 2.946, brightness: 0.667)
                outgoingPollsProgressColor = outgoingBubbleMixedColor.withMultiplied(hue: 1.283 * hueFactor, saturation: 3.176, brightness: 0.765)
                outgoingSelectionColor = outgoingBubbleMixedColor.withMultiplied(hue: 1.013 * hueFactor, saturation: 1.292, brightness: 0.871)
                outgoingSelectionBaseColor = outgoingControlColor
                outgoingCheckColor = outgoingBubbleMixedColor.withMultiplied(hue: 1.344 * hueFactor, saturation: 4.554 * saturationFactor, brightness: 0.549).withAlphaComponent(0.8)
            }
            outgoingPendingActivityColor = outgoingCheckColor
            
            outgoingFileDescriptionColor = outgoingBubbleFillColors?.first?.withMultiplied(hue: 1.257 * hueFactor, saturation: 1.842, brightness: 0.698)
            outgoingFileDurationColor = outgoingBubbleFillColors?.first?.withMultiplied(hue: 1.344 * hueFactor, saturation: 4.554, brightness: 0.549).withAlphaComponent(0.8)
            outgoingMediaPlaceholderColor = outgoingBubbleFillColors?.first?.withMultiplied(hue: 0.998, saturation: 1.129, brightness: 0.949)
            outgoingPollsButtonColor = outgoingBubbleFillColors?.first?.withMultiplied(hue: 1.207 * hueFactor, saturation: 1.721, brightness: 0.851)

            if day {
                if let distance = outgoingBubbleFillColors?.first?.distance(to: UIColor(rgb: 0xffffff)), distance < 200 {
                    outgoingBubbleStrokeColor = UIColor(rgb: 0xc8c7cc)
                }
            }
        } else {
            outgoingPrimaryTextColor = UIColor(rgb: 0xffffff)
            outgoingSecondaryTextColor = UIColor(rgb: 0xffffff, alpha: 0.65)
            outgoingAccentTextColor = outgoingPrimaryTextColor
            outgoingLinkTextColor = UIColor(rgb: 0xffffff)
            outgoingScamColor = outgoingPrimaryTextColor
            outgoingControlColor = outgoingPrimaryTextColor
            outgoingInactiveControlColor = outgoingSecondaryTextColor
            outgoingPendingActivityColor = outgoingSecondaryTextColor
            outgoingFileTitleColor = outgoingPrimaryTextColor
            outgoingFileDescriptionColor = outgoingSecondaryTextColor
            outgoingFileDurationColor = outgoingSecondaryTextColor
            outgoingMediaPlaceholderColor = outgoingBubbleFillColors?.first?.withMultipliedBrightnessBy(0.95)
            outgoingPollsButtonColor = outgoingSecondaryTextColor
            outgoingPollsProgressColor = outgoingPrimaryTextColor
            outgoingSelectionBaseColor = UIColor(rgb: 0xffffff)
            outgoingSelectionColor = outgoingSelectionBaseColor?.withAlphaComponent(0.2)
            outgoingCheckColor = UIColor(rgb: 0xffffff)
        }
    }
    
    var defaultWallpaper: TelegramWallpaper?
    if let forcedWallpaper = forcedWallpaper {
        defaultWallpaper = forcedWallpaper
    } else if !backgroundColors.isEmpty {
        if backgroundColors.count >= 2 {
            defaultWallpaper = .gradient(TelegramWallpaper.Gradient(id: nil, colors: backgroundColors, settings: WallpaperSettings()))
        } else {
            defaultWallpaper = .color(backgroundColors[0])
        }
    } else if let forcedWallpaper = suggestedWallpaper {
        defaultWallpaper = forcedWallpaper
    }
    
    chat = chat.withUpdated(
        defaultWallpaper: defaultWallpaper,
        animateMessageColors: animateBubbleColors,
        message: chat.message.withUpdated(
            incoming: chat.message.incoming.withUpdated(
                bubble: chat.message.incoming.bubble.withUpdated(
                    withWallpaper: chat.message.incoming.bubble.withWallpaper.withUpdated(
                        stroke: incomingBubbleStrokeColor,
                        reactionInactiveBackground: accentColor?.withMultipliedAlpha(0.1),
                        reactionInactiveForeground: accentColor,
                        reactionActiveBackground: accentColor,
                        reactionActiveForeground: .clear
                    ),
                    withoutWallpaper: chat.message.incoming.bubble.withoutWallpaper.withUpdated(
                        stroke: incomingBubbleStrokeColor,
                        reactionInactiveBackground: accentColor?.withMultipliedAlpha(0.1),
                        reactionInactiveForeground: accentColor,
                        reactionActiveBackground: accentColor,
                        reactionActiveForeground: .clear
                    )
                ),
                linkHighlightColor: accentColor?.withAlphaComponent(0.3),
                accentTextColor: accentColor,
                accentControlColor: accentColor,
                accentControlDisabledColor: accentColor?.withAlphaComponent(0.7),
                mediaActiveControlColor: accentColor,
                fileTitleColor: accentColor,
                polls: chat.message.incoming.polls.withUpdated(
                    radioProgress: accentColor,
                    highlight: accentColor?.withAlphaComponent(0.12),
                    bar: accentColor
                ),
                actionButtonsFillColor: serviceBackgroundColor.flatMap { chat.message.incoming.actionButtonsFillColor.withUpdated(withWallpaper: $0) },
                actionButtonsStrokeColor: day ? chat.message.incoming.actionButtonsStrokeColor.withUpdated(withoutWallpaper: accentColor) : nil,
                actionButtonsTextColor: day ? chat.message.incoming.actionButtonsTextColor.withUpdated(withoutWallpaper: accentColor) : nil,
                textSelectionColor: accentColor?.withAlphaComponent(0.2),
                textSelectionKnobColor: accentColor
            ),
            outgoing: chat.message.outgoing.withUpdated(
                bubble: chat.message.outgoing.bubble.withUpdated(
                    withWallpaper: chat.message.outgoing.bubble.withWallpaper.withUpdated(
                        fill: outgoingBubbleFillColors,
                        highlightedFill: outgoingBubbleHighlightedFill,
                        stroke: outgoingBubbleStrokeColor,
                        reactionInactiveBackground: outgoingControlColor?.withMultipliedAlpha(0.1),
                        reactionInactiveForeground: outgoingControlColor,
                        reactionActiveBackground: outgoingControlColor,
                        reactionActiveForeground: .clear
                    ),
                    withoutWallpaper: chat.message.outgoing.bubble.withoutWallpaper.withUpdated(
                        fill: outgoingBubbleFillColors,
                        highlightedFill: outgoingBubbleHighlightedFill,
                        stroke: outgoingBubbleStrokeColor,
                        reactionInactiveBackground: outgoingControlColor?.withMultipliedAlpha(0.1),
                        reactionInactiveForeground: outgoingControlColor,
                        reactionActiveBackground: outgoingControlColor,
                        reactionActiveForeground: .clear
                    )
                ),
                primaryTextColor: outgoingPrimaryTextColor,
                secondaryTextColor: outgoingSecondaryTextColor,
                linkTextColor: outgoingLinkTextColor,
                linkHighlightColor: day ? nil : accentColor?.withAlphaComponent(0.3),
                scamColor: outgoingScamColor,
                accentTextColor: outgoingAccentTextColor,
                accentControlColor: outgoingControlColor,
                accentControlDisabledColor: outgoingControlColor?.withAlphaComponent(0.7),
                mediaActiveControlColor: outgoingControlColor,
                mediaInactiveControlColor: outgoingInactiveControlColor,
                mediaControlInnerBackgroundColor: .clear,
                pendingActivityColor: outgoingPendingActivityColor,
                fileTitleColor: outgoingFileTitleColor,
                fileDescriptionColor: outgoingFileDescriptionColor,
                fileDurationColor: outgoingFileDurationColor,
                mediaPlaceholderColor: day ? accentColor?.withMultipliedBrightnessBy(0.95) : outgoingMediaPlaceholderColor,
                polls: chat.message.outgoing.polls.withUpdated(radioButton: outgoingPollsButtonColor, radioProgress: outgoingPollsProgressColor, highlight: outgoingPollsProgressColor?.withAlphaComponent(0.12), separator: outgoingPollsButtonColor, bar: outgoingPollsProgressColor, barIconForeground: .clear, barPositive: outgoingPollsProgressColor, barNegative: outgoingPollsProgressColor),
                actionButtonsFillColor: chat.message.outgoing.actionButtonsFillColor.withUpdated(withWallpaper: serviceBackgroundColor),
                actionButtonsStrokeColor: day ? chat.message.outgoing.actionButtonsStrokeColor.withUpdated(withoutWallpaper: accentColor) : nil,
                actionButtonsTextColor: day ? chat.message.outgoing.actionButtonsTextColor.withUpdated(withoutWallpaper: accentColor) : nil,
                textSelectionColor: outgoingSelectionColor,
                textSelectionKnobColor: outgoingSelectionBaseColor),
            outgoingCheckColor: outgoingCheckColor,
            shareButtonFillColor: serviceBackgroundColor.flatMap { chat.message.shareButtonFillColor.withUpdated(withWallpaper: $0) },
            shareButtonForegroundColor: chat.message.shareButtonForegroundColor.withUpdated(withoutWallpaper: day ? accentColor : nil),
            selectionControlColors: chat.message.selectionControlColors.withUpdated(fillColor: accentColor)),
        serviceMessage: serviceBackgroundColor.flatMap {
            chat.serviceMessage.withUpdated(components: chat.serviceMessage.components.withUpdated(withCustomWallpaper: chat.serviceMessage.components.withCustomWallpaper.withUpdated(fill: $0, dateFillStatic: $0, dateFillFloating: $0.withAlphaComponent($0.alpha * 0.6667))))
        },
        inputPanel: chat.inputPanel.withUpdated(
            panelControlAccentColor: accentColor,
            actionControlFillColor: accentColor,
            mediaRecordingControl: chat.inputPanel.mediaRecordingControl.withUpdated(
                buttonColor: accentColor,
                micLevelColor: accentColor?.withAlphaComponent(0.2)
            )
        ),
        historyNavigation: chat.historyNavigation.withUpdated(
            badgeBackgroundColor: accentColor,
            badgeStrokeColor: accentColor
        )
    )
    
    return PresentationTheme(
        name: title.flatMap { .custom($0) } ?? theme.name,
        index: theme.index,
        referenceTheme: theme.referenceTheme,
        overallDarkAppearance: theme.overallDarkAppearance,
        intro: intro,
        passcode: theme.passcode,
        rootController: rootController,
        list: list,
        chatList: chatList,
        chat: chat,
        actionSheet: actionSheet,
        contextMenu: theme.contextMenu,
        inAppNotification: theme.inAppNotification,
        chart: theme.chart,
        preview: theme.preview
    )
}

public func makeDefaultDayPresentationTheme(extendingThemeReference: PresentationThemeReference? = nil, serviceBackgroundColor: UIColor?, day: Bool, preview: Bool) -> PresentationTheme {
    var serviceBackgroundColor = serviceBackgroundColor ?? defaultServiceBackgroundColor

    if !day {
        serviceBackgroundColor = UIColor(white: 0.0, alpha: 0.2)
    }
    
    let intro = PresentationThemeIntro(
        statusBarStyle: .black,
        primaryTextColor: UIColor(rgb: 0x000000),
        accentTextColor: defaultDayAccentColor,
        disabledTextColor: UIColor(rgb: 0xd0d0d0),
        startButtonColor: UIColor(rgb: 0x2ca5e0),
        dotColor: UIColor(rgb: 0xd9d9d9)
    )
    
    let passcode = PresentationThemePasscode(
        backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x46739e), bottomColor: UIColor(rgb: 0x2a5982)),
        buttonColor: .clear
    )
    
    let rootNavigationBar = PresentationThemeRootNavigationBar(
        buttonColor: defaultDayAccentColor,
        disabledButtonColor: UIColor(rgb: 0xd0d0d0),
        primaryTextColor: UIColor(rgb: 0x000000),
        secondaryTextColor: UIColor(rgb: 0x787878),
        controlColor: UIColor(rgb: 0x7e8791),
        accentTextColor: defaultDayAccentColor,
        blurredBackgroundColor: UIColor(rgb: 0xf2f2f2, alpha: 0.9),
        opaqueBackgroundColor: UIColor(rgb: 0xf7f7f7).mixedWith(.white, alpha: 0.14),
        separatorColor: UIColor(rgb: 0xc8c7cc),
        badgeBackgroundColor: UIColor(rgb: 0xff3b30),
        badgeStrokeColor: UIColor(rgb: 0xff3b30),
        badgeTextColor: UIColor(rgb: 0xffffff),
        segmentedBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.06),
        segmentedForegroundColor: UIColor(rgb: 0xf7f7f7),
        segmentedTextColor: UIColor(rgb: 0x000000),
        segmentedDividerColor: UIColor(rgb: 0xd6d6dc),
        clearButtonBackgroundColor: UIColor(rgb: 0xE3E3E3, alpha: 0.78),
        clearButtonForegroundColor: UIColor(rgb: 0x7f7f7f)
    )

    let rootTabBar = PresentationThemeRootTabBar(
        backgroundColor: rootNavigationBar.blurredBackgroundColor,
        separatorColor: UIColor(rgb: 0xa3a3a3),
        iconColor: UIColor(rgb: 0x959595),
        selectedIconColor: defaultDayAccentColor,
        textColor: UIColor(rgb: 0x959595),
        selectedTextColor: defaultDayAccentColor,
        badgeBackgroundColor: UIColor(rgb: 0xff3b30),
        badgeStrokeColor: UIColor(rgb: 0xff3b30),
        badgeTextColor: UIColor(rgb: 0xffffff)
    )
    
    let navigationSearchBar = PresentationThemeNavigationSearchBar(
        backgroundColor: UIColor(rgb: 0xffffff),
        accentColor: defaultDayAccentColor,
        inputFillColor: UIColor(rgb: 0x000000, alpha: 0.06),
        inputTextColor: UIColor(rgb: 0x000000),
        inputPlaceholderTextColor: UIColor(rgb: 0x8e8e93),
        inputIconColor: UIColor(rgb: 0x8e8e93),
        inputClearButtonColor: UIColor(rgb: 0x7b7b81),
        separatorColor: UIColor(rgb: 0xc8c7cc)
    )
        
    let rootController = PresentationThemeRootController(
        statusBarStyle: .black,
        tabBar: rootTabBar,
        navigationBar: rootNavigationBar,
        navigationSearchBar: navigationSearchBar,
        keyboardColor: .light
    )
    
    let switchColors = PresentationThemeSwitch(
        frameColor: UIColor(rgb: 0xe9e9ea),
        handleColor: UIColor(rgb: 0xffffff),
        contentColor: UIColor(rgb: 0x35c759),
        positiveColor: UIColor(rgb: 0x00c900),
        negativeColor: UIColor(rgb: 0xff3b30)
    )
    
    let list = PresentationThemeList(
        blocksBackgroundColor: UIColor(rgb: 0xefeff4),
        modalBlocksBackgroundColor: UIColor(rgb: 0xefeff4),
        plainBackgroundColor: UIColor(rgb: 0xffffff),
        modalPlainBackgroundColor: UIColor(rgb: 0xffffff),
        itemPrimaryTextColor: UIColor(rgb: 0x000000),
        itemSecondaryTextColor: UIColor(rgb: 0x8e8e93),
        itemDisabledTextColor: UIColor(rgb: 0x8e8e93),
        itemAccentColor: defaultDayAccentColor,
        itemHighlightedColor: UIColor(rgb: 0x00b12c),
        itemDestructiveColor: UIColor(rgb: 0xff3b30),
        itemPlaceholderTextColor: UIColor(rgb: 0xc8c8ce),
        itemBlocksBackgroundColor: UIColor(rgb: 0xffffff),
        itemModalBlocksBackgroundColor: UIColor(rgb: 0xffffff),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xe5e5ea),
        itemBlocksSeparatorColor: UIColor(rgb: 0xc8c7cc),
        itemPlainSeparatorColor: UIColor(rgb: 0xc8c7cc),
        disclosureArrowColor: UIColor(rgb: 0xbab9be),
        sectionHeaderTextColor: UIColor(rgb: 0x6d6d72),
        freeTextColor: UIColor(rgb: 0x6d6d72),
        freeTextErrorColor: UIColor(rgb: 0xcf3030),
        freeTextSuccessColor: UIColor(rgb: 0x26972c),
        freeMonoIconColor: UIColor(rgb: 0x7e7e87),
        itemSwitchColors: switchColors,
        itemDisclosureActions: PresentationThemeItemDisclosureActions(
            neutral1: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x4892f2), foregroundColor: UIColor(rgb: 0xffffff)),
            neutral2: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xf09a37), foregroundColor: UIColor(rgb: 0xffffff)),
            destructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xff3824), foregroundColor: UIColor(rgb: 0xffffff)),
            constructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x00c900), foregroundColor: UIColor(rgb: 0xffffff)),
            accent: PresentationThemeFillForeground(fillColor: defaultDayAccentColor, foregroundColor: UIColor(rgb: 0xffffff)),
            warning: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xff9500), foregroundColor: UIColor(rgb: 0xffffff)),
            inactive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xbcbcc3), foregroundColor: UIColor(rgb: 0xffffff))
        ),
        itemCheckColors: PresentationThemeFillStrokeForeground(
            fillColor: defaultDayAccentColor,
            strokeColor: UIColor(rgb: 0xc7c7cc),
            foregroundColor: UIColor(rgb: 0xffffff)
        ),
        controlSecondaryColor: UIColor(rgb: 0xdedede),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: UIColor(rgb: 0xd6d6dc),
            strokeColor: UIColor(rgb: 0xd6d6dc),
            placeholderColor: UIColor(rgb: 0x96979d),
            primaryColor: UIColor(rgb: 0x000000),
            controlColor: UIColor(rgb: 0x96979d)
        ),
        freePlainInputField: PresentationInputFieldTheme(
            backgroundColor: UIColor(rgb: 0xe9e9e9),
            strokeColor: UIColor(rgb: 0xe9e9e9),
            placeholderColor: UIColor(rgb: 0x8e8d92),
            primaryColor: UIColor(rgb: 0x000000),
            controlColor: UIColor(rgb: 0xbcbcc0)
        ),
        mediaPlaceholderColor: UIColor(rgb: 0xEFEFF4),
        scrollIndicatorColor: UIColor(white: 0.0, alpha: 0.3),
        pageIndicatorInactiveColor: UIColor(rgb: 0xe3e3e7),
        inputClearButtonColor: UIColor(rgb: 0xcccccc),
        itemBarChart: PresentationThemeItemBarChart(color1: defaultDayAccentColor, color2: UIColor(rgb: 0xc8c7cc), color3: UIColor(rgb: 0xf2f1f7)),
        itemInputField: PresentationInputFieldTheme(backgroundColor: UIColor(rgb: 0xf2f2f7), strokeColor: UIColor(rgb: 0xf2f2f7), placeholderColor: UIColor(rgb: 0xb6b6bb), primaryColor: UIColor(rgb: 0x000000), controlColor: UIColor(rgb: 0xb6b6bb)),
        paymentOption: PresentationThemeList.PaymentOption(
            inactiveFillColor: UIColor(rgb: 0x00A650).withMultipliedAlpha(0.1),
            inactiveForegroundColor: UIColor(rgb: 0x00A650),
            activeFillColor: UIColor(rgb: 0x00A650),
            activeForegroundColor: UIColor(rgb: 0xffffff)
        )
    )
    
    let chatList = PresentationThemeChatList(
        backgroundColor: UIColor(rgb: 0xffffff),
        itemSeparatorColor: UIColor(rgb: 0xc8c7cc),
        itemBackgroundColor: UIColor(rgb: 0xffffff),
        pinnedItemBackgroundColor: UIColor(rgb: 0xf7f7f7),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xe5e5ea),
        itemSelectedBackgroundColor: UIColor(rgb: 0xe9f0fa),
        titleColor: UIColor(rgb: 0x000000),
        secretTitleColor: UIColor(rgb: 0x00b12c),
        dateTextColor: UIColor(rgb: 0x8e8e93),
        authorNameColor: UIColor(rgb: 0x000000),
        messageTextColor: UIColor(rgb: 0x8e8e93),
        messageHighlightedTextColor: UIColor(rgb: 0x000000),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: day ? defaultDayAccentColor : UIColor(rgb: 0x21c004),
        pendingIndicatorColor: UIColor(rgb: 0x8e8e93),
        failedFillColor: UIColor(rgb: 0xff3b30),
        failedForegroundColor: UIColor(rgb: 0xffffff),
        muteIconColor: UIColor(rgb: 0xa7a7ad),
        unreadBadgeActiveBackgroundColor: defaultDayAccentColor,
        unreadBadgeActiveTextColor: UIColor(rgb: 0xffffff),
        unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0xb6b6bb),
        unreadBadgeInactiveTextColor: UIColor(rgb: 0xffffff),
        reactionBadgeActiveBackgroundColor: UIColor(rgb: 0xFF2D55),
        pinnedBadgeColor: UIColor(rgb: 0xb6b6bb),
        pinnedSearchBarColor: UIColor(rgb: 0xe5e5e5),
        regularSearchBarColor: UIColor(rgb: 0xe9e9e9),
        sectionHeaderFillColor: UIColor(rgb: 0xf7f7f7),
        sectionHeaderTextColor: UIColor(rgb: 0x8e8e93),
        verifiedIconFillColor: defaultDayAccentColor,
        verifiedIconForegroundColor: UIColor(rgb: 0xffffff),
        secretIconColor: UIColor(rgb: 0x00b12c),
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x72d5fd), bottomColor: UIColor(rgb: 0x2a9ef1)), foregroundColor: UIColor(rgb: 0xffffff)),
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0xdedee5), bottomColor: UIColor(rgb: 0xc5c6cc)), foregroundColor: UIColor(rgb: 0xffffff)),
        onlineDotColor: UIColor(rgb: 0x4cc91f)
    )
    
    let bubbleStrokeColor: UIColor
    if day {
        bubbleStrokeColor = serviceBackgroundColor.withMultiplied(hue: 0.999, saturation: 1.667, brightness: 1.1).withAlphaComponent(0.2)
    } else {
        bubbleStrokeColor = UIColor(white: 0.0, alpha: 0.2)
    }

    let message = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(
            bubble: PresentationThemeBubbleColor(
                withWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0xffffff)],
                    highlightedFill: UIColor(rgb: 0xd9f4ff),
                    stroke: bubbleStrokeColor,
                    shadow: nil,
                    reactionInactiveBackground: defaultDayAccentColor.withMultipliedAlpha(0.1),
                    reactionInactiveForeground: defaultDayAccentColor,
                    reactionActiveBackground: defaultDayAccentColor,
                    reactionActiveForeground: .clear
                ),
                withoutWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0xffffff)],
                    highlightedFill: UIColor(rgb: 0xd9f4ff),
                    stroke: bubbleStrokeColor,
                    shadow: nil,
                    reactionInactiveBackground: defaultDayAccentColor.withMultipliedAlpha(0.1),
                    reactionInactiveForeground: defaultDayAccentColor,
                    reactionActiveBackground: defaultDayAccentColor,
                    reactionActiveForeground: .clear
                )
            ),
            primaryTextColor: UIColor(rgb: 0x000000),
            secondaryTextColor: UIColor(rgb: 0x525252, alpha: 0.6),
            linkTextColor: UIColor(rgb: 0x004bad),
            linkHighlightColor: defaultDayAccentColor.withAlphaComponent(0.3),
            scamColor: UIColor(rgb: 0xff3b30),
            textHighlightColor: UIColor(rgb: 0xffe438),
            accentTextColor: defaultDayAccentColor,
            accentControlColor: defaultDayAccentColor,
            accentControlDisabledColor: UIColor(rgb: 0x525252, alpha: 0.6),
            mediaActiveControlColor: defaultDayAccentColor,
            mediaInactiveControlColor: UIColor(rgb: 0xcacaca),
            mediaControlInnerBackgroundColor: UIColor(rgb: 0xffffff),
            pendingActivityColor: UIColor(rgb: 0x525252, alpha: 0.6),
            fileTitleColor: UIColor(rgb: 0x0b8bed),
            fileDescriptionColor: UIColor(rgb: 0x999999),
            fileDurationColor: UIColor(rgb: 0x525252, alpha: 0.6),
            mediaPlaceholderColor: UIColor(rgb: 0xe8ecf0),
            polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0xc8c7cc), radioProgress: defaultDayAccentColor, highlight: defaultDayAccentColor.withAlphaComponent(0.08), separator: UIColor(rgb: 0xc8c7cc), bar: defaultDayAccentColor, barIconForeground: .white, barPositive: UIColor(rgb: 0x2dba45), barNegative: UIColor(rgb: 0xFE3824)),
            actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0x596e89, alpha: 0.35)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: .clear),
            actionButtonsTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)), textSelectionColor: defaultDayAccentColor.withAlphaComponent(0.2), textSelectionKnobColor: defaultDayAccentColor),
        outgoing: PresentationThemePartedColors(
            bubble: PresentationThemeBubbleColor(
                withWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0xe1ffc7)],
                    highlightedFill: UIColor(rgb: 0xc8ffa6),
                    stroke: bubbleStrokeColor,
                    shadow: nil,
                    reactionInactiveBackground: UIColor(rgb: 0x2DA32F).withMultipliedAlpha(0.12),
                    reactionInactiveForeground: UIColor(rgb: 0x2DA32F),
                    reactionActiveBackground: UIColor(rgb: 0x2DA32F),
                    reactionActiveForeground: .clear
                ),
                withoutWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0xe1ffc7)],
                    highlightedFill: UIColor(rgb: 0xc8ffa6),
                    stroke: bubbleStrokeColor,
                    shadow: nil,
                    reactionInactiveBackground: UIColor(rgb: 0x2DA32F).withMultipliedAlpha(0.12),
                    reactionInactiveForeground: UIColor(rgb: 0x2DA32F),
                    reactionActiveBackground: UIColor(rgb: 0x2DA32F),
                    reactionActiveForeground: .clear
                )
            ),
            primaryTextColor: UIColor(rgb: 0x000000),
            secondaryTextColor: UIColor(rgb: 0x008c09, alpha: 0.8),
            linkTextColor: UIColor(rgb: 0x004bad),
            linkHighlightColor: defaultDayAccentColor.withAlphaComponent(0.3),
            scamColor: UIColor(rgb: 0xff3b30),
            textHighlightColor: UIColor(rgb: 0xffe438),
            accentTextColor: UIColor(rgb: 0x00a700),
            accentControlColor: UIColor(rgb: 0x3fc33b),
            accentControlDisabledColor: UIColor(rgb: 0x3fc33b).withAlphaComponent(0.7),
            mediaActiveControlColor: UIColor(rgb: 0x3fc33b),
            mediaInactiveControlColor: UIColor(rgb: 0x93d987),
            mediaControlInnerBackgroundColor: UIColor(rgb: 0xe1ffc7),
            pendingActivityColor: UIColor(rgb: 0x42b649),
            fileTitleColor: UIColor(rgb: 0x3faa3c),
            fileDescriptionColor: UIColor(rgb: 0x6fb26a),
            fileDurationColor: UIColor(rgb: 0x008c09, alpha: 0.8),
            mediaPlaceholderColor: UIColor(rgb: 0xd2f2b6),
            polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x93d987), radioProgress: UIColor(rgb: 0x3fc33b), highlight: UIColor(rgb: 0x3fc33b).withAlphaComponent(0.08), separator: UIColor(rgb: 0x93d987), bar: UIColor(rgb: 0x00A700), barIconForeground: .white, barPositive: UIColor(rgb: 0x00A700), barNegative: UIColor(rgb: 0x00A700)),
            actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0x596e89, alpha: 0.35)),
            actionButtonsStrokeColor: PresentationThemeVariableColor(color: .clear),
            actionButtonsTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)),
            textSelectionColor: UIColor(rgb: 0xbbde9f),
            textSelectionKnobColor: UIColor(rgb: 0x3fc33b)),
        freeform: PresentationThemeBubbleColor(
            withWallpaper: PresentationThemeBubbleColorComponents(
                fill: [UIColor(rgb: 0xffffff)],
                highlightedFill: UIColor(rgb: 0xd9f4ff),
                stroke: UIColor(rgb: 0x86a9c9, alpha: 0.5),
                shadow: nil,
                reactionInactiveBackground: UIColor(rgb: 0xffffff),
                reactionInactiveForeground: UIColor(rgb: 0xffffff),
                reactionActiveBackground: UIColor(rgb: 0xffffff, alpha: 0.8),
                reactionActiveForeground: UIColor(white: 0.0, alpha: 0.1)
            ),
            withoutWallpaper: PresentationThemeBubbleColorComponents(
                fill: [UIColor(rgb: 0xffffff)],
                highlightedFill: UIColor(rgb: 0xd9f4ff),
                stroke: UIColor(rgb: 0x86a9c9, alpha: 0.5),
                shadow: nil,
                reactionInactiveBackground: UIColor(rgb: 0xffffff),
                reactionInactiveForeground: UIColor(rgb: 0xffffff),
                reactionActiveBackground: UIColor(rgb: 0xffffff, alpha: 0.8),
                reactionActiveForeground: UIColor(white: 0.0, alpha: 0.1)
            )
        ),
        infoPrimaryTextColor: UIColor(rgb: 0x000000),
        infoLinkTextColor: UIColor(rgb: 0x004bad),
        outgoingCheckColor: UIColor(rgb: 0x19c700),
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: UIColor(rgb: 0xffffff),
        shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0x748391, alpha: 0.45)),
        shareButtonStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: .clear),
        shareButtonForegroundColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xffffff), withoutWallpaper: UIColor(rgb: 0xffffff)),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: UIColor(rgb: 0xffffff)),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: defaultDayAccentColor, strokeColor: UIColor(rgb: 0xc7c7cc), foregroundColor: UIColor(rgb: 0xffffff)),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xff3b30), foregroundColor: UIColor(rgb: 0xffffff)),
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6),
        stickerPlaceholderColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0x748391, alpha: 0.25)),
        stickerPlaceholderShimmerColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xffffff, alpha: 0.2), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.1))
    )
    
    let messageDay = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(
            bubble: PresentationThemeBubbleColor(
                withWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0xffffff)],
                    highlightedFill: UIColor(rgb: 0xdadade),
                    stroke: UIColor(rgb: 0xffffff),
                    shadow: nil,
                    reactionInactiveBackground: defaultDayAccentColor.withMultipliedAlpha(0.1),
                    reactionInactiveForeground: defaultDayAccentColor,
                    reactionActiveBackground: defaultDayAccentColor,
                    reactionActiveForeground: .clear
                ),
                withoutWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0xf1f1f4)],
                    highlightedFill: UIColor(rgb: 0xdadade),
                    stroke: UIColor(rgb: 0xf1f1f4),
                    shadow: nil,
                    reactionInactiveBackground: .clear,
                    reactionInactiveForeground: defaultDayAccentColor,
                    reactionActiveBackground: defaultDayAccentColor,
                    reactionActiveForeground: .clear
                )
            ),
            primaryTextColor: UIColor(rgb: 0x000000),
            secondaryTextColor: UIColor(rgb: 0x525252, alpha: 0.6),
            linkTextColor: UIColor(rgb: 0x004bad),
            linkHighlightColor: defaultDayAccentColor.withAlphaComponent(0.3),
            scamColor: UIColor(rgb: 0xff3b30),
            textHighlightColor: UIColor(rgb: 0xffc738),
            accentTextColor: defaultDayAccentColor,
            accentControlColor: defaultDayAccentColor,
            accentControlDisabledColor: UIColor(rgb: 0x525252, alpha: 0.6),
            mediaActiveControlColor: defaultDayAccentColor,
            mediaInactiveControlColor: UIColor(rgb: 0xcacaca),
            mediaControlInnerBackgroundColor: UIColor(rgb: 0xffffff),
            pendingActivityColor: UIColor(rgb: 0x525252, alpha: 0.6),
            fileTitleColor: defaultDayAccentColor,
            fileDescriptionColor: UIColor(rgb: 0x999999),
            fileDurationColor: UIColor(rgb: 0x525252, alpha: 0.6),
            mediaPlaceholderColor: UIColor(rgb: 0xffffff).withMultipliedBrightnessBy(0.95),
            polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0xc8c7cc), radioProgress: defaultDayAccentColor, highlight: defaultDayAccentColor.withAlphaComponent(0.12), separator: UIColor(rgb: 0xc8c7cc), bar: defaultDayAccentColor, barIconForeground: .white, barPositive: UIColor(rgb: 0x00A700), barNegative: UIColor(rgb: 0xFE3824)),
            actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0xffffff, alpha: 0.8)),
            actionButtonsStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: defaultDayAccentColor),
            actionButtonsTextColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xffffff), withoutWallpaper: defaultDayAccentColor),
            textSelectionColor: defaultDayAccentColor.withAlphaComponent(0.3),
            textSelectionKnobColor: defaultDayAccentColor),
        outgoing: PresentationThemePartedColors(
            bubble: PresentationThemeBubbleColor(
                withWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0x57b2e0), defaultDayAccentColor],
                    highlightedFill: UIColor(rgb: 0x57b2e0).withMultipliedBrightnessBy(0.7),
                    stroke: .clear,
                    shadow: nil,
                    reactionInactiveBackground: UIColor(rgb: 0xffffff, alpha: 0.12),
                    reactionInactiveForeground: UIColor(rgb: 0xffffff),
                    reactionActiveBackground: UIColor(rgb: 0xffffff),
                    reactionActiveForeground: .clear
                ),
                withoutWallpaper: PresentationThemeBubbleColorComponents(
                    fill: [UIColor(rgb: 0x57b2e0), defaultDayAccentColor],
                    highlightedFill: UIColor(rgb: 0x57b2e0).withMultipliedBrightnessBy(0.7),
                    stroke: .clear,
                    shadow: nil,
                    reactionInactiveBackground: UIColor(rgb: 0xffffff, alpha: 0.12),
                    reactionInactiveForeground: UIColor(rgb: 0xffffff),
                    reactionActiveBackground: UIColor(rgb: 0xffffff),
                    reactionActiveForeground: .clear
                )
            ),
            primaryTextColor: UIColor(rgb: 0xffffff),
            secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.65),
            linkTextColor: UIColor(rgb: 0xffffff),
            linkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.3),
            scamColor: UIColor(rgb: 0xffffff),
            textHighlightColor: UIColor(rgb: 0xffc738),
            accentTextColor: UIColor(rgb: 0xffffff),
            accentControlColor: UIColor(rgb: 0xffffff),
            accentControlDisabledColor: UIColor(rgb: 0xffffff).withAlphaComponent(0.5),
            mediaActiveControlColor: UIColor(rgb: 0xffffff),
            mediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.65),
            mediaControlInnerBackgroundColor: .clear,
            pendingActivityColor: UIColor(rgb: 0xffffff, alpha: 0.65),
            fileTitleColor: UIColor(rgb: 0xffffff),
            fileDescriptionColor: UIColor(rgb: 0xffffff, alpha: 0.65),
            fileDurationColor: UIColor(rgb: 0xffffff, alpha: 0.65),
            mediaPlaceholderColor: UIColor(rgb: 0x0077d9),
            polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0xffffff, alpha: 0.65), radioProgress: UIColor(rgb: 0xffffff), highlight: UIColor(rgb: 0xffffff, alpha: 0.12), separator: UIColor(rgb: 0xffffff, alpha: 0.65), bar: UIColor(rgb: 0xffffff), barIconForeground: .clear, barPositive: UIColor(rgb: 0xffffff), barNegative: UIColor(rgb: 0xffffff)),
            actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0xffffff, alpha: 0.8)),
            actionButtonsStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: defaultDayAccentColor),
            actionButtonsTextColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xffffff), withoutWallpaper: defaultDayAccentColor),
            textSelectionColor: UIColor(rgb: 0xffffff, alpha: 0.2),
            textSelectionKnobColor: UIColor(rgb: 0xffffff)),
        freeform: PresentationThemeBubbleColor(
            withWallpaper: PresentationThemeBubbleColorComponents(
                fill: [UIColor(rgb: 0xe5e5ea)],
                highlightedFill: UIColor(rgb: 0xdadade),
                stroke: UIColor(rgb: 0xe5e5ea),
                shadow: nil,
                reactionInactiveBackground: defaultDayAccentColor.withMultipliedAlpha(0.1),
                reactionInactiveForeground: defaultDayAccentColor,
                reactionActiveBackground: defaultDayAccentColor,
                reactionActiveForeground: .clear
            ),
            withoutWallpaper: PresentationThemeBubbleColorComponents(
                fill: [UIColor(rgb: 0xe5e5ea)],
                highlightedFill: UIColor(rgb: 0xdadade),
                stroke: UIColor(rgb: 0xe5e5ea),
                shadow: nil,
                reactionInactiveBackground: UIColor(rgb: 0xF1F0F5),
                reactionInactiveForeground: defaultDayAccentColor,
                reactionActiveBackground: defaultDayAccentColor,
                reactionActiveForeground: .clear
            )
        ),
        infoPrimaryTextColor: UIColor(rgb: 0x000000),
        infoLinkTextColor: UIColor(rgb: 0x004bad),
        outgoingCheckColor: UIColor(rgb: 0xffffff),
        mediaDateAndStatusFillColor: UIColor(rgb: 0x000000, alpha: 0.5),
        mediaDateAndStatusTextColor: UIColor(rgb: 0xffffff),
        shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0xffffff, alpha: 0.8)),
        shareButtonStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: UIColor(rgb: 0xe5e5ea)),
        shareButtonForegroundColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xffffff), withoutWallpaper: defaultDayAccentColor),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: UIColor(rgb: 0xffffff)),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: defaultDayAccentColor, strokeColor: UIColor(rgb: 0xc7c7cc), foregroundColor: UIColor(rgb: 0xffffff)),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xff3b30), foregroundColor: UIColor(rgb: 0xffffff)),
        mediaHighlightOverlayColor: UIColor(rgb: 0xffffff, alpha: 0.6),
        stickerPlaceholderColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor.withAlphaComponent(0.3), withoutWallpaper: UIColor(rgb: 0xf7f7f7)),
        stickerPlaceholderShimmerColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xffffff, alpha: 0.2), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.1))
    )
    
    let serviceMessage = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x939fab, alpha: 0.5), primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: UIColor(rgb: 0xffffff), dateFillStatic: UIColor(rgb: 0x000000, alpha: 0.2), dateFillFloating: UIColor(rgb: 0x939fab, alpha: 0.5)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: serviceBackgroundColor, primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: UIColor(rgb: 0xffffff), dateFillStatic: UIColor(rgb: 0x000000, alpha: 0.2), dateFillFloating: serviceBackgroundColor.withAlphaComponent(serviceBackgroundColor.alpha * 0.6667))),
        unreadBarFillColor: UIColor(white: 1.0, alpha: 0.9),
        unreadBarStrokeColor: UIColor(white: 0.0, alpha: 0.2),
        unreadBarTextColor: UIColor(rgb: 0x86868d),
        dateTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff))
    )
    
    let serviceMessageDay = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0xffffff, alpha: 0.8), primaryText: UIColor(rgb: 0x8d8e93), linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: UIColor(rgb: 0xff3b30), dateFillStatic: UIColor(rgb: 0xffffff, alpha: 0.8), dateFillFloating: UIColor(rgb: 0xffffff, alpha: 0.8)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: serviceBackgroundColor, primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: UIColor(rgb: 0xff3b30), dateFillStatic: UIColor(rgb: 0x000000, alpha: 0.2), dateFillFloating: serviceBackgroundColor.withAlphaComponent(serviceBackgroundColor.alpha * 0.6667))),
        unreadBarFillColor: UIColor(rgb: 0xffffff),
        unreadBarStrokeColor: UIColor(rgb: 0xffffff),
        unreadBarTextColor: UIColor(rgb: 0x8d8e93),
        dateTextColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xffffff), withoutWallpaper: UIColor(rgb: 0x8d8e93))
    )
    
    let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
        buttonColor: defaultDayAccentColor,
        micLevelColor: defaultDayAccentColor.withAlphaComponent(0.2),
        activeIconColor: UIColor(rgb: 0xffffff)
    )
    
    let inputPanel = PresentationThemeChatInputPanel(
        panelBackgroundColor: rootNavigationBar.blurredBackgroundColor,
        panelBackgroundColorNoWallpaper: rootNavigationBar.blurredBackgroundColor,
        panelSeparatorColor: UIColor(rgb: 0xb2b2b2),
        panelControlAccentColor: defaultDayAccentColor,
        panelControlColor: UIColor(rgb: 0x858e99),
        panelControlDisabledColor: UIColor(rgb: 0x727b87, alpha: 0.5),
        panelControlDestructiveColor: UIColor(rgb: 0xff3b30),
        inputBackgroundColor: UIColor(rgb: 0xffffff),
        inputStrokeColor: UIColor(rgb: 0x000000, alpha: 0.1),
        inputPlaceholderColor: UIColor(rgb: 0xbebec0),
        inputTextColor: UIColor(rgb: 0x000000),
        inputControlColor: UIColor(rgb: 0xa0a7b0),
        actionControlFillColor: defaultDayAccentColor,
        actionControlForegroundColor: UIColor(rgb: 0xffffff),
        primaryTextColor: UIColor(rgb: 0x000000),
        secondaryTextColor: UIColor(rgb: 0x8e8e93),
        mediaRecordingDotColor: UIColor(rgb: 0xed2521),
        mediaRecordingControl: inputPanelMediaRecordingControl
    )
    
    let inputMediaPanel = PresentationThemeInputMediaPanel(
        panelSeparatorColor: UIColor(rgb: 0xbec2c6),
        panelIconColor: UIColor(rgb: 0x858e99),
        panelHighlightedIconBackgroundColor: UIColor(rgb: 0x858e99, alpha: 0.2),
        stickersBackgroundColor: UIColor(rgb: 0xe8ebf0),
        stickersSectionTextColor: UIColor(rgb: 0x9099a2),
        stickersSearchBackgroundColor: UIColor(rgb: 0xd9dbe1),
        stickersSearchPlaceholderColor: UIColor(rgb: 0x8e8e93),
        stickersSearchPrimaryColor: UIColor(rgb: 0x000000),
        stickersSearchControlColor: UIColor(rgb: 0x8e8e93),
        gifsBackgroundColor: UIColor(rgb: 0xffffff)
    )
    
    let inputButtonPanel = PresentationThemeInputButtonPanel(
        panelSeparatorColor: UIColor(rgb: 0xbec2c6),
        panelBackgroundColor: UIColor(rgb: 0xdee2e6),
        buttonFillColor: UIColor(rgb: 0xffffff),
        buttonStrokeColor: UIColor(rgb: 0xc3c7c9),
        buttonHighlightedFillColor: UIColor(rgb: 0xa8b3c0),
        buttonHighlightedStrokeColor: UIColor(rgb: 0xc3c7c9),
        buttonTextColor: UIColor(rgb: 0x000000)
    )
    
    let historyNavigation = PresentationThemeChatHistoryNavigation(
        fillColor: UIColor(rgb: 0xf7f7f7),
        strokeColor: UIColor(rgb: 0xc8c7cc),
        foregroundColor: UIColor(rgb: 0x88888d),
        badgeBackgroundColor: defaultDayAccentColor,
        badgeStrokeColor: defaultDayAccentColor,
        badgeTextColor: UIColor(rgb: 0xffffff)
    )

    let defaultPatternWallpaper: TelegramWallpaper = defaultBuiltinWallpaper(data: .default, colors: defaultBuiltinWallpaperGradientColors.map(\.rgb))

    let chat = PresentationThemeChat(
        defaultWallpaper: day ? .color(0xffffff) : defaultPatternWallpaper,
        animateMessageColors: false,
        message: day ? messageDay : message,
        serviceMessage: day ? serviceMessageDay : serviceMessage,
        inputPanel: inputPanel,
        inputMediaPanel: inputMediaPanel,
        inputButtonPanel: inputButtonPanel,
        historyNavigation: historyNavigation
    )
    
    let actionSheet = PresentationThemeActionSheet(
        dimColor: UIColor(white: 0.0, alpha: 0.4),
        backgroundType: .light,
        opaqueItemBackgroundColor: UIColor(rgb: 0xffffff),
        itemBackgroundColor: UIColor(white: 1.0, alpha: 0.8),
        opaqueItemHighlightedBackgroundColor: UIColor(white: 0.9, alpha: 1.0),
        itemHighlightedBackgroundColor: UIColor(white: 0.9, alpha: 0.7),
        opaqueItemSeparatorColor: UIColor(white: 0.9, alpha: 1.0),
        standardActionTextColor: defaultDayAccentColor,
        destructiveActionTextColor: UIColor(rgb: 0xff3b30),
        disabledActionTextColor: UIColor(rgb: 0xb3b3b3),
        primaryTextColor: UIColor(rgb: 0x000000),
        secondaryTextColor: UIColor(rgb: 0x8e8e93),
        controlAccentColor: defaultDayAccentColor,
        inputBackgroundColor: UIColor(rgb: 0xe9e9e9),
        inputHollowBackgroundColor: UIColor(rgb: 0xffffff),
        inputBorderColor: UIColor(rgb: 0xe4e4e6),
        inputPlaceholderColor: UIColor(rgb: 0x8e8d92),
        inputTextColor: UIColor(rgb: 0x000000),
        inputClearButtonColor: UIColor(rgb: 0x9e9ea1),
        checkContentColor: UIColor(rgb: 0xffffff)
    )
    
    let contextMenu = PresentationThemeContextMenu(
        dimColor: UIColor(rgb: 0x000a26, alpha: 0.2),
        backgroundColor: UIColor(rgb: 0xf9f9f9, alpha: 0.78),
        itemSeparatorColor: UIColor(rgb: 0x3c3c43, alpha: 0.2),
        sectionSeparatorColor: UIColor(rgb: 0x8a8a8a, alpha: 0.2),
        itemBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.0),
        itemHighlightedBackgroundColor: UIColor(rgb: 0x3c3c43, alpha: 0.2),
        primaryColor: UIColor(rgb: 0x000000),
        secondaryColor: UIColor(rgb: 0x000000, alpha: 0.5),
        destructiveColor: UIColor(rgb: 0xff3b30),
        badgeFillColor: defaultDayAccentColor,
        badgeForegroundColor: UIColor(rgb: 0xffffff),
        badgeInactiveFillColor: UIColor(rgb: 0xb6b6bb),
        badgeInactiveForegroundColor: UIColor(rgb: 0xffffff),
        extractedContentTintColor: .white
    )
    
    let inAppNotification = PresentationThemeInAppNotification(
        fillColor: UIColor(rgb: 0xffffff),
        primaryTextColor: UIColor(rgb: 0x000000),
        expandedNotification: PresentationThemeExpandedNotification(
            backgroundType: .light,
            navigationBar: PresentationThemeExpandedNotificationNavigationBar(
                backgroundColor: UIColor(rgb: 0xffffff),
                primaryTextColor: UIColor(rgb: 0x000000),
                controlColor: UIColor(rgb: 0x7e8791),
                separatorColor: UIColor(rgb: 0xc8c7cc)
            )
        )
    )
    
    let chart = PresentationThemeChart(
        labelsColor: UIColor(rgb: 0x252529, alpha: 0.5),
        helperLinesColor: UIColor(rgb: 0x182d3b, alpha: 0.3),
        strongLinesColor: UIColor(rgb: 0x182d3b, alpha: 0.3),
        barStrongLinesColor: UIColor(rgb: 0x252529, alpha: 0.2),
        detailsTextColor: UIColor(rgb: 0x6d6d72),
        detailsArrowColor: UIColor(rgb: 0xc5c7cd),
        detailsViewColor: UIColor(rgb: 0xf5f5fb),
        rangeViewFrameColor: UIColor(rgb: 0xcad4de),
        rangeViewMarkerColor: UIColor(rgb: 0xffffff)
    )
    
    return PresentationTheme(
        name: extendingThemeReference?.name ?? .builtin(day ? .day : .dayClassic),
        index: extendingThemeReference?.index ?? PresentationThemeReference.builtin(day ? .day : .dayClassic).index,
        referenceTheme: day ? .day : .dayClassic,
        overallDarkAppearance: false,
        intro: intro,
        passcode: passcode,
        rootController: rootController,
        list: list,
        chatList: chatList,
        chat: chat,
        actionSheet: actionSheet,
        contextMenu: contextMenu,
        inAppNotification: inAppNotification,
        chart: chart,
        preview: preview
    )
}

public let defaultBuiltinWallpaperGradientColors: [UIColor] = [
    UIColor(rgb: 0xdbddbb),
    UIColor(rgb: 0x6ba587),
    UIColor(rgb: 0xd5d88d),
    UIColor(rgb: 0x88b884)
]

public struct BuiltinWallpaperData {
    var wallpaperId: Int64
    var wallpaperAccessHash: Int64
    var slug: String
    var fileId: Int64
    var fileAccessHash: Int64
    var datacenterId: Int
    var fileSize: Int
}

public extension BuiltinWallpaperData {
    static let `default` = BuiltinWallpaperData(
        wallpaperId: 5951821522514477057,
        wallpaperAccessHash: 542913527008942388,
        slug: "fqv01SQemVIBAAAApND8LDRUhRU",
        fileId: 5789658100176783156,
        fileAccessHash: 2106033778341319685,
        datacenterId: 4,
        fileSize: 183832
    )
    static let variant1 = BuiltinWallpaperData(
        wallpaperId: 5784984711902265347,
        wallpaperAccessHash: -7073897034484875424,
        slug: "RlZs2PJkSFADAAAAElGaGwgJBgU",
        fileId: 5924571028763183790,
        fileAccessHash: 8131740629580593134,
        datacenterId: 4,
        fileSize: 175995
    )
    static let variant2 = BuiltinWallpaperData(
        wallpaperId: 5785171457080295426,
        wallpaperAccessHash: 7299737721761177260,
        slug: "9LW_RcoOSVACAAAAFTk3DTyXN-M",
        fileId: 5927041584146156278,
        fileAccessHash: -5921024951834087382,
        datacenterId: 4,
        fileSize: 134539
    )
    static let variant3 = BuiltinWallpaperData(
        wallpaperId: 5785191424383254532,
        wallpaperAccessHash: 6428855567842967483,
        slug: "CJNyxPMgSVAEAAAAvW9sMwc51cw",
        fileId: 5785343895722264360,
        fileAccessHash: 3407562549390786397,
        datacenterId: 4,
        fileSize: 312605
    )
    static let variant4 = BuiltinWallpaperData(
        wallpaperId: 5785123761468473345,
        wallpaperAccessHash: -6430405714673464374,
        slug: "BQqgrGnjSFABAAAA8mQDBXQcARE",
        fileId: 5924847998319201207,
        fileAccessHash: 6746675725325490532,
        datacenterId: 4,
        fileSize: 55699
    )
    static let variant5 = BuiltinWallpaperData(
        wallpaperId: 5785021373743104005,
        wallpaperAccessHash: -1374597781576365315,
        slug: "MIo6r0qGSFAFAAAAtL8TsDzNX60",
        fileId: 5782630687571969871,
        fileAccessHash: 8944679612701303524,
        datacenterId: 4,
        fileSize: 100992
    )
    static let variant6 = BuiltinWallpaperData(
        wallpaperId: 5782920928576929793,
        wallpaperAccessHash: -2397741670740938317,
        slug: "9iklpvIPQVABAAAAORQXKur_Eyc",
        fileId: 5924714386181589959,
        fileAccessHash: -316419094644368953,
        datacenterId: 4,
        fileSize: 106249
    )
    static let variant7 = BuiltinWallpaperData(
        wallpaperId: 5931406765567508492,
        wallpaperAccessHash: 7991333610111953175,
        slug: "H6rz6geXUFIMAAAAuUs7m6cXbcc",
        fileId: 5931433527508732666,
        fileAccessHash: -8637914243010610774,
        datacenterId: 4,
        fileSize: 76332
    )
    static let variant8 = BuiltinWallpaperData(
        wallpaperId: 5785007509588672513,
        wallpaperAccessHash: 8437532349638900210,
        slug: "kO4jyq55SFABAAAA0WEpcLfahXk",
        fileId: 5925009274341165314,
        fileAccessHash: 5091210796362176800,
        datacenterId: 4,
        fileSize: 78338
    )
    static let variant9 = BuiltinWallpaperData(
        wallpaperId: 5785068300555780101,
        wallpaperAccessHash: -4335874468273472323,
        slug: "mP3FG_iwSFAFAAAA2AklJO978pA",
        fileId: 5924664689115007842,
        fileAccessHash: -4490072684673383370,
        datacenterId: 4,
        fileSize: 51705
    )
    static let variant10 = BuiltinWallpaperData(
        wallpaperId: 5785165465600917506,
        wallpaperAccessHash: 4563443115749434444,
        slug: "Ujx2TFcJSVACAAAARJ4vLa50MkM",
        fileId: 5924792752154872619,
        fileAccessHash: -2210879717040856036,
        datacenterId: 4,
        fileSize: 114694
    )
    static let variant11 = BuiltinWallpaperData(
        wallpaperId: 5785225431934304257,
        wallpaperAccessHash: 3814946612408881045,
        slug: "RepJ5uE_SVABAAAAr4d0YhgB850",
        fileId: 5927262354055105101,
        fileAccessHash: -435932841948252811,
        datacenterId: 4,
        fileSize: 66465
    )
    static let variant12 = BuiltinWallpaperData(
        wallpaperId: 5785328386595356675,
        wallpaperAccessHash: -5900784223259948847,
        slug: "9GcNVISdSVADAAAAUcw5BYjELW4",
        fileId: 5926924928539429325,
        fileAccessHash: -5306472339097647861,
        datacenterId: 4,
        fileSize: 57262
    )
    static let variant13 = BuiltinWallpaperData(
        wallpaperId: 6041986402319597570,
        wallpaperAccessHash: -8909137552203056986,
        slug: "-Xc-np9y2VMCAAAARKr0yNNPYW0",
        fileId: 5789856918507882132,
        fileAccessHash: 2327344847690632249,
        datacenterId: 4,
        fileSize: 104932
    )
    static let variant14 = BuiltinWallpaperData(
        wallpaperId: 5784981280223395841,
        wallpaperAccessHash: 8334701614156015552,
        slug: "JrNEYdNhSFABAAAA9WtRdJkPRbY",
        fileId: 5924784243824658746,
        fileAccessHash: -2563505106174626287,
        datacenterId: 4,
        fileSize: 122246
    )

    static func generate(account: Account) {
        let slugToName: [(String, String)] = [
            ("fqv01SQemVIBAAAApND8LDRUhRU", "`default`"),
            ("RlZs2PJkSFADAAAAElGaGwgJBgU", "variant1"),
            ("9LW_RcoOSVACAAAAFTk3DTyXN-M", "variant2"),
            ("CJNyxPMgSVAEAAAAvW9sMwc51cw", "variant3"),
            ("BQqgrGnjSFABAAAA8mQDBXQcARE", "variant4"),
            ("MIo6r0qGSFAFAAAAtL8TsDzNX60", "variant5"),
            ("9iklpvIPQVABAAAAORQXKur_Eyc", "variant6"),
            ("H6rz6geXUFIMAAAAuUs7m6cXbcc", "variant7"),
            ("kO4jyq55SFABAAAA0WEpcLfahXk", "variant8"),
            ("mP3FG_iwSFAFAAAA2AklJO978pA", "variant9"),
            ("Ujx2TFcJSVACAAAARJ4vLa50MkM", "variant10"),
            ("RepJ5uE_SVABAAAAr4d0YhgB850", "variant11"),
            ("9GcNVISdSVADAAAAUcw5BYjELW4", "variant12"),
            ("-Xc-np9y2VMCAAAARKr0yNNPYW0", "variant13"),
            ("JrNEYdNhSFABAAAA9WtRdJkPRbY", "variant14"),
        ]

        var signals: [Signal<String?, GetWallpaperError>] = []
        for (slug, name) in slugToName {
            signals.append(getWallpaper(network: account.network, slug: slug)
            |> map { wallpaper -> String? in
                switch wallpaper {
                case let .file(file):
                    guard let resource = file.file.resource as? CloudDocumentMediaResource else {
                        return nil
                    }
                    guard let size = file.file.size else {
                        return nil
                    }
                    return """
static let \(name) = BuiltinWallpaperData(
    wallpaperId: \(file.id),
    wallpaperAccessHash: \(file.accessHash),
    slug: "\(slug)",
    fileId: \(file.file.fileId.id),
    fileAccessHash: \(resource.accessHash),
    datacenterId: \(resource.datacenterId),
    fileSize: \(size)
)
"""
                default:
                    return nil
                }
            })
        }

        let _ = (combineLatest(signals)
        |> map { strings -> String in
            var result = ""
            for case let string? in strings {
                if !result.isEmpty {
                    result.append("\n")
                }
                result.append(string)
            }
            return result
        }
        |> deliverOnMainQueue).start(next: { result in
            print("\(result)")
        })
    }
}

public func defaultBuiltinWallpaper(data: BuiltinWallpaperData, colors: [UInt32], intensity: Int32 = 50, rotation: Int32? = nil) -> TelegramWallpaper {
    return .file(TelegramWallpaper.File(
        id: data.wallpaperId,
        accessHash: data.wallpaperAccessHash,
        isCreator: false,
        isDefault: false,
        isPattern: true,
        isDark: false,
        slug: data.slug,
        file: TelegramMediaFile(
            fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: data.fileId),
            partialReference: nil,
            resource: CloudDocumentMediaResource(
                datacenterId: data.datacenterId,
                fileId: data.fileId,
                accessHash: data.fileAccessHash,
                size: Int64(data.fileSize),
                fileReference: Data(),
                fileName: "pattern.tgv"
            ),
            previewRepresentations: [
                TelegramMediaImageRepresentation(
                    dimensions: PixelDimensions(width: 155, height: 320),
                    resource: CloudDocumentSizeMediaResource(
                        datacenterId: 1,
                        documentId: data.fileId,
                        accessHash: data.fileAccessHash,
                        sizeSpec: "m",
                        fileReference: Data()
                    ),
                    progressiveSizes: [],
                    immediateThumbnailData: nil
                )
            ],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "application/x-tgwallpattern",
            size: Int64(data.fileSize),
            attributes: [
                .ImageSize(size: PixelDimensions(width: 1440, height: 2960)),
                .FileName(fileName: "pattern.tgv")
            ]
        ),
        settings: WallpaperSettings(colors: colors, intensity: intensity, rotation: rotation)
    ))
}
