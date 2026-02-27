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
    func displayMediaGalleryContextMenu(source: ContextReferenceContentNode, gesture: ContextGesture?) {
        let peerId = self.peerId
        
        var isBotPreviewOrStories = false
        if let currentPaneKey = self.paneContainerNode.currentPaneKey {
            if case .botPreview = currentPaneKey {
                isBotPreviewOrStories = true
            } else if case .stories = currentPaneKey {
                isBotPreviewOrStories = true
            }
        }
        
        if isBotPreviewOrStories {
            guard let controller = self.controller else {
                return
            }
            guard let pane = self.paneContainerNode.currentPane?.node as? PeerInfoStoryPaneNode else {
                return
            }
            
            if case .botPreview = pane.scope {
                guard let data = self.data, let user = data.peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                
                let strings = self.presentationData.strings
                
                var ignoreNextActions = false
                
                if pane.canAddMoreBotPreviews() {
                    items.append(.action(ContextMenuActionItem(text: strings.BotPreviews_MenuAddPreview, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        if let self {
                            self.headerNode.navigationButtonContainer.performAction?(.postStory, nil, nil)
                        }
                    })))
                }
                
                if pane.canReorder() {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.BotPreviews_MenuReorder, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        if let pane {
                            pane.beginReordering()
                        }
                    })))
                }
                
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuSelect, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    if ignoreNextActions {
                        return
                    }
                    ignoreNextActions = true
                    a(.default)
                    
                    if let self {
                        self.toggleStorySelection(ids: [], isSelected: true)
                    }
                })))
                
                if let language = pane.currentBotPreviewLanguage {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.BotPreviews_MenuDeleteLanguage(language.name).string, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak pane] _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        if let pane {
                            pane.presentDeleteBotPreviewLanguage()
                        }
                    })))
                }
                
                let contextController = makeContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: source)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoVisualMediaPaneNode {
                                node.brieflyDisableTouchActions()
                                return .dismiss(consume: false, result: nil)
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoStoryPaneNode {
                                node.brieflyDisableTouchActions()
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
            } else if case .peer = pane.scope {
                guard let data = self.data, let user = data.peer as? TelegramUser else {
                    return
                }
                let _ = user
                
                var items: [ContextMenuItem] = []
                
                let strings = self.presentationData.strings
                
                var ignoreNextActions = false
                
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_MenuAddStories, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat List/AddStoryIcon"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    if ignoreNextActions {
                        return
                    }
                    ignoreNextActions = true
                    a(.default)
                    
                    if let self {
                        self.headerNode.navigationButtonContainer.performAction?(.postStory, nil, nil)
                    }
                })))
                
                if let _ = pane.currentStoryFolder {
                    items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuShare, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        if let pane {
                            pane.shareCurrentFolder()
                        }
                    })))
                }
                
                if pane.canReorder() {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.BotPreviews_MenuReorder, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        if let pane {
                            pane.beginReordering()
                        }
                    })))
                }
                
                if let folder = pane.currentStoryFolder {
                    let _ = folder
                    
                    items.append(.action(ContextMenuActionItem(text: strings.Stories_MenuDeleteAlbum, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak pane] _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        if let pane {
                            pane.presentDeleteCurrentStoryFolder()
                        }
                    })))
                }
                
                if let language = pane.currentBotPreviewLanguage {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.BotPreviews_MenuDeleteLanguage(language.name).string, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak pane] _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        if let pane {
                            pane.presentDeleteBotPreviewLanguage()
                        }
                    })))
                }
                
                let contextController = makeContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: source)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoVisualMediaPaneNode {
                                node.brieflyDisableTouchActions()
                                return .dismiss(consume: false, result: nil)
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoStoryPaneNode {
                                node.brieflyDisableTouchActions()
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
        } else {
            let _ = (self.context.engine.data.get(EngineDataMap([
                TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, threadId: self.chatLocation.threadId, tag: .photo),
                TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, threadId: self.chatLocation.threadId, tag: .video)
            ]))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] messageCounts in
                guard let strongSelf = self else {
                    return
                }
                
                var mediaCount: [MessageTags: Int32] = [:]
                for (key, count) in messageCounts {
                    mediaCount[key.tag] = count.flatMap(Int32.init) ?? 0
                }
                
                let photoCount: Int32 = mediaCount[.photo] ?? 0
                let videoCount: Int32 = mediaCount[.video] ?? 0
                
                guard let controller = strongSelf.controller else {
                    return
                }
                guard let pane = strongSelf.paneContainerNode.currentPane?.node as? PeerInfoVisualMediaPaneNode else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                
                let strings = strongSelf.presentationData.strings
                
                var recurseGenerateAction: ((Bool) -> ContextMenuActionItem)?
                let generateAction: (Bool) -> ContextMenuActionItem = { [weak pane] isZoomIn in
                    let nextZoomLevel = isZoomIn ? pane?.availableZoomLevels().increment : pane?.availableZoomLevels().decrement
                    let canZoom: Bool = nextZoomLevel != nil
                    
                    return ContextMenuActionItem(id: isZoomIn ? 0 : 1, text: isZoomIn ? strings.SharedMedia_ZoomIn : strings.SharedMedia_ZoomOut, textColor: canZoom ? .primary : .disabled, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: isZoomIn ? "Chat/Context Menu/ZoomIn" : "Chat/Context Menu/ZoomOut"), color: canZoom ? theme.contextMenu.primaryColor : theme.contextMenu.primaryColor.withMultipliedAlpha(0.4))
                    }, action: canZoom ? { action in
                        guard let pane = pane, let zoomLevel = isZoomIn ? pane.availableZoomLevels().increment : pane.availableZoomLevels().decrement else {
                            return
                        }
                        pane.updateZoomLevel(level: zoomLevel)
                        if let recurseGenerateAction = recurseGenerateAction {
                            action.updateAction(0, recurseGenerateAction(true))
                            action.updateAction(1, recurseGenerateAction(false))
                        }
                    } : nil)
                }
                recurseGenerateAction = { isZoomIn in
                    return generateAction(isZoomIn)
                }
                
                items.append(.action(generateAction(true)))
                items.append(.action(generateAction(false)))
                
                var ignoreNextActions = false
                if strongSelf.chatLocation.threadId == nil {
                    items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowCalendar, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Calendar"), color: theme.contextMenu.primaryColor)
                    }, action: { _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        self?.openMediaCalendar()
                    })))
                }
                
                if photoCount != 0 && videoCount != 0 {
                    items.append(.separator)
                    
                    let showPhotos: Bool
                    switch pane.contentType {
                    case .photo, .photoOrVideo:
                        showPhotos = true
                    default:
                        showPhotos = false
                    }
                    let showVideos: Bool
                    switch pane.contentType {
                    case .video, .photoOrVideo:
                        showVideos = true
                    default:
                        showVideos = false
                    }
                    
                    items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowPhotos, icon: { theme in
                        if !showPhotos {
                            return UIImage()
                        }
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, a in
                        a(.default)
                        
                        guard let pane = pane else {
                            return
                        }
                        let updatedContentType: PeerInfoVisualMediaPaneNode.ContentType
                        switch pane.contentType {
                        case .photoOrVideo:
                            updatedContentType = .video
                        case .photo:
                            updatedContentType = .photo
                        case .video:
                            updatedContentType = .photoOrVideo
                        default:
                            updatedContentType = pane.contentType
                        }
                        pane.updateContentType(contentType: updatedContentType)
                    })))
                    items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowVideos, icon: { theme in
                        if !showVideos {
                            return UIImage()
                        }
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, a in
                        a(.default)
                        
                        guard let pane = pane else {
                            return
                        }
                        let updatedContentType: PeerInfoVisualMediaPaneNode.ContentType
                        switch pane.contentType {
                        case .photoOrVideo:
                            updatedContentType = .photo
                        case .photo:
                            updatedContentType = .photoOrVideo
                        case .video:
                            updatedContentType = .video
                        default:
                            updatedContentType = pane.contentType
                        }
                        pane.updateContentType(contentType: updatedContentType)
                    })))
                }
                
                var sourceView: UIView = source.view
                if sourceView.isDescendant(of: strongSelf.headerNode.navigationButtonContainer.rightButtonsBackground) {
                    sourceView = strongSelf.headerNode.navigationButtonContainer.rightButtonsBackground
                } else if sourceView.isDescendant(of: strongSelf.headerNode.navigationButtonContainer.leftButtonsBackground) {
                    sourceView = strongSelf.headerNode.navigationButtonContainer.leftButtonsBackground
                }
                
                let contextController = makeContextController(presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                contextController.passthroughTouchEvent = { sourceView, point in
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
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoVisualMediaPaneNode {
                                node.brieflyDisableTouchActions()
                                return .dismiss(consume: false, result: nil)
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoStoryPaneNode {
                                node.brieflyDisableTouchActions()
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
                strongSelf.mediaGalleryContextMenu = contextController
                controller.presentInGlobalOverlay(contextController)
            })
        }
    }
}
