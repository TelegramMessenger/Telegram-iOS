import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputTrendingPane: ASDisplayNode {
    private let account: Account
    
    private let listNode: ListView
    
    init(account: Account) {
        self.account = account
        
        self.listNode = ListView()
        
        super.init()
        
        self.addSubnode(self.listNode)
    }
}
