import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import MultiplexedVideoNode
import EntityKeyboard

public final class ChatMediaInputGifPaneTrendingState {
    public let files: [MultiplexedVideoNodeFile]
    public let nextOffset: String?
    
    public init(files: [MultiplexedVideoNodeFile], nextOffset: String?) {
        self.files = files
        self.nextOffset = nextOffset
    }
}

public final class EntityKeyboardGifContent: Equatable {
    public let hasRecentGifs: Bool
    public let component: GifPagerContentComponent
    
    public init(hasRecentGifs: Bool, component: GifPagerContentComponent) {
        self.hasRecentGifs = hasRecentGifs
        self.component = component
    }
    
    public static func ==(lhs: EntityKeyboardGifContent, rhs: EntityKeyboardGifContent) -> Bool {
        if lhs.hasRecentGifs != rhs.hasRecentGifs {
            return false
        }
        if lhs.component != rhs.component {
            return false
        }
        return true
    }
}

public class PaneGifSearchForQueryResult {
    public let files: [MultiplexedVideoNodeFile]
    public let nextOffset: String?
    public let isComplete: Bool
    public let isStale: Bool
    
    public init(files: [MultiplexedVideoNodeFile], nextOffset: String?, isComplete: Bool, isStale: Bool) {
        self.files = files
        self.nextOffset = nextOffset
        self.isComplete = isComplete
        self.isStale = isStale
    }
}

public func paneGifSearchForQuery(context: AccountContext, query: String, offset: String?, incompleteResults: Bool = false, staleCachedResults: Bool = false, delayRequest: Bool = true, updateActivity: ((Bool) -> Void)?) -> Signal<PaneGifSearchForQueryResult?, NoError> {
    let contextBot = context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
    |> mapToSignal { searchBots -> Signal<EnginePeer?, NoError> in
        let botName = searchBots.gifBotUsername ?? "gif"
        return context.engine.peers.resolvePeerByName(name: botName)
    }
    |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?, Bool, Bool), NoError> in
        if case let .user(user) = peer, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
            let results = requestContextResults(engine: context.engine, botId: user.id, query: query, peerId: context.account.peerId, offset: offset ?? "", incompleteResults: incompleteResults, staleCachedResults: staleCachedResults, limit: 1)
            |> map { results -> (ChatPresentationInputQueryResult?, Bool, Bool) in
                return (.contextRequestResult(.user(user), results?.results), results != nil, results?.isStale ?? false)
            }
            
            let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?, Bool, Bool), NoError>
            if delayRequest {
                maybeDelayedContextResults = results |> delay(0.4, queue: Queue.concurrentDefaultQueue())
            } else {
                maybeDelayedContextResults = results
            }
            
            return maybeDelayedContextResults
        } else {
            return .single((nil, true, false))
        }
    }
    return contextBot
    |> mapToSignal { result -> Signal<PaneGifSearchForQueryResult?, NoError> in
        if let r = result.0, case let .contextRequestResult(_, maybeCollection) = r, let collection = maybeCollection {
            let results = collection.results
            var references: [MultiplexedVideoNodeFile] = []
            for result in results {
                switch result {
                case let .externalReference(externalReference):
                    var imageResource: TelegramMediaResource?
                    var thumbnailResource: TelegramMediaResource?
                    var thumbnailIsVideo: Bool = false
                    var uniqueId: Int64?
                    if let content = externalReference.content {
                        imageResource = content.resource
                        if let resource = content.resource as? WebFileReferenceMediaResource {
                            uniqueId = Int64(HashFunctions.murMurHash32(resource.url))
                        }
                    }
                    if let thumbnail = externalReference.thumbnail {
                        thumbnailResource = thumbnail.resource
                        if thumbnail.mimeType.hasPrefix("video/") {
                            thumbnailIsVideo = true
                        }
                    }
                    
                    if externalReference.type == "gif", let resource = imageResource, let content = externalReference.content, let dimensions = content.dimensions {
                        var previews: [TelegramMediaImageRepresentation] = []
                        var videoThumbnails: [TelegramMediaFile.VideoThumbnail] = []
                        if let thumbnailResource = thumbnailResource {
                            if thumbnailIsVideo {
                                videoThumbnails.append(TelegramMediaFile.VideoThumbnail(
                                    dimensions: dimensions,
                                    resource: thumbnailResource
                                ))
                            } else {
                                previews.append(TelegramMediaImageRepresentation(
                                    dimensions: dimensions,
                                    resource: thumbnailResource,
                                    progressiveSizes: [],
                                    immediateThumbnailData: nil,
                                    hasVideo: false,
                                    isPersonal: false
                                ))
                            }
                        }
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: uniqueId ?? 0), partialReference: nil, resource: resource, previewRepresentations: previews, videoThumbnails: videoThumbnails, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: dimensions, flags: [], preloadSize: nil)])
                        references.append(MultiplexedVideoNodeFile(file: FileMediaReference.standalone(media: file), contextResult: (collection, result)))
                    }
                case let .internalReference(internalReference):
                    if let file = internalReference.file {
                        references.append(MultiplexedVideoNodeFile(file: FileMediaReference.standalone(media: file), contextResult: (collection, result)))
                    }
                }
            }
            return .single(PaneGifSearchForQueryResult(files: references, nextOffset: collection.nextOffset, isComplete: result.1, isStale: result.2))
        } else if incompleteResults {
            return .single(nil)
        } else {
            return .complete()
        }
    }
    |> deliverOnMainQueue
    |> beforeStarted {
        updateActivity?(true)
    }
    |> afterCompleted {
        updateActivity?(false)
    }
}


