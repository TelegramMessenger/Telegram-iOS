import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import ContextUI
import PeerInfoVisualMediaPaneNode

extension PeerInfoScreenNode {
    func displayGiftsContextMenu(source: ContextReferenceContentNode, gesture: ContextGesture?) {
        guard let currentPaneKey = self.paneContainerNode.currentPaneKey, case .gifts = currentPaneKey else {
            return
        }
        guard let pane = self.paneContainerNode.currentPane?.node as? PeerInfoGiftsPaneNode else {
            return
        }
        guard let controller = self.controller else {
            return
        }
        guard let data = self.data else {
            return
        }
        
        let giftsContext = pane.giftsContext
        
        var hasVisibility = false
        if let channel = data.peer as? TelegramChannel, channel.hasPermission(.sendSomething) {
            hasVisibility = true
        } else if data.peer?.id == self.context.account.peerId {
            hasVisibility = true
        }
        
        let isCollection = giftsContext.collectionId != nil
            
        let strings = self.presentationData.strings
        let items: Signal<ContextController.Items, NoError> = giftsContext.state
        |> map { state in
            var hasPinnedGifts = false
            for gift in state.gifts {
                if gift.pinnedToTop {
                    hasPinnedGifts = true
                    break
                }
            }
            return (state.filter, state.sorting, hasPinnedGifts || isCollection)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
            let filterEquals = lhs.0 == rhs.0
            let sortingEquals = lhs.1 == rhs.1
            let canReorderEquals = lhs.2 == rhs.2
            return filterEquals && sortingEquals && canReorderEquals
        })
        |> map { [weak pane, weak giftsContext] filter, sorting, canReorder -> ContextController.Items in
            var items: [ContextMenuItem] = []
                        
            if hasVisibility {
                if let pane, case .all = pane.currentCollection {
                    items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_AddCollection, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/Gifts/AddCollection"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, f in
                        f(.default)
                        
                        if let pane {
                            pane.createCollection()
                        }
                    })))
                } else {
                    items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_AddGifts, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/Gifts/AddGift"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, f in
                        f(.default)
                        
                        if let pane, case let .collection(id) = pane.currentCollection {
                            pane.addGiftsToCollection(id: id)
                        }
                    })))
                }

                if canReorder {
                    items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Reorder, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, f in
                        f(.default)
                        
                        if let pane {
                            pane.beginReordering()
                        }
                    })))
                }
                
                if let pane, case let .collection(id) = pane.currentCollection {
                    items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_DeleteCollection, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak pane] _, f in
                        f(.default)
                        
                        if let pane {
                            pane.deleteCollection(id: id)
                        }
                    })))
                }
            }
            
            if let pane, case let .collection(id) = pane.currentCollection, let addressName = data.peer?.addressName, !addressName.isEmpty {
                let shareAction: ContextMenuItem = .action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_ShareCollection, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    self?.openShareLink(url: "https://t.me/\(addressName)/c/\(id)")
                }))
                if items.isEmpty {
                    items.append(shareAction)
                } else {
                    items.insert(shareAction, at: 1)
                }
            }
            
            if !items.isEmpty {
                items.append(.separator)
            }
            
            if let pane, case .all = pane.currentCollection {
                items.append(.action(ContextMenuActionItem(text: sorting == .date ? strings.PeerInfo_Gifts_SortByValue : strings.PeerInfo_Gifts_SortByDate, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: sorting == .date ? "Peer Info/SortValue" : "Peer Info/SortDate"), color: theme.contextMenu.primaryColor)
                }, action: { [weak giftsContext] _, f in
                    f(.default)
                    
                    giftsContext?.updateSorting(sorting == .date ? .value : .date)
                })))
            
                items.append(.separator)
            }
            
            let toggleFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                if updatedFilter.contains(value) {
                    updatedFilter.remove(value)
                } else {
                    updatedFilter.insert(value)
                }
                if !updatedFilter.contains(.unlimited) && !updatedFilter.contains(.limitedUpgradable) && !updatedFilter.contains(.limitedNonUpgradable) && !updatedFilter.contains(.unique) {
                    updatedFilter.insert(.unlimited)
                }
                if !updatedFilter.contains(.displayed) && !updatedFilter.contains(.hidden) {
                    if value == .displayed {
                        updatedFilter.insert(.hidden)
                    } else {
                        updatedFilter.insert(.displayed)
                    }
                }
                giftsContext?.updateFilter(updatedFilter)
            }
            
            let switchToFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                updatedFilter.remove(.unlimited)
                updatedFilter.remove(.limitedUpgradable)
                updatedFilter.remove(.limitedNonUpgradable)
                updatedFilter.remove(.unique)
                updatedFilter.insert(value)
                giftsContext?.updateFilter(updatedFilter)
            }
            
            let switchToVisiblityFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                updatedFilter.remove(.hidden)
                updatedFilter.remove(.displayed)
                updatedFilter.insert(value)
                giftsContext?.updateFilter(updatedFilter)
            }
            
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Unlimited, icon: { theme in
                return filter.contains(.unlimited) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, f in
                toggleFilter(.unlimited)
            }, longPressAction: { _, f in
                switchToFilter(.unlimited)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Limited, icon: { theme in
                return filter.contains(.limitedNonUpgradable) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, f in
                toggleFilter(.limitedNonUpgradable)
            }, longPressAction: { _, f in
                switchToFilter(.limitedNonUpgradable)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Upgradable, icon: { theme in
                return filter.contains(.limitedUpgradable) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, f in
                toggleFilter(.limitedUpgradable)
            }, longPressAction: { _, f in
                switchToFilter(.limitedUpgradable)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Unique, icon: { theme in
                return filter.contains(.unique) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, f in
                toggleFilter(.unique)
            }, longPressAction: { _, f in
                switchToFilter(.unique)
            })))
            
            if hasVisibility {
                items.append(.separator)
                
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Displayed, icon: { theme in
                    return filter.contains(.displayed) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
                }, action: { _, f in
                    toggleFilter(.displayed)
                }, longPressAction: { _, f in
                    switchToVisiblityFilter(.displayed)
                })))
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Hidden, icon: { theme in
                    return filter.contains(.hidden) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
                }, action: { _, f in
                    toggleFilter(.hidden)
                }, longPressAction: { _, f in
                    switchToVisiblityFilter(.hidden)
                })))
            }
            
            return ContextController.Items(content: .list(items))
        }
        
        var sourceView: UIView = source.view
        if sourceView.isDescendant(of: self.headerNode.navigationButtonContainer.rightButtonsBackground) {
            sourceView = self.headerNode.navigationButtonContainer.rightButtonsBackground
        } else if sourceView.isDescendant(of: self.headerNode.navigationButtonContainer.leftButtonsBackground) {
            sourceView = self.headerNode.navigationButtonContainer.leftButtonsBackground
        }
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: items, gesture: gesture)
        contextController.passthroughTouchEvent = { [weak self] sourceView, point in
            guard let strongSelf = self else {
                return .ignore
            }
            
            let localPoint = strongSelf.view.convert(sourceView.convert(point, to: nil), from: nil)
            guard let localResult = strongSelf.hitTest(localPoint, with: nil) else {
                return .dismiss(consume: true, result: nil)
            }
            
            var testView: UIView? = localResult
            while true {
                if let testViewValue = testView {
                    if let node = testViewValue.asyncdisplaykit_node as? PeerInfoHeaderNavigationButton {
                        node.isUserInteractionEnabled = false
                        DispatchQueue.main.async {
                            node.isUserInteractionEnabled = true
                        }
                        return .dismiss(consume: false, result: nil)
                    } else {
                        testView = testViewValue.superview
                    }
                } else {
                    break
                }
            }
            
            return .dismiss(consume: true, result: nil)
        }
        self.mediaGalleryContextMenu = contextController
        controller.presentInGlobalOverlay(contextController)
    }
}
