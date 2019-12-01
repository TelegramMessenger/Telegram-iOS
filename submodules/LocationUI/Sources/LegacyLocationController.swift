import Foundation
import UIKit
import Display
import LegacyComponents
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import AccountContext
import ShareController
import LegacyUI
import OpenInExternalAppUI
import AppBundle
import LocationResources

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

func makeLegacyPeer(_ peer: Peer) -> AnyObject? {
    if let user = peer as? TelegramUser {
        let legacyUser = TGUser()
        legacyUser.uid = user.id.id
        legacyUser.firstName = user.firstName
        legacyUser.lastName = user.lastName
        if let representation = smallestImageRepresentation(user.photo) {
            legacyUser.photoUrlSmall = legacyImageLocationUri(resource: representation.resource)
        }
        return legacyUser
    } else if let channel = peer as? TelegramChannel {
        let legacyConversation = TGConversation()
        legacyConversation.conversationId = Int64(channel.id.id)
        legacyConversation.chatTitle = channel.title
        if let representation = smallestImageRepresentation(channel.photo) {
            legacyConversation.chatPhotoSmall = legacyImageLocationUri(resource: representation.resource)
        }
        return legacyConversation
    } else {
        return nil
    }
}

private func makeLegacyMessage(_ message: Message) -> TGMessage {
    let result = TGMessage()
    result.mid = message.id.id
    result.date = Double(message.timestamp)
    if message.flags.contains(.Failed) {
        result.deliveryState = TGMessageDeliveryStateFailed
    } else if message.flags.contains(.Sending) {
        result.deliveryState = TGMessageDeliveryStatePending
    } else {
        result.deliveryState = TGMessageDeliveryStateDelivered
    }
    
    for attribute in message.attributes {
        if let attribute = attribute as? EditedMessageAttribute {
            result.editDate = Double(attribute.date)
        }
    }
    
    var media: [Any] = []
    for m in message.media {
        if let mapMedia = m as? TelegramMediaMap {
            let legacyLocation = TGLocationMediaAttachment()
            legacyLocation.latitude = mapMedia.latitude
            legacyLocation.longitude = mapMedia.longitude
            if let venue = mapMedia.venue {
                legacyLocation.venue = TGVenueAttachment(title: venue.title, address: venue.address, provider: venue.provider, venueId: venue.id, type: venue.type)
            }
            if let liveBroadcastingTimeout = mapMedia.liveBroadcastingTimeout {
                legacyLocation.period = liveBroadcastingTimeout
            }
            
            media.append(legacyLocation)
        }
    }
    if !media.isEmpty {
        result.mediaAttachments = media
    }
    
    return result
}

private func legacyRemainingTime(message: TGMessage) -> SSignal {
    var liveBroadcastingTimeoutValue: Int32?
    if let mediaAttachments = message.mediaAttachments {
        for media in mediaAttachments {
            if let m = media as? TGLocationMediaAttachment, m.period != 0 {
                liveBroadcastingTimeoutValue = m.period
            }
        }
    }
    guard let liveBroadcastingTimeout = liveBroadcastingTimeoutValue else {
        return SSignal.fail(nil)
    }
    
    if message.deliveryState != TGMessageDeliveryStateDelivered {
        return SSignal.single(liveBroadcastingTimeout as NSNumber)
    }
    
    let remainingTime = SSignal.`defer`({
        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        let remainingTime = max(0, Int32(message.date) + liveBroadcastingTimeout - currentTime)
        var signal = SSignal.single(remainingTime as NSNumber)
        if remainingTime == 0 {
            signal = signal?.then(SSignal.fail(nil))
        }
        return signal
    })!
    
    return (remainingTime.then(SSignal.complete().delay(5.0, on: SQueue.main()))).restart().`catch`({ _ in
        return SSignal.complete()
    })
}

private func telegramMap(for location: TGLocationMediaAttachment) -> TelegramMediaMap {
    let mapVenue: MapVenue?
    if let venue = location.venue {
        mapVenue = MapVenue(title: venue.title ?? "", address: venue.address ?? "", provider: venue.provider ?? "", id: venue.venueId ?? "", type: venue.type ?? "")
    } else {
        mapVenue = nil
    }
    return TelegramMediaMap(latitude: location.latitude, longitude: location.longitude, geoPlace: nil, venue: mapVenue, liveBroadcastingTimeout: nil)
}

