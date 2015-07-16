import UIKit
import XCTest

import Postbox

enum TestPeerNamespace: PeerId.Namespace {
    case User = 0
}

enum TestMessageNamespace: MessageId.Namespace {
    case Cloud = 0
    case Local = 1
}

enum TestMediaNamespace: MediaId.Namespace {
    case Test = 0
}

class TestPeer: Peer {
    var id: PeerId
    
    init(id: PeerId) {
        self.id = id
    }
    
    required init(decoder: Decoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("id"))
    }
    
    func encode(encoder: Encoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "id")
    }
}

class TestMessage: Message {
    var id: MessageId
    var authorId: PeerId
    var date: Int32
    var text: String
    var referencedMediaIds: [MediaId]
    
    var timestamp: Int32 {
        return date
    }
    
    init(id: MessageId, authorId: PeerId, date: Int32, text: String, referencedMediaIds: [MediaId]) {
        self.id = id
        self.authorId = authorId
        self.date = date
        self.text = text
        self.referencedMediaIds = referencedMediaIds
    }
    
    required init(decoder: Decoder) {
        self.id = MessageId(decoder.decodeBytesForKeyNoCopy("id"))
        self.authorId = PeerId(decoder.decodeInt64ForKey("authorId"))
        self.date = decoder.decodeInt32ForKey("date")
        self.text = decoder.decodeStringForKey("text")
        self.referencedMediaIds = MediaId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("mediaIds"))
    }
    
    func encode(encoder: Encoder) {
        let buffer = WriteBuffer()
        self.id.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "id")
        buffer.reset()
        
        encoder.encodeInt64(self.authorId.toInt64(), forKey: "authorId")
        encoder.encodeInt32(self.date, forKey: "date")
        encoder.encodeString(self.text, forKey: "text")
        
        MediaId.encodeArrayToBuffer(self.referencedMediaIds, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "mediaIds")
        buffer.reset()
    }
}

class TestMedia: Media {
    var id: MediaId
    
    init(id: MediaId) {
        self.id = id
    }
    
    required init(decoder: Decoder) {
        self.id = MediaId(decoder.decodeBytesForKeyNoCopy("id"))
    }
    
    func encode(encoder: Encoder) {
        let buffer = WriteBuffer()
        self.id.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "id")
    }
}

class EmptyState: PostboxState {
    required init(decoder: Decoder) {
    }
    
    func encode(encoder: Encoder) {
    }
}

class PostboxTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAddMessages() {
        declareEncodable(TestMessage.self, { TestMessage(decoder: $0) })
        declareEncodable(TestMedia.self, { TestMedia(decoder: $0) })
        
