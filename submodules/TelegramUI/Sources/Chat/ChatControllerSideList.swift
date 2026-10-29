import Foundation
import UIKit
import Display
import AccountContext
import ChatPresentationInterfaceState

extension ChatControllerImpl {
    func currentSideListKind(presentationInterfaceState: ChatPresentationInterfaceState) -> ChatSideListKind? {
        let isRegularWidth = self.validLayout?.metrics.widthClass == .regular
        return chatSideListKindForChatPresentationInterfaceState(presentationInterfaceState, context: self.context, isRegularWidth: isRegularWidth)
    }

    func toggleSideList() {
    }
}