func legacyLocationPalette(from theme: PresentationTheme) -> TGLocationPallete {
    let listTheme = theme.list
    let searchTheme = theme.rootController.navigationSearchBar
    return TGLocationPallete(backgroundColor: listTheme.plainBackgroundColor, selectionColor: listTheme.itemHighlightedBackgroundColor, separatorColor: listTheme.itemPlainSeparatorColor, textColor: listTheme.itemPrimaryTextColor, secondaryTextColor: listTheme.itemSecondaryTextColor, accentColor: listTheme.itemAccentColor, destructiveColor: listTheme.itemDestructiveColor, locationColor: UIColor(rgb: 0x008df2), liveLocationColor: UIColor(rgb: 0xff6464), iconColor: searchTheme.backgroundColor, sectionHeaderBackgroundColor: theme.chatList.sectionHeaderFillColor, sectionHeaderTextColor: theme.chatList.sectionHeaderTextColor, searchBarPallete: TGSearchBarPallete(dark: theme.overallDarkAppearance, backgroundColor: searchTheme.backgroundColor, highContrastBackgroundColor: searchTheme.backgroundColor, textColor: searchTheme.inputTextColor, placeholderColor: searchTheme.inputPlaceholderTextColor, clearIcon: generateClearIcon(color: theme.rootController.navigationSearchBar.inputClearButtonColor), barBackgroundColor: searchTheme.backgroundColor, barSeparatorColor: searchTheme.separatorColor, plainBackgroundColor: searchTheme.backgroundColor, accentColor: searchTheme.accentColor, accentContrastColor: searchTheme.backgroundColor, menuBackgroundColor: searchTheme.backgroundColor, segmentedControlBackgroundImage: nil, segmentedControlSelectedImage: nil, segmentedControlHighlightedImage: nil, segmentedControlDividerImage: nil), avatarPlaceholder: nil)
}

