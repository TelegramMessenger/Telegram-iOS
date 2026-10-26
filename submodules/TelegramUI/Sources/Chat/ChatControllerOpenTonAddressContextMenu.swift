import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import Display
import ContextUI
import AccountContext
import AvatarNode
import UndoUI
import ChatControllerInteraction
import WalletContext

extension ChatControllerImpl {
    func openTonAddressContextMenu(address: String, params: ChatControllerInteraction.LongTapParams) {
        guard let message = params.message, let contentNode = params.contentNode,
              let normalizedAddress = WalletContext.transferAddress(from: address) else {
            params.progress?.set(.single(false))
            params.contentNode?.removeFromSupernode()
            return
        }

        let context = self.context
        let source: ContextContentSource = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))
        var menuPresented = false
        params.progress?.set(.single(true))

        let recipient = context.engine.wallet.getUserAddresses(addresses: [address])
        |> `catch` { _ -> Signal<[WalletUserAddress], NoError> in
            return .single([])
        }
        |> mapToSignal { addresses -> Signal<WalletSendRequest.Recipient, NoError> in
            guard let userAddress = addresses.first(where: { WalletContext.transferAddress(from: $0.address) == normalizedAddress }),
                  let userId = userAddress.userId else {
                return .single(.address(address))
            }
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: userId))
            |> map { peer -> WalletSendRequest.Recipient in
                guard let peer, case .user = peer else {
                    return .address(address)
                }
                return .peer(peer, resolvedAddress: WalletUserAddress(userId: peer.id, address: address, publicKey: userAddress.publicKey))
            }
        }

        self.navigationActionDisposable.set((recipient
        |> take(1)
        |> deliverOnMainQueue
        |> afterDisposed {
            Queue.mainQueue().async {
                params.progress?.set(.single(false))
                if !menuPresented {
                    contentNode.removeFromSupernode()
                }
            }
        }).startStrict(next: { [weak self] recipient in
            params.progress?.set(.single(false))
            guard let self, let window = self.window else {
                return
            }

            var items: [ContextMenuItem] = []
            if WalletConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 }).isAvailable {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Wallet_SendMoney, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Ton"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, dismiss in
                    dismiss(.default)
                    self?.openResolved(result: .sendGrams(transfer: WalletSendRequest(recipient: recipient, amountNanograms: nil)), sourceMessageId: message.id)
                })))
            }
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Wallet_CopyAddress, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, dismiss in
                dismiss(.default)
                guard let self else {
                    return
                }
                UIPasteboard.general.string = address
                self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.Wallet_AddressCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })))
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Wallet_ViewInExplorer, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Search"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, dismiss in
                dismiss(.default)
                guard let self,
                      let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) else {
                    return
                }
                let configuration = WalletConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                let baseUrl = configuration.explorerUrl.hasSuffix("/") ? configuration.explorerUrl : configuration.explorerUrl + "/"
                self.openUrl(baseUrl + encodedAddress, concealed: false)
            })))

            if case let .peer(peer, _) = recipient {
                items.append(.separator)
                let avatarSize = CGSize(width: 28.0, height: 28.0)
                let avatarSignal = peerAvatarCompleteImage(account: self.context.account, peer: peer, size: avatarSize)
                let subtitle = NSMutableAttributedString(string: self.presentationData.strings.Wallet_ViewProfile)
                if let range = subtitle.string.range(of: ">"), let arrowImage = UIImage(bundleImageName: "Item List/InlineTextRightArrow") {
                    subtitle.addAttribute(.attachment, value: arrowImage, range: NSRange(range, in: subtitle.string))
                    subtitle.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: subtitle.string))
                }
                items.append(.action(ContextMenuActionItem(text: peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), textLayout: .secondLineWithAttributedValue(subtitle), icon: { _ in return nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: avatarSignal), iconPosition: .left, action: { [weak self] _, dismiss in
                    dismiss(.default)
                    self?.openPeer(peer: peer, navigation: .info(ChatControllerInteractionNavigateToPeer.InfoParams(ignoreInSavedMessages: true)), fromMessage: nil)
                })))
            }

            let controller = makeContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: params.gesture, gesture: nil, disableScreenshots: false)
            controller.dismissed = { [weak self] in
                self?.canReadHistory.set(true)
            }
            menuPresented = true
            self.canReadHistory.set(false)
            window.presentInGlobalOverlay(controller)
        }))
    }
}