        let ownerId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 1000)
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        let messageNamespace = TestMessageNamespace.Cloud.rawValue
        
        let basePath = "/tmp/postboxtest"
        NSFileManager.defaultManager().removeItemAtPath(basePath, error: nil)
        let postbox = Postbox<EmptyState>(basePath: basePath, messageNamespaces: [messageNamespace])
        (postbox.modify { state -> Void in
            let testMedia = TestMedia(id: MediaId(namespace: TestMediaNamespace.Test.rawValue, id: 1))
            for i in 0 ..< 10 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: ownerId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            return
        }).start()
        postbox._dumpTables()
        
        (postbox.modify { state -> Void in
            var messageIds: [MessageId] = []
            for i in 0 ..< 5 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(i + 1))
                messageIds.append(messageId)
            }
            state.deleteMessagesWithIds(messageIds)
        }).start()
        postbox._dumpTables();
        
        (postbox.modify { state -> Void in
            var messageIds: [MessageId] = []
            for i in 0 ..< 10 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(i + 1))
                messageIds.append(messageId)
            }
            state.deleteMessagesWithIds(messageIds)
        }).start()
        postbox._dumpTables();
    }
    
    func testMessageNamespaceViewAddTail() {
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        
        let view = MutableMessageView(namespaces: [1, 2], count: 3, earlier: [:], messages: [], later: [:])
        
        func message(namespace: Int32, id: Int32, timestamp: Int32) -> Message {
            let messageId = MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
            return TestMessage(id: messageId, authorId: otherId, date: Int32(timestamp), text: "", referencedMediaIds: [])
        }
        
        func add(message: Message) {
            view.add(message)
            println("\(view)\n")
        }
        
        /*func assertIds(earlier: Int32?, ids: [Int32], later: Int32?) {
            let otherMessages = ids.reverse().map({ id -> Message in
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(id))
                let message = TestMessage(id: messageId, authorId: otherId, date: Int32(0), text: "", referencedMediaIds: [])
                return message
            })
            let otherView = MessageNamespaceView(namespace: messageNamespace, messages: otherMessages, earlierId: earlier, laterId: later, count: 2)
            
            XCTAssert(view == otherView, "\(view) != \(otherView)")
        }*/
        
        add(message(1, 90, 90))
        add(message(2, 70, 70))
        
        add(message(1, 70, 70))
        
        add(message(1, 80, 80))
        add(message(2, 100, 100))
        
        add(message(1, 75, 75))
        
        add(message(1, 60, 60))
    }
    
    func testMessageNamespaceViewAddMiddle1() {
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        
        func message(namespace: Int32, id: Int32, timestamp: Int32) -> Message {
            let messageId = MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
            return TestMessage(id: messageId, authorId: otherId, date: Int32(timestamp), text: "", referencedMediaIds: [])
        }
        
        let view = MutableMessageView(namespaces: [1, 2], count: 3, earlier: [1: message(1, 90, 90)], messages: [message(1, 100, 100), message(1, 120, 120), message(1, 140, 140)], later: [1: message(1, 200, 200)])
        
        func add(message: Message) {
            view.add(message)
            println("\(view)\n")
        }
        
        add(message(2, 105, 105))
        add(message(2, 150, 150))
        add(message(2, 250, 250))
        add(message(2, 180, 180))
    }
    
    func testMessageNamespaceRemoveTail() {
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        
        var messages: [Message] = []
        
        func print(messages: [Message]) {
            var string = ""
            string += "["
            var first = true
            for message in messages {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(message.id.namespace): \(message.id.id)—\(message.timestamp)"
            }
            string += "]"
            println(string)
        }
        
        let view = MutableMessageView(namespaces: [1, 2], count: 3, earlier: [:], messages: [], later: [:])
        
        func id(namespace: Int32, id: Int32) -> MessageId {
            return MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
        }
        
        func message(namespace: Int32, id: Int32, timestamp: Int32) -> Message {
            let messageId = MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
            return TestMessage(id: messageId, authorId: otherId, date: Int32(timestamp), text: "", referencedMediaIds: [])
        }
        
        func add(message: Message) {
            view.add(message)
            println("\(view)")
            
            messages.append(message)
            messages.sort({MessageIndex($0) < MessageIndex($1)})
            
            print(messages)
            println()
        }
        
        func remove(ids: Set<MessageId>) -> MutableMessageView.RemoveContext {
            let context = view.remove(ids)
            println("\(view)")
            
            messages = messages.filter { !ids.contains($0.id) }
            print(messages)
            
            return context
        }
        
        func fetchEarlier(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = messages.count - 1
            while i >= 0 && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id < id!) {
                    filtered.append(messages[i])
                }
                i--
            }
            
            return filtered
        }
        
        func fetchLater(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = 0
            while i < messages.count && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id > id!) {
                    filtered.append(messages[i])
                }
                i++
            }
            
            return filtered
        }
        
        func complete(context: MutableMessageView.RemoveContext) {
            view.complete(context, fetchEarlier: fetchEarlier(messages), fetchLater: fetchLater(messages))
            println("\(view)\n")
        }
        
        add(message(1, 90, 90))
        add(message(2, 70, 70))
        add(message(1, 70, 70))
        add(message(1, 80, 80))
        add(message(2, 100, 100))
        add(message(1, 75, 75))
        add(message(1, 60, 60))
        
        println("remove 1:90, 2:100")
        complete(remove([id(1, 90), id(2, 100)]))

        println("remove 1:60, 2:70")
        complete(remove([id(1, 60), id(2, 70)]))
        
        println("remove 1:80, 2:100")
        complete(remove([id(1, 80), id(2, 100)]))
    }
    
    func testMessageNamespaceRemoveAllInside() {
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        
        var messages: [Message] = []
        
        func print(messages: [Message]) {
            var string = ""
            string += "["
            var first = true
            for message in messages {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(message.id.namespace): \(message.id.id)—\(message.timestamp)"
            }
            string += "]"
            println(string)
        }
        
        let view = MutableMessageView(namespaces: [1, 2], count: 3, earlier: [:], messages: [], later: [:])
        
        func id(namespace: Int32, id: Int32) -> MessageId {
            return MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
        }
        
        func message(namespace: Int32, id: Int32, timestamp: Int32) -> Message {
            let messageId = MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
            return TestMessage(id: messageId, authorId: otherId, date: Int32(timestamp), text: "", referencedMediaIds: [])
        }
        
        func add(message: Message) {
            view.add(message)
            println("\(view)")
            
            messages.append(message)
            messages.sort({MessageIndex($0) < MessageIndex($1)})
            
            print(messages)
            println()
        }
        
        func remove(ids: Set<MessageId>) -> MutableMessageView.RemoveContext {
            let context = view.remove(ids)
            println("\(view)")
            
            messages = messages.filter { !ids.contains($0.id) }
            print(messages)
            
            return context
        }
        
        func fetchEarlier(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = messages.count - 1
            while i >= 0 && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id < id!) {
                    filtered.append(messages[i])
                }
                i--
            }
            
            return filtered
        }
        
        func fetchLater(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = 0
            while i < messages.count && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id > id!) {
                    filtered.append(messages[i])
                }
                i++
            }
            
            return filtered
        }
        
        func complete(context: MutableMessageView.RemoveContext) {
            view.complete(context, fetchEarlier: fetchEarlier(messages), fetchLater: fetchLater(messages))
            println("\(view)\n")
        }
        
        add(message(2, 10, 10))
        add(message(2, 20, 20))
        add(message(1, 90, 90))
        add(message(2, 70, 70))
        add(message(1, 70, 70))
        add(message(1, 80, 80))
        add(message(2, 100, 100))
        add(message(1, 75, 75))
        add(message(1, 60, 60))
        
        println("remove 2:20, 1:80, 1:90, 2:100")
        complete(remove([id(2, 20), id(1, 80), id(1, 90), id(2, 100)]))
    }
    
    func testMessageNamespaceRemoveMiddleSome() {
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        
        var messages: [Message] = []
        
        func print(messages: [Message]) {
            var string = ""
            string += "["
            var first = true
            for message in messages {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(message.id.namespace): \(message.id.id)—\(message.timestamp)"
            }
            string += "]"
            println(string)
        }
        
        func id(namespace: Int32, id: Int32) -> MessageId {
            return MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
        }
        
        func message(namespace: Int32, id: Int32, timestamp: Int32) -> Message {
            let messageId = MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
            return TestMessage(id: messageId, authorId: otherId, date: Int32(timestamp), text: "", referencedMediaIds: [])
        }
        
        messages = [message(2, 1, 1), message(2, 2, 2), message(1, 98, 98), message(1, 99, 99), message(1, 100, 100), message(2, 101, 101), message(1, 102, 102), message(1, 103, 103), message(1, 104, 104), message(1, 105, 105), message(2, 200, 200), message(2, 300, 300)]
        
        let view = MutableMessageView(namespaces: [1, 2], count: 3, earlier: [1: message(1, 99, 99), 2: message(2, 2, 2)], messages: [message(1, 100, 100), message(2, 101, 101), message(1, 102, 102)], later: [1: message(1, 103, 103), 2: message(2, 200, 200)])
        
        func add(message: Message) {
            view.add(message)
            println("\(view)")
            
            messages.append(message)
            messages.sort({MessageIndex($0) < MessageIndex($1)})
            
            print(messages)
            println()
        }
        
        func remove(ids: Set<MessageId>) -> MutableMessageView.RemoveContext {
            let context = view.remove(ids)
            println("\(view)")
            
            messages = messages.filter { !ids.contains($0.id) }
            print(messages)
            
            return context
        }
        
        func fetchEarlier(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = messages.count - 1
            while i >= 0 && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id < id!) {
                    filtered.append(messages[i])
                }
                i--
            }
            
            return filtered
        }
        
        func fetchLater(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = 0
            while i < messages.count && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id > id!) {
                    filtered.append(messages[i])
                }
                i++
            }
            
            return filtered
        }
        
        func complete(context: MutableMessageView.RemoveContext) {
            view.complete(context, fetchEarlier: fetchEarlier(messages), fetchLater: fetchLater(messages))
            println("\(view)\n")
        }
        
        print(messages)
        println("\(view)")
        
        println("remove 1:100, 2:101")
        complete(remove([id(1, 100), id(2, 101)]))
    }
    
    func testMessageNamespaceRemoveMiddleAllInside() {
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        
        var messages: [Message] = []
        
        func print(messages: [Message]) {
            var string = ""
            string += "["
            var first = true
            for message in messages {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "\(message.id.namespace): \(message.id.id)—\(message.timestamp)"
            }
            string += "]"
            println(string)
        }
        
        func id(namespace: Int32, id: Int32) -> MessageId {
            return MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
        }
        
        func message(namespace: Int32, id: Int32, timestamp: Int32) -> Message {
            let messageId = MessageId(peerId: otherId, namespace: namespace, id: Int32(id))
            return TestMessage(id: messageId, authorId: otherId, date: Int32(timestamp), text: "", referencedMediaIds: [])
        }
        
        messages = [message(2, 1, 1), message(2, 2, 2), message(1, 98, 98), message(1, 99, 99), message(1, 100, 100), message(2, 101, 101), message(1, 102, 102), message(1, 103, 103), message(1, 104, 104), message(1, 105, 105), message(2, 200, 200), message(2, 300, 300)]
        
        let view = MutableMessageView(namespaces: [1, 2], count: 3, earlier: [1: message(1, 99, 99), 2: message(2, 2, 2)], messages: [message(1, 100, 100), message(2, 101, 101), message(1, 102, 102)], later: [1: message(1, 103, 103), 2: message(2, 200, 200)])
        
        func add(message: Message) {
            view.add(message)
            println("\(view)")
            
            messages.append(message)
            messages.sort({MessageIndex($0) < MessageIndex($1)})
            
            print(messages)
            println()
        }
        
        func remove(ids: Set<MessageId>) -> MutableMessageView.RemoveContext {
            let context = view.remove(ids)
            println("\(view)")
            
            messages = messages.filter { !ids.contains($0.id) }
            print(messages)
            
            return context
        }
        
        func fetchEarlier(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = messages.count - 1
            while i >= 0 && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id < id!) {
                    filtered.append(messages[i])
                }
                i--
            }
            
            return filtered
        }
        
        func fetchLater(messages: [Message])(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
            var filtered: [Message] = []
            var i = 0
            while i < messages.count && filtered.count < count {
                if messages[i].id.namespace == namespace && (id == nil || messages[i].id.id > id!) {
                    filtered.append(messages[i])
                }
                i++
            }
            
            return filtered
        }
        
        func complete(context: MutableMessageView.RemoveContext) {
            view.complete(context, fetchEarlier: fetchEarlier(messages), fetchLater: fetchLater(messages))
            println("\(view)\n")
        }
        
        print(messages)
        println("\(view)\n")
        
        println("remove 1:100, 2:101, 1: 102")
        complete(remove([id(1, 100), id(2, 101), id(1, 102)]))
    }
    
    func testViewTail() {
        declareEncodable(TestMessage.self, { TestMessage(decoder: $0) })
        declareEncodable(TestMedia.self, { TestMedia(decoder: $0) })
        
        let ownerId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 1000)
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        let messageNamespace = TestMessageNamespace.Cloud.rawValue
        
        let basePath = "/tmp/postboxtest"
        NSFileManager.defaultManager().removeItemAtPath(basePath, error: nil)
        let postbox = Postbox<EmptyState>(basePath: basePath, messageNamespaces: [messageNamespace])
        
        (postbox.modify { state -> Void in
            let testMedia = TestMedia(id: MediaId(namespace: TestMediaNamespace.Test.rawValue, id: 1))
            for i in 0 ..< 10 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: ownerId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            return
        }).start()
        
        postbox.tailMessageViewForPeerId(otherId, count: 4).start(next: { next in
            println(next)
        })
        
        (postbox.modify { state -> Void in
            let testMedia = TestMedia(id: MediaId(namespace: TestMediaNamespace.Test.rawValue, id: 1))
            for i in 10 ..< 15 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: ownerId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            return
        }).start()
        
        postbox._sync()
    }
    
    func testViewAround() {
        declareEncodable(TestMessage.self, { TestMessage(decoder: $0) })
        declareEncodable(TestMedia.self, { TestMedia(decoder: $0) })
        
        let ownerId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 1000)
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        let messageNamespaceCloud = TestMessageNamespace.Cloud.rawValue
        let messageNamespaceLocal = TestMessageNamespace.Local.rawValue
        
        let basePath = "/tmp/postboxtest"
        NSFileManager.defaultManager().removeItemAtPath(basePath, error: nil)
        let postbox = Postbox<EmptyState>(basePath: basePath, messageNamespaces: [messageNamespaceCloud, messageNamespaceLocal])
        
        (postbox.modify { state -> Void in
            let testMedia = TestMedia(id: MediaId(namespace: TestMediaNamespace.Test.rawValue, id: 1))
            for i in 0 ..< 10 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespaceCloud, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: ownerId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            for i in 10 ..< 12 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespaceLocal, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: ownerId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            return
        }).start()
        
        var i = 1000
        postbox.aroundMessageViewForPeerId(otherId, id: MessageId(peerId: otherId, namespace: messageNamespaceCloud, id: Int32(i + 1)), count: 3).start(next: { next in
            println(next)
        })
        
        (postbox.modify { state -> Void in
            let testMedia = TestMedia(id: MediaId(namespace: TestMediaNamespace.Test.rawValue, id: 1))
            for i in 10 ..< 15 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespaceCloud, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: ownerId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            return
        }).start()
        
        postbox._sync()
    }
    
    func testPeerView() {
        let view = MutablePeerView(count: 3, earlier: nil, entries: [], later: nil)
        let messageNamespaceCloud = TestMessageNamespace.Cloud.rawValue
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        
        var entries: [PeerViewEntry] = []
        
        func print(entries: [PeerViewEntry]) {
            var string = ""
            string += "["
            var first = true
            for entry in entries {
                if first {
                    first = false
                } else {
                    string += ", "
                }
                string += "(p \(entry.peerId.namespace):\(entry.peerId.id), m \(entry.message.id.namespace):\(entry.message.id.id)—\(entry.message.timestamp))"
            }
            string += "]"
            println("\(string)")
        }
        
        func add(entry: PeerViewEntry) {
            entries.append(entry)
            entries.sort({ PeerViewEntryIndex($0) < PeerViewEntryIndex($1) })
            
            view.addEntry(entry)
            
            println("\n\(view)")
            print(entries)
        }
        
        func remove(peerId: PeerId, context: MutablePeerView.RemoveContext? = nil) -> MutablePeerView.RemoveContext {
            entries = entries.filter({ $0.peerId != peerId })
            return view.removeEntry(context, peerId: peerId)
        }
        
        func fetchEarlier(entries: [PeerViewEntry])(index: PeerViewEntryIndex?, count: Int) -> [PeerViewEntry] {
            var filtered: [PeerViewEntry] = []
            var i = entries.count - 1
            while i >= 0 && filtered.count < count {
                if index == nil || PeerViewEntryIndex(entries[i]) < index! {
                    filtered.append(entries[i])
                }
                i--
            }
            
            return filtered
        }
        
        func fetchLater(entries: [PeerViewEntry])(index: PeerViewEntryIndex?, count: Int) -> [PeerViewEntry] {
            var filtered: [PeerViewEntry] = []
            var i = 0
            while i < entries.count && filtered.count < count {
                if index == nil || PeerViewEntryIndex(entries[i]) > index! {
                    filtered.append(entries[i])
                }
                i++
            }
            
            return filtered
        }
        
        func complete(context: MutablePeerView.RemoveContext) {
            view.complete(context, fetchEarlier: fetchEarlier(entries), fetchLater: fetchLater(entries))
        }
        
        println("\(view)")
        
        for i in 1 ..< 10 {
            let messageId = MessageId(peerId: otherId, namespace: messageNamespaceCloud, id: Int32(i * 2 * 100))
            let message = TestMessage(id: messageId, authorId: otherId, date: Int32(i * 2 * 100), text: "\(i)", referencedMediaIds: [])
            
            add(PeerViewEntry(peer: TestPeer(id: PeerId(namespace: TestPeerNamespace.User.rawValue, id: Int32(i * 2))), message: message))
        }
        
        if true {
            let i = 15
            let messageId = MessageId(peerId: otherId, namespace: messageNamespaceCloud, id: Int32(i * 100))
            let message = TestMessage(id: messageId, authorId: otherId, date: Int32(i * 100), text: "\(i)", referencedMediaIds: [])
            
            add(PeerViewEntry(peer: TestPeer(id: PeerId(namespace: TestPeerNamespace.User.rawValue, id: Int32(i))), message: message))
        }
        
        if true {
            var context = remove(PeerId(namespace: TestPeerNamespace.User.rawValue, id: Int32(15)))
            context = remove(PeerId(namespace: TestPeerNamespace.User.rawValue, id: Int32(14)), context: context)
            context = remove(PeerId(namespace: TestPeerNamespace.User.rawValue, id: Int32(16)), context: context)
            context = remove(PeerId(namespace: TestPeerNamespace.User.rawValue, id: Int32(18)), context: context)
            println("\n\(view)")
            print(entries)
            complete(context)
            println("\(view)")
        }
    }
    
    func testPeerViewTail() {
        declareEncodable(TestMessage.self, { TestMessage(decoder: $0) })
        declareEncodable(TestMedia.self, { TestMedia(decoder: $0) })
        
        let otherId = PeerId(namespace: TestPeerNamespace.User.rawValue, id: 2000)
        let messageNamespace = TestMessageNamespace.Cloud.rawValue
        
        let basePath = "/tmp/postboxtest"
        NSFileManager.defaultManager().removeItemAtPath(basePath, error: nil)
        let postbox = Postbox<EmptyState>(basePath: basePath, messageNamespaces: [messageNamespace])
        
        (postbox.modify { state -> Void in
            let testMedia = TestMedia(id: MediaId(namespace: TestMediaNamespace.Test.rawValue, id: 1))
            for i in 0 ..< 10 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: otherId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            return
        }).start()
        
        postbox.tailPeerView(3).start(next: { next in
            println(next)
        })
        
        postbox.tailMessageViewForPeerId(otherId, count: 4).start(next: { next in
            println(next)
        })
        
        (postbox.modify { state -> Void in
            let testMedia = TestMedia(id: MediaId(namespace: TestMediaNamespace.Test.rawValue, id: 1))
            for i in 10 ..< 15 {
                let messageId = MessageId(peerId: otherId, namespace: messageNamespace, id: Int32(i + 1))
                let message = TestMessage(id: messageId, authorId: otherId, date: Int32(i + 100), text: "\(i)", referencedMediaIds: [testMedia.id])
                state.addMessages([message, message], medias: [testMedia])
            }
            return
        }).start()
        
        postbox._sync()
    }
}