public func legacyLocationController(message: Message?, mapMedia: TelegramMediaMap, context: AccountContext, openPeer: @escaping (Peer) -> Void, sendLiveLocation: @escaping (CLLocationCoordinate2D, Int32) -> Void, stopLiveLocation: @escaping () -> Void, openUrl: @escaping (String) -> Void) -> ViewController {
    let legacyLocation = TGLocationMediaAttachment()
    legacyLocation.latitude = mapMedia.latitude
    legacyLocation.longitude = mapMedia.longitude
    if let venue = mapMedia.venue {
        legacyLocation.venue = TGVenueAttachment(title: venue.title, address: venue.address, provider: venue.provider, venueId: venue.id, type: venue.type)
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
    let legacyController = LegacyController(presentation: .navigation, theme: presentationData.theme, strings: presentationData.strings)
    legacyController.navigationPresentation = .modal
    let controller: TGLocationViewController
    
    let venueColor = mapMedia.venue?.type.flatMap { venueIconColor(type: $0) }
    if let message = message {
        let legacyMessage = makeLegacyMessage(message)
        let legacyAuthor: AnyObject? = message.author.flatMap(makeLegacyPeer)
        
        let updatedLocations = SSignal(generator: { subscriber in
            let disposable = topPeerActiveLiveLocationMessages(viewTracker: context.account.viewTracker, accountPeerId: context.account.peerId, peerId: message.id.peerId).start(next: { (_, messages) in
                var result: [Any] = []
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                loop: for message in messages {
                    var liveBroadcastingTimeout: Int32 = 0
                    
                    mediaLoop: for media in message.media {
                        if let map = media as? TelegramMediaMap, let timeout = map.liveBroadcastingTimeout  {
                            liveBroadcastingTimeout = timeout
                            break mediaLoop
                        }
                    }
                    
                    let legacyMessage = makeLegacyMessage(message)
                    guard let legacyAuthor = message.author.flatMap(makeLegacyPeer) else {
                        continue loop
                    }
                    let remainingTime = max(0, message.timestamp + liveBroadcastingTimeout - currentTime)
                    if legacyMessage.locationAttachment?.period != 0 {
                        let hasOwnSession = message.localTags.contains(.OutgoingLiveLocation)
                        var isOwn = false
                        if !message.flags.contains(.Incoming) {
                            isOwn = true
                        } else if let peer = message.peers[message.id.peerId] as? TelegramChannel {
                            isOwn = peer.hasPermission(.sendMessages)
                        }
                        
                        let liveLocation = TGLiveLocation(message: legacyMessage, peer: legacyAuthor, hasOwnSession: hasOwnSession, isOwnLocation: isOwn, isExpired: remainingTime == 0)!
                        result.append(liveLocation)
                    }
                }
                subscriber?.putNext(result)
            })
            
            return SBlockDisposable(block: {
                disposable.dispose()
            })
        })!
        
        if let liveBroadcastingTimeout = mapMedia.liveBroadcastingTimeout {
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let remainingTime = max(0, message.timestamp + liveBroadcastingTimeout - currentTime)
            
            let messageLiveLocation = TGLiveLocation(message: legacyMessage, peer: legacyAuthor, hasOwnSession: false, isOwnLocation: false, isExpired: remainingTime == 0)!
            
            controller = TGLocationViewController(context: legacyController.context, liveLocation: messageLiveLocation)
            
            if remainingTime == 0 {
                let freezeLocations: [Any] = [messageLiveLocation]
                controller.setLiveLocationsSignal(.single(freezeLocations))
            } else {
                controller.setLiveLocationsSignal(updatedLocations)
                if message.flags.contains(.Incoming) {
                    context.account.viewTracker.updateSeenLiveLocationForMessageIds(messageIds: Set([message.id]))
                }
            }
        } else {
            controller = TGLocationViewController(context: legacyController.context, message: legacyMessage, peer: legacyAuthor, color: venueColor)!
            controller.receivingPeer = message.peers[message.id.peerId].flatMap(makeLegacyPeer)
            controller.setLiveLocationsSignal(updatedLocations)
        }
        
        let namespacesWithEnabledLiveLocation: Set<PeerId.Namespace> = Set([
            Namespaces.Peer.CloudChannel,
            Namespaces.Peer.CloudGroup,
            Namespaces.Peer.CloudUser
            ])
        if namespacesWithEnabledLiveLocation.contains(message.id.peerId.namespace) {
            controller.allowLiveLocationSharing = true
        }
    } else {
        let attachment = TGLocationMediaAttachment()
        attachment.latitude = mapMedia.latitude
        attachment.longitude = mapMedia.longitude
        controller = TGLocationViewController(context: legacyController.context, locationAttachment: attachment, peer: nil, color: venueColor)
    }
    
    controller.remainingTimeForMessage = { message in
        return legacyRemainingTime(message: message!)
    }
    controller.liveLocationStarted = { [weak legacyController] coordinate, period in
        sendLiveLocation(coordinate, period)
        legacyController?.dismiss()
    }
    controller.liveLocationStopped = { [weak legacyController] in
        stopLiveLocation()
        legacyController?.dismiss()
    }
    
    let theme = (context.sharedContext.currentPresentationData.with { $0 }).theme
    controller.pallete = legacyLocationPalette(from: theme)
    
    controller.modalMode = true
    controller.presentActionsMenu = { [weak legacyController] legacyLocation, directions in
        if let strongLegacyController = legacyController, let location = legacyLocation {
            let map = telegramMap(for: location)
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let shareAction = OpenInControllerAction(title: presentationData.strings.Conversation_ContextMenuShare, action: {
                strongLegacyController.present(ShareController(context: context, subject: .mapMedia(map), externalShare: true), in: .window(.root), with: nil)
            })
            
            strongLegacyController.present(OpenInActionSheetController(context: context, item: .location(location: map, withDirections: directions), additionalAction: !directions ? shareAction : nil, openUrl: openUrl), in: .window(.root), with: nil)
        }
    }
    
    controller.onViewDidAppear = { [weak controller] in
        if let strongController = controller {
            strongController.view.disablesInteractiveModalDismiss = true
            strongController.view.disablesInteractiveTransitionGestureRecognizer = true
            strongController.locationMapView.interactiveTransitionGestureRecognizerTest = { point -> Bool in
                return point.x > 30.0
            }
        }
    }
    
    legacyController.navigationItem.title = controller.navigationItem.title
    controller.updateRightBarItem = { item, action, animated in
        if action {
            legacyController.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationShareIcon(theme), style: .plain, target: controller, action: #selector(controller.actionsButtonPressed))
        } else {
            legacyController.navigationItem.setRightBarButton(item, animated: animated)
        }
    }
    legacyController.bind(controller: controller)
    
    let presentationDisposable = context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
        if let controller = controller  {
            controller.pallete = legacyLocationPalette(from: presentationData.theme)
        }
    })
    legacyController.disposables.add(presentationDisposable)

    return legacyController
}
