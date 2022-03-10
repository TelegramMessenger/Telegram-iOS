import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Display

import CoreSpotlight
import MobileCoreServices

private let roundCorners = { () -> UIImage in
    let diameter: CGFloat = 60.0
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}()

private struct SpotlightIndexStorageItem: Codable, Equatable {
    var firstName: String
    var lastName: String
    var avatarSourcePath: String?
}

private final class SpotlightIndexStorage {
    private let appBasePath: String
    private let basePath: String
    private var items: [PeerId: SpotlightIndexStorageItem] = [:]
    
    init(appBasePath: String, basePath: String) {
        self.appBasePath = appBasePath
        self.basePath = basePath
        
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
        
        self.reload()
        
        if self.items.isEmpty {
            CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["telegram-contacts"], completionHandler: { _ in })
        }
    }
    
    private func path(peerId: PeerId) -> String {
        return self.basePath + "/p:\(UInt64(bitPattern: peerId.toInt64()))"
    }
    
    private func reload() {
        self.items.removeAll()
        
        guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: self.basePath), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants], errorHandler: nil) else {
            return
        }
        
        while let item = enumerator.nextObject() {
            guard let url = item as? NSURL else {
                continue
            }
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
                continue
            }
            if let value = resourceValues[.isDirectoryKey] as? Bool, !value {
                continue
            }
            if let path = url.path, let directoryName = url.lastPathComponent, directoryName.hasPrefix("p:") {
                let peerIdString = directoryName[directoryName.index(directoryName.startIndex, offsetBy: 2)...]
                if let peerIdValue = UInt64(peerIdString) {
                    let peerId = PeerId(Int64(bitPattern: peerIdValue))
                    
                    let item: SpotlightIndexStorageItem
                    if let itemData = try? Data(contentsOf: URL(fileURLWithPath: path + "/data.json")), let decodedItem = try? JSONDecoder().decode(SpotlightIndexStorageItem.self, from: itemData) {
                        item = decodedItem
                    } else {
                        let _ = try? FileManager.default.removeItem(atPath: path + "/data.json")
                        let _ = try? FileManager.default.removeItem(atPath: path + "/avatar.png")
                        item = SpotlightIndexStorageItem(firstName: "", lastName: "", avatarSourcePath: nil)
                    }
                    
                    self.items[peerId] = item
                }
            }
        }
    }
    
    func update(items: [PeerId: SpotlightIndexStorageItem]) {
        let validPeerIds = Set(items.keys)
        var removePeerIds: [PeerId] = []
        for (peerId, _) in self.items {
            if !validPeerIds.contains(peerId) {
                removePeerIds.append(peerId)
            }
        }
        if !removePeerIds.isEmpty {
            for peerId in removePeerIds {
                let _ = try? FileManager.default.removeItem(atPath: self.path(peerId: peerId))
                self.items.removeValue(forKey: peerId)
            }
            
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: removePeerIds.map { peerId in
                return "contact-\(peerId.toInt64())"
            })
        }
        
        var addToIndexItems: [CSSearchableItem] = []
        
        for (peerId, item) in items {
            let previousItem = self.items[peerId]
            if previousItem != item {
                var updatedAvatarSourcePath: String?
                if let avatarSourcePath = item.avatarSourcePath, let _ = fileSize(self.appBasePath + "/" + avatarSourcePath) {
                    updatedAvatarSourcePath = avatarSourcePath
                }
                
                var encodeItem = item
                encodeItem.avatarSourcePath = updatedAvatarSourcePath
                
                if encodeItem == previousItem {
                    continue
                }
                
                print("Spotlight: updating \(item.firstName) \(item.lastName)")
                let path = self.path(peerId: peerId)
                let _ = try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                
                var resolvedAvatarPath: String?
                if previousItem?.avatarSourcePath != updatedAvatarSourcePath {
                    let avatarPath = path + "/avatar.png"
                    let _ = try? FileManager.default.removeItem(atPath: avatarPath)
                    
                    if let updatedAvatarSourcePathValue = updatedAvatarSourcePath, let avatarData = try? Data(contentsOf: URL(fileURLWithPath: self.appBasePath + "/" + updatedAvatarSourcePathValue)), let image = UIImage(data: avatarData) {
                        let size = CGSize(width: 120.0, height: 120.0)
                        let context = DrawingContext(size: size, scale: 1.0, clear: true)
                        context.withFlippedContext { c in
                            c.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                            c.setBlendMode(.destinationOut)
                            c.draw(roundCorners.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                        }
                        if let resultImage = context.generateImage(), let resultData = resultImage.pngData(), let _ = try? resultData.write(to: URL(fileURLWithPath: avatarPath)) {
                            resolvedAvatarPath = avatarPath
                        } else {
                            updatedAvatarSourcePath = nil
                        }
                    }
                }
                
                let itemDataPath = path + "/data.json"
                
                let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
                attributeSet.version = "\(UInt64.random(in: 0 ..< UInt64.max))"
                if !item.firstName.isEmpty && !item.lastName.isEmpty {
                    attributeSet.title = "\(item.firstName) \(item.lastName)"
                } else if !item.firstName.isEmpty {
                    attributeSet.title = item.firstName
                } else {
                    attributeSet.title = item.lastName
                }
                attributeSet.thumbnailURL = resolvedAvatarPath.flatMap(URL.init(fileURLWithPath:))
                let indexItem = CSSearchableItem(uniqueIdentifier: "contact-\(peerId.toInt64())", domainIdentifier: "telegram-contacts", attributeSet: attributeSet)
                addToIndexItems.append(indexItem)
                
                encodeItem.avatarSourcePath = updatedAvatarSourcePath
                if let data = try? JSONEncoder().encode(encodeItem) {
                    let _ = try? data.write(to: URL(fileURLWithPath: itemDataPath), options: [.atomic])
                }
                
                self.items[peerId] = item
            }
        }
        
        if !addToIndexItems.isEmpty {
            CSSearchableIndex.default().indexSearchableItems(addToIndexItems, completionHandler: { error in
                if let error = error {
                    Logger.shared.log("CSSearchableIndex", "indexSearchableItems error: \(error)")
                }
            })
        }
    }
}

