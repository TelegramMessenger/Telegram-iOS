import Foundation
import UIKit
import Display
import TelegramCore
import AccountContext
import TelegramPresentationData
import ComponentFlow
import InstantPageUI
import TelegramUIPreferences
import ChatSendMessageActionUI

final class ChatSendMessageRichTextPreview: ChatSendMessageContextScreenRichTextPreview {
    private let context: AccountContext
    private let instantPage: InstantPage
    private let webpage: TelegramMediaWebpage
    private let pageView: InstantPageV2View

    private var cachedBoundingWidth: CGFloat?
    private var cachedThemeIdentity: ObjectIdentifier?
    private var cachedFontSize: PresentationFontSize?
    private var cachedContentSize: CGSize = .zero

    var view: UIView {
        return self.pageView
    }

    init(context: AccountContext, instantPage: InstantPage) {
        self.context = context
        self.instantPage = instantPage

        let webpage = TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(
            url: "",
            displayUrl: "",
            hash: 0,
            type: nil,
            websiteName: nil,
            title: nil,
            text: nil,
            embedUrl: nil,
            embedType: nil,
            embedSize: nil,
            duration: nil,
            author: nil,
            isMediaLargeByDefault: nil,
            imageIsVideoCover: false,
            image: nil,
            file: nil,
            story: nil,
            attributes: [],
            instantPage: instantPage
        )))
        self.webpage = webpage

        let renderContext = InstantPageV2RenderContext(
            context: context,
            webpage: webpage,
            sourceLocation: InstantPageSourceLocation(userLocation: .other, peerType: .channel),
            imageReference: { image in
                return ImageMediaReference.standalone(media: image)
            },
            fileReference: { file in
                return FileMediaReference.standalone(media: file)
            },
            present: { _, _ in },
            push: { _ in },
            openUrl: { _ in },
            baseNavigationController: { return nil },
            message: nil
        )
        self.pageView = InstantPageV2View(renderContext: renderContext)
        self.pageView.isUserInteractionEnabled = false
    }

    func update(boundingWidth: CGFloat, presentationData: PresentationData, transition: ComponentTransition) -> CGSize {
        let themeIdentity = ObjectIdentifier(presentationData.theme)
        if self.cachedBoundingWidth == boundingWidth, self.cachedThemeIdentity == themeIdentity, self.cachedFontSize == presentationData.chatFontSize {
            return self.cachedContentSize
        }

        // Combined with MessageItemView's 1pt left border this yields a 10pt left text inset.
        let pageHorizontalInset: CGFloat = 9.0
        let isDark = presentationData.theme.overallDarkAppearance
        let messageTheme = presentationData.theme.chat.message.outgoing
        let mainColor = messageTheme.accentTextColor

        if isDark {
        } else {
        }

        let textCategories = InstantPageTextCategories.chatMessage(
            primaryText: messageTheme.primaryTextColor,
            secondaryText: messageTheme.secondaryTextColor
        )
        let pageTheme = InstantPageTheme(
            type: isDark ? .dark : .light,
            pageBackgroundColor: .clear,
            textCategories: textCategories,
            serif: false,
            // Matches the bubble this previews: the highlighted-table-cell fill, not an accent tint.
            codeBlockBackgroundColor: messageTheme.accentControlColor.withMultipliedAlpha(0.1),
            linkColor: messageTheme.linkTextColor,
            textHighlightColor: messageTheme.accentTextColor.withMultipliedAlpha(0.1),
            linkHighlightColor: messageTheme.linkTextColor.withMultipliedAlpha(0.1),
            markerColor: UIColor(rgb: 0xfef3bc),
            panelBackgroundColor: messageTheme.accentControlColor.withMultipliedAlpha(0.1),
            panelHighlightedBackgroundColor: messageTheme.accentControlColor.withMultipliedAlpha(0.25),
            panelPrimaryColor: messageTheme.primaryTextColor,
            panelSecondaryColor: messageTheme.secondaryTextColor,
            panelAccentColor: messageTheme.accentTextColor,
            // Preview is always outgoing, so these match the reference bubble's
            // `isDark || !isIncoming` (always-true) branch.
            tableBorderColor: messageTheme.accentControlColor.withMultipliedAlpha(0.25),
            tableHeaderColor: messageTheme.accentControlColor.withMultipliedAlpha(0.1),
            controlColor: messageTheme.accentControlColor,
            imageTintColor: nil,
            overlayPanelColor: messageTheme.accentControlColor.withMultipliedAlpha(0.25),
            separatorColor: messageTheme.accentControlColor.withMultipliedAlpha(0.25),
            secondaryControlColor: messageTheme.secondaryTextColor,
            quoteAccentColor: mainColor
        )

        let layout = layoutInstantPageV2(
            webpage: self.webpage,
            instantPage: self.instantPage,
            userLocation: .other,
            boundingWidth: boundingWidth,
            horizontalInset: pageHorizontalInset,
            theme: pageTheme,
            strings: presentationData.strings,
            dateTimeFormat: presentationData.dateTimeFormat,
            cachedMessageSyntaxHighlight: nil,
            expandedDetails: [:],
            fitToWidth: true,
            // The bubble this previews follows Text Size, so the preview must too or it stops being one.
            contentScale: instantPageChatMessageContentScale(baseFontSize: presentationData.chatFontSize.baseDisplaySize)
        )
        self.pageView.update(layout: layout, theme: pageTheme, animation: .None)
        // The parent (MessageItemView) owns and sets `pageView`'s frame; `update` only
        // rebuilds content and reports the size. Rendering is static (.None) — the screen
        // drives the size/crossfade transition.

        self.cachedBoundingWidth = boundingWidth
        self.cachedThemeIdentity = themeIdentity
        self.cachedFontSize = presentationData.chatFontSize
        self.cachedContentSize = layout.contentSize
        return layout.contentSize
    }
}
