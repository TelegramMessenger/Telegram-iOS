import Foundation
import SwiftSignalKit
import Postbox
import SyncCore
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

private struct SpotlightAccountContact: Equatable, Codable {
    var id: Int64
    var title: String
    var avatarPath: String?
}

private func manageableSpotlightContacts(accounts: Signal<[Account], NoError>) -> Signal<[Int64: SpotlightAccountContact], NoError> {
    let queue = Queue()
    return accounts
    |> mapToSignal { accounts -> Signal<[[SpotlightAccountContact]], NoError> in
        return combineLatest(queue: queue, accounts.map { account -> Signal<[SpotlightAccountContact], NoError> in
            return account.postbox.contactPeersView(accountPeerId: account.peerId, includePresences: false)
            |> map { view -> [SpotlightAccountContact] in
                var result: [SpotlightAccountContact] = []
                for peer in view.peers {
                    if let user = peer as? TelegramUser {
                        result.append(SpotlightAccountContact(id: user.id.toInt64(), title: user.debugDisplayTitle, avatarPath: smallestImageRepresentation(user.photo).flatMap { representation in
                            return account.postbox.mediaBox.resourcePath(representation.resource)
                        }))
                    }
                }
                result.sort(by: { $0.id < $1.id })
                return result
            }
            |> distinctUntilChanged
        })
    }
    |> map { accountContacts -> [Int64: SpotlightAccountContact] in
        var result: [Int64: SpotlightAccountContact] = [:]
        for singleAccountContacts in accountContacts {
            for contact in singleAccountContacts {
                if result[contact.id] == nil {
                    result[contact.id] = contact
                }
            }
        }
        return result
    }
}

private final class SpotlightContactContext {
    private let indexQueue: Queue
    private let disposable = MetaDisposable()
    private var contact: SpotlightAccountContact?
    
    init(indexQueue: Queue) {
        self.indexQueue = indexQueue
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func update(contact: SpotlightAccountContact) {
        if self.contact == contact {
            return
        }
        let photoUpdated = self.contact?.avatarPath != contact.avatarPath
        self.contact = contact
        
        let indexQueue = self.indexQueue
        let indexSignal: Signal<Never, NoError> = Signal { subscriber in
            indexQueue.async {
                let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
                attributeSet.title = contact.title
                if let avatarPath = contact.avatarPath, let avatarData = try? Data(contentsOf: URL(fileURLWithPath: avatarPath)), let image = UIImage(data: avatarData) {
                    let size = CGSize(width: 120.0, height: 120.0)
                    let context = DrawingContext(size: size, scale: 1.0, clear: true)
                    context.withFlippedContext { c in
                        c.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                        c.setBlendMode(.destinationOut)
                        c.draw(roundCorners.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    }
                    if let resultImage = context.generateImage(), let resultData = resultImage.pngData() {
                        attributeSet.thumbnailData = resultData
                    }
                }
                let item = CSSearchableItem(uniqueIdentifier: "contact-\(contact.id)", domainIdentifier: "telegram-contacts", attributeSet: attributeSet)
                Logger.shared.log("SpotlightDataContext", "index \(contact.id) title: \(contact.title)")
                CSSearchableIndex.default().indexSearchableItems([item], completionHandler: { error in
                    if let error = error {
                        Logger.shared.log("CSSearchableIndex", "error: \(error)")
                    }
                    subscriber.putCompletion()
                })
            }
            
            return EmptyDisposable
        }
        
        self.disposable.set(indexSignal.start())
    }
}

private final class SpotlightDataContextImpl {
    private let queue: Queue
    private let indexQueue: Queue = Queue()
    private var contactContexts: [Int64: SpotlightContactContext] = [:]
    
    private var listDisposable: Disposable?
    
    init(queue: Queue, accounts: Signal<[Account], NoError>) {
        self.queue = queue
        
        self.indexQueue.async {
            Logger.shared.log("SpotlightDataContext", "deleteSearchableItems")
            CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["telegram-contacts"], completionHandler: { _ in })
        }
        
        self.listDisposable = (manageableSpotlightContacts(accounts: accounts
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
        |> deliverOn(self.queue)).start(next: { [weak self] contacts in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateContacts(contacts: contacts)
        })
    }
    
    private func updateContacts(contacts: [Int64: SpotlightAccountContact]) {
        var validIds = Set<Int64>()
        for (_, contact) in contacts {
            validIds.insert(contact.id)
            
            let context: SpotlightContactContext
            if let current = self.contactContexts[contact.id] {
                context = current
            } else {
                context = SpotlightContactContext(indexQueue: self.indexQueue)
                self.contactContexts[contact.id] = context
            }
            context.update(contact: contact)
        }
        
        var removeIds: [Int64] = []
        for id in self.contactContexts.keys {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            self.contactContexts.removeValue(forKey: id)
        }
    }
}

public final class SpotlightDataContext {
    private let impl: QueueLocalObject<SpotlightDataContextImpl>
    
    public init(accounts: Signal<[Account], NoError>) {
        let queue = Queue()
        self.impl = QueueLocalObject(queue: queue, generate: {
            return SpotlightDataContextImpl(queue: queue, accounts: accounts)
        })
    }
}
