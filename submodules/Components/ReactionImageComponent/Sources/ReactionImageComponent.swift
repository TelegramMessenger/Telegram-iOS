import Foundation
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import UIKit
import WebPBinding

public final class ReactionImageNode: ASImageNode {
    private var disposable: Disposable?
    public let size: CGSize
    
    public init(context: AccountContext, availableReactions: AvailableReactions?, reaction: String) {
        var file: TelegramMediaFile?
        if let availableReactions = availableReactions {
            for availableReaction in availableReactions.reactions {
                if availableReaction.value == reaction {
                    file = availableReaction.staticIcon
                    break
                }
            }
        }
        if let file = file {
            self.size = file.dimensions?.cgSize ?? CGSize(width: 18.0, height: 18.0)
            
            super.init()
            
            self.disposable = (context.account.postbox.mediaBox.resourceData(file.resource)
            |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let strongSelf = self else {
                    return
                }
                
                if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                    if let image = WebP.convert(fromWebP: dataValue) {
                        strongSelf.image = image
                    }
                }
            })
        } else {
            self.size = CGSize(width: 18.0, height: 18.0)
            super.init()
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

public final class ReactionFileImageNode: ASImageNode {
    private let disposable = MetaDisposable()

    private var currentFile: TelegramMediaFile?
    
    override public init() {
    }
    
    deinit {
        self.disposable.dispose()
    }

    public func asyncLayout() -> (_ context: AccountContext, _ file: TelegramMediaFile?) -> (size: CGSize, apply: () -> Void) {
        return { [weak self] context, file in
            let size = file?.dimensions?.cgSize ?? CGSize(width: 18.0, height: 18.0)
            
            return (size, {
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.currentFile != file {
                    strongSelf.currentFile = file
                    
                    if let file = file {
                        strongSelf.disposable.set((context.account.postbox.mediaBox.resourceData(file.resource)
                        |> deliverOnMainQueue).start(next: { data in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if data.complete, let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                if let image = WebP.convert(fromWebP: dataValue) {
                                    strongSelf.image = image
                                }
                            }
                        }))
                    }
                }
            })
        }
    }
}
