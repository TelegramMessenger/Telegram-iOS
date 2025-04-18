import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

final class ListMessageHoleItem: ListViewItem {
    public init() {
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = ListMessageHoleItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom, dateAtBottom) = (false, false, false)
            let (layout, apply) = nodeLayout(self, params, top, bottom, dateAtBottom)
            
            node.updateSelectionState(animated: false)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ListMessageHoleItemNode {
                nodeValue.updateSelectionState(animated: false)
                
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom, dateAtBottom) = (false, false, false)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom, dateAtBottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

final class ListMessageHoleItemNode: ListViewItemNode {
    private var activityIndicator: UIActivityIndicatorView?
    
    init() {
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        self.activityIndicator = activityIndicator
        self.view.addSubview(activityIndicator)
        let size = activityIndicator.bounds.size
        activityIndicator.frame = CGRect(origin: CGPoint(x: floor((self.bounds.size.width - size.width) / 2.0), y: floor((self.bounds.size.height - size.height) / 2.0)), size: size)
        activityIndicator.startAnimating()
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ListMessageHoleItem {
            let doLayout = self.asyncLayout()
            let merged = (top: false, bottom: false, dateAtBottom: false)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom, merged.dateAtBottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: ListMessageHoleItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { [weak self] _, params, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 50.0), insets: UIEdgeInsets()), { _ in
                if let strongSelf = self, let activityIndicator = strongSelf.activityIndicator {
                    let boundsSize = CGSize(width: params.width, height: 50.0)
                    let size = activityIndicator.bounds.size
                    activityIndicator.frame = CGRect(origin: CGPoint(x: floor((boundsSize.width - size.width) / 2.0), y: floor((boundsSize.height - size.height) / 2.0)), size: size)
                }
            })
        }
    }
    
    func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
    
    func updateSelectionState(animated: Bool) {
    }
}
