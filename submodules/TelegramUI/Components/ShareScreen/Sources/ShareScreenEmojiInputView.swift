import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramPresentationData
import ChatPresentationInterfaceState
import ChatEntityKeyboardInputNode
import SwiftSignalKit

// A real inputView keeps UIKit's keyboard geometry and interactive dismissal in sync with the sheet.
final class ShareScreenEmojiInputView: UIInputView {
    private let context: AccountContext
    private let metrics: LayoutMetrics
    private let deviceMetrics: DeviceMetrics
    private let data = Promise<ChatEntityKeyboardInputNode.InputData>()
    private let disposable = MetaDisposable()
    private let stateContext = ChatEntityKeyboardInputNode.StateContext()
    private var node: ChatEntityKeyboardInputNode?

    init(context: AccountContext, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, insertText: @escaping (NSAttributedString) -> Void, deleteBackward: @escaping () -> Void, switchToText: @escaping () -> Void) {
        self.context = context
        self.metrics = metrics
        self.deviceMetrics = deviceMetrics
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: deviceMetrics.standardInputHeight(inLandscape: false)), inputViewStyle: .keyboard)
        self.data.set(ChatEntityKeyboardInputNode.inputData(context: context, chatPeerId: nil, areCustomEmojiEnabled: true, hasTrending: false, hasSearch: false, hasStickers: false, hasGifs: false, hideBackground: false, maskEdge: .none, sendGif: nil))
        let interaction = ChatEntityKeyboardInputNode.Interaction(
            sendSticker: { _, _, _, _, _, _, _, _, _ in false }, sendEmoji: { _, _, _ in }, sendGif: { _, _, _, _, _ in false }, sendBotContextResultAsGif: { _, _, _, _, _, _ in false }, editGif: { _, _ in }, updateChoosingSticker: { _ in },
            switchToTextInput: switchToText, dismissTextInput: switchToText, insertText: insertText, backwardsDeleteText: deleteBackward,
            openStickerEditor: {}, presentController: { _, _ in }, presentGlobalOverlayController: { _, _ in }, getNavigationController: { nil }, requestLayout: { _ in }
        )
        self.disposable.set((self.data.get() |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self, self.node == nil else { return }
            let node = ChatEntityKeyboardInputNode(context: context, currentInputData: data, updatedInputData: self.data.get(), defaultToEmojiTab: true, opaqueTopPanelBackground: false, useOpaqueTheme: false, interaction: interaction, chatPeerId: nil, stateContext: self.stateContext)
            node.externalTopPanelContainerImpl = nil
            node.clipsToBounds = true
            self.node = node
            self.addSubview(node.view)
            self.setNeedsLayout()
        }))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { self.disposable.dispose() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let node = self.node, self.bounds.width > 0.0 else { return }
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        let interfaceState = ChatPresentationInterfaceState(chatWallpaper: .builtin(WallpaperSettings()), theme: data.theme, preferredGlassType: .default, strings: data.strings, dateTimeFormat: data.dateTimeFormat, nameDisplayOrder: data.nameDisplayOrder, limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 }, fontSize: data.chatFontSize, bubbleCorners: data.chatBubbleCorners, accountPeerId: self.context.account.peerId, mode: .standard(.default), chatLocation: .peer(id: self.context.account.peerId), subject: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, threadData: nil, isGeneralThreadClosed: nil, replyMessage: nil, accountPeerColor: nil, businessIntro: nil)
        let _ = node.updateLayout(width: self.bounds.width, leftInset: 0.0, rightInset: 0.0, bottomInset: self.safeAreaInsets.bottom, standardInputHeight: self.bounds.height, inputHeight: 0.0, maximumHeight: self.bounds.height, inputPanelHeight: 0.0, transition: .immediate, interfaceState: interfaceState, layoutMetrics: self.metrics, deviceMetrics: self.deviceMetrics, isVisible: true, isExpanded: false)
        node.frame = self.bounds
    }
}