public final class GifContext {
    private var componentValue: EntityKeyboardGifContent? {
        didSet {
            if let componentValue = self.componentValue {
                self.componentResult.set(.single(componentValue))
            }
        }
    }
    private let componentPromise = Promise<EntityKeyboardGifContent>()
    
    private let componentResult = Promise<EntityKeyboardGifContent>()
    public var component: Signal<EntityKeyboardGifContent, NoError> {
        return self.componentResult.get()
    }
    private var componentDisposable: Disposable?
    
    private let context: AccountContext
    private let subject: GifPagerContentComponent.Subject
    private let gifInputInteraction: GifPagerContentComponent.InputInteraction
    
    private var loadingMoreToken: String?
    
    public init(context: AccountContext, subject: GifPagerContentComponent.Subject, gifInputInteraction: GifPagerContentComponent.InputInteraction, trendingGifs: Signal<ChatMediaInputGifPaneTrendingState?, NoError>) {
        self.context = context
        self.subject = subject
        self.gifInputInteraction = gifInputInteraction
        
        let hideBackground = gifInputInteraction.hideBackground
        
        let hasRecentGifs = context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
        |> map { savedGifs -> Bool in
            return !savedGifs.isEmpty
        }
        
        let searchCategories: Signal<EmojiSearchCategories?, NoError> = context.engine.stickers.emojiSearchCategories(kind: .emoji)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let gifItems: Signal<EntityKeyboardGifContent, NoError>
        switch subject {
        case .recent:
            gifItems = combineLatest(
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs)),
                searchCategories
            )
            |> map { savedGifs, searchCategories -> EntityKeyboardGifContent in
                var items: [GifPagerContentComponent.Item] = []
                for gifItem in savedGifs {
                    items.append(GifPagerContentComponent.Item(
                        file: .savedGif(media: gifItem.contents.get(RecentMediaItem.self)!.media),
                        contextResult: nil
                    ))
                }
                return EntityKeyboardGifContent(
                    hasRecentGifs: true,
                    component: GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: false,
                        loadMoreToken: nil,
                        displaySearchWithPlaceholder: gifInputInteraction.hasSearch ? presentationData.strings.Common_Search : nil,
                        searchCategories: searchCategories,
                        searchInitiallyHidden: true,
                        searchState: .empty(hasResults: false),
                        hideBackground: hideBackground
                    )
                )
            }
        case .trending:
            gifItems = combineLatest(hasRecentGifs, trendingGifs, searchCategories)
            |> map { hasRecentGifs, trendingGifs, searchCategories -> EntityKeyboardGifContent in
                var items: [GifPagerContentComponent.Item] = []
                
                var isLoading = false
                if let trendingGifs = trendingGifs {
                    for file in trendingGifs.files {
                        items.append(GifPagerContentComponent.Item(
                            file: file.file,
                            contextResult: file.contextResult
                        ))
                    }
                } else {
                    isLoading = true
                }
                
                return EntityKeyboardGifContent(
                    hasRecentGifs: hasRecentGifs,
                    component: GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: nil,
                        displaySearchWithPlaceholder: gifInputInteraction.hasSearch ? presentationData.strings.Common_Search : nil,
                        searchCategories: searchCategories,
                        searchInitiallyHidden: true,
                        searchState: .empty(hasResults: false),
                        hideBackground: hideBackground
                    )
                )
            }
        case let .emojiSearch(query):
            gifItems = combineLatest(
                hasRecentGifs,
                paneGifSearchForQuery(context: context, query: query.joined(separator: ""), offset: nil, incompleteResults: true, staleCachedResults: true, delayRequest: false, updateActivity: nil),
                searchCategories
            )
            |> map { hasRecentGifs, result, searchCategories -> EntityKeyboardGifContent in
                var items: [GifPagerContentComponent.Item] = []
                
                var loadMoreToken: String?
                var isLoading = false
                if let result = result {
                    for file in result.files {
                        items.append(GifPagerContentComponent.Item(
                            file: file.file,
                            contextResult: file.contextResult
                        ))
                    }
                    loadMoreToken = result.nextOffset
                } else {
                    isLoading = true
                }
                
                return EntityKeyboardGifContent(
                    hasRecentGifs: hasRecentGifs,
                    component: GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: loadMoreToken,
                        displaySearchWithPlaceholder: gifInputInteraction.hasSearch ? presentationData.strings.Common_Search : nil,
                        searchCategories: searchCategories,
                        searchInitiallyHidden: true,
                        searchState: .active,
                        hideBackground: gifInputInteraction.hideBackground
                    )
                )
            }
        }
        
        self.componentPromise.set(gifItems)
        self.componentDisposable = (self.componentPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            strongSelf.componentValue = result
        })
    }
    
    deinit {
        self.componentDisposable?.dispose()
    }
    
    public func loadMore(token: String) {
        if self.loadingMoreToken == token {
            return
        }
        self.loadingMoreToken = token
        
        guard let componentValue = self.componentValue else {
            return
        }
        
        let context = self.context
        let subject = self.subject
        let gifInputInteraction = self.gifInputInteraction
        
        switch self.subject {
        case let .emojiSearch(query):
            let hasRecentGifs = context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
            |> map { savedGifs -> Bool in
                return !savedGifs.isEmpty
            }
            
            let searchCategories: Signal<EmojiSearchCategories?, NoError> = context.engine.stickers.emojiSearchCategories(kind: .emoji)
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let gifItems: Signal<EntityKeyboardGifContent, NoError>
            gifItems = combineLatest(hasRecentGifs, paneGifSearchForQuery(context: context, query: query.joined(separator: ""), offset: token, incompleteResults: true, staleCachedResults: true, delayRequest: false, updateActivity: nil), searchCategories)
            |> map { hasRecentGifs, result, searchCategories -> EntityKeyboardGifContent in
                var items: [GifPagerContentComponent.Item] = []
                var existingIds = Set<MediaId>()
                for item in componentValue.component.items {
                    items.append(item)
                    existingIds.insert(item.file.media.fileId)
                }
                
                var loadMoreToken: String?
                var isLoading = false
                if let result = result {
                    for file in result.files {
                        if existingIds.contains(file.file.media.fileId) {
                            continue
                        }
                        existingIds.insert(file.file.media.fileId)
                        items.append(GifPagerContentComponent.Item(
                            file: file.file,
                            contextResult: file.contextResult
                        ))
                    }
                    if !result.isComplete {
                        loadMoreToken = result.nextOffset
                    }
                } else {
                    isLoading = true
                }
                
                return EntityKeyboardGifContent(
                    hasRecentGifs: hasRecentGifs,
                    component: GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: loadMoreToken,
                        displaySearchWithPlaceholder: gifInputInteraction.hasSearch ? presentationData.strings.Common_Search : nil,
                        searchCategories: searchCategories,
                        searchInitiallyHidden: true,
                        searchState: .active,
                        hideBackground: gifInputInteraction.hideBackground
                    )
                )
            }
            
            self.componentPromise.set(gifItems)
        default:
            break
        }
    }
}
