import SwiftSignalKit
import TelegramPresentationData

private func themeWithDefaultAccent(_ theme: PresentationTheme) -> PresentationTheme {
    let defaultTheme: PresentationTheme
    switch theme.referenceTheme {
    case .day, .dayClassic:
        defaultTheme = defaultPresentationTheme
    case .night:
        defaultTheme = defaultDarkColorPresentationTheme
    case .nightAccent:
        return defaultDarkTintedPresentationTheme
    }

    let updatedTheme = customizePresentationTheme(
        theme,
        editing: false,
        accentColor: defaultTheme.list.itemAccentColor,
        outgoingAccentColor: nil,
        backgroundColors: [],
        bubbleColors: [],
        animateBubbleColors: theme.chat.animateMessageColors,
        wallpaper: theme.chat.defaultWallpaper
    )
    updatedTheme.forceSync = theme.forceSync
    updatedTheme.starGift = theme.starGift
    return updatedTheme
}

public func presentationDataWithDefaultAccent(
    _ presentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
) -> (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
    let initialTheme = themeWithDefaultAccent(presentationData.initial.theme)
    let cachedTheme = Atomic(value: (source: presentationData.initial.theme, resolved: initialTheme))

    return (
        initial: presentationData.initial.withUpdated(theme: initialTheme),
        signal: presentationData.signal |> map { presentationData in
            let theme = cachedTheme.modify { current in
                if current.source === presentationData.theme {
                    return current
                }
                return (source: presentationData.theme, resolved: themeWithDefaultAccent(presentationData.theme))
            }.resolved
            return presentationData.withUpdated(theme: theme)
        }
    )
}