private func manageableSpotlightContacts(appBasePath: String, accounts: Signal<[Account], NoError>) -> Signal<[PeerId: SpotlightIndexStorageItem], NoError> {
    let queue = Queue()
    return accounts
    |> mapToSignal { accounts -> Signal<[[PeerId: SpotlightIndexStorageItem]], NoError> in
        return combineLatest(queue: queue, accounts.map { account -> Signal<[PeerId: SpotlightIndexStorageItem], NoError> in
            return TelegramEngine(account: account).data.subscribe(
                TelegramEngine.EngineData.Item.Contacts.List(includePresences: false)
            )
            |> map { view -> [EnginePeer.Id: SpotlightIndexStorageItem] in
                var result: [EnginePeer.Id: SpotlightIndexStorageItem] = [:]
                for peer in view.peers {
                    if case let .user(user) = peer {
                        let avatarSourcePath = smallestImageRepresentation(user.photo).flatMap { representation -> String? in
                            let resourcePath = account.postbox.mediaBox.resourcePath(representation.resource)
                            if resourcePath.hasPrefix(appBasePath + "/") {
                                return String(resourcePath[resourcePath.index(resourcePath.startIndex, offsetBy: appBasePath.count + 1)...])
                            } else {
                                return resourcePath
                            }
                        }
                        result[user.id] = SpotlightIndexStorageItem(firstName: user.firstName ?? "", lastName: user.lastName ?? "", avatarSourcePath: avatarSourcePath)
                    }
                }
                return result
            }
            |> distinctUntilChanged
        })
    }
    |> map { accountContacts -> [EnginePeer.Id: SpotlightIndexStorageItem] in
        var result: [EnginePeer.Id: SpotlightIndexStorageItem] = [:]
        for singleAccountContacts in accountContacts {
            for (peerId, contact) in singleAccountContacts {
                if result[peerId] == nil {
                    result[peerId] = contact
                }
            }
        }
        return result
    }
}

private final class SpotlightDataContextImpl {
    private let queue: Queue
    private let appBasePath: String
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let indexStorage: SpotlightIndexStorage
    
    private var listDisposable: Disposable?
    
    init(queue: Queue, appBasePath: String, accountManager: AccountManager<TelegramAccountManagerTypes>, accounts: Signal<[Account], NoError>) {
        self.queue = queue
        self.appBasePath = appBasePath
        self.accountManager = accountManager
        self.indexStorage = SpotlightIndexStorage(appBasePath: appBasePath, basePath: accountManager.basePath + "/spotlight")
        
        self.listDisposable = (manageableSpotlightContacts(appBasePath: appBasePath, accounts: accounts
        |> map { accounts in
            return accounts.sorted(by: { $0.id < $1.id })
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.count != rhs.count {
                return false
            }
            for i in 0 ..< lhs.count {
                if lhs[i] !== rhs[i] {
                    return false
                }
            }
            return true
        }))
        |> deliverOn(self.queue)).start(next: { [weak self] items in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateContacts(items: items)
        })
    }
    
    private func updateContacts(items: [PeerId: SpotlightIndexStorageItem]) {
        self.indexStorage.update(items: items)
    }
}

public final class SpotlightDataContext {
    private let impl: QueueLocalObject<SpotlightDataContextImpl>
    
    public init(appBasePath: String, accountManager: AccountManager<TelegramAccountManagerTypes>, accounts: Signal<[Account], NoError>) {
        let queue = Queue()
        self.impl = QueueLocalObject(queue: queue, generate: {
            return SpotlightDataContextImpl(queue: queue, appBasePath: appBasePath, accountManager: accountManager, accounts: accounts)
        })
    }
}
