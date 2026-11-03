import Foundation
import Display
import TelegramCore

public enum ChatHistoryInitialSearchLocation: Equatable {
    case index(EngineMessage.Index)
    case id(EngineMessage.Id)
}

public struct MessageHistoryScrollToSubject: Equatable {
    public struct Quote: Equatable {
        public var string: String
        public var offset: Int?
        
        public init(string: String, offset: Int?) {
            self.string = string
            self.offset = offset
        }
    }
    
    public var index: EngineMessageHistoryAnchorIndex
    public var quote: Quote?
    public var subject: EngineMessageReplyInnerSubject?
    public var setupReply: Bool
    
    public init(index: EngineMessageHistoryAnchorIndex, quote: Quote? = nil, subject: EngineMessageReplyInnerSubject? = nil, setupReply: Bool = false) {
        self.index = index
        self.quote = quote
        self.subject = subject
        self.setupReply = setupReply
    }
}

public struct MessageHistoryInitialSearchSubject: Equatable {
    public struct Quote: Equatable {
        public var string: String
        public var offset: Int?
        
        public init(string: String, offset: Int?) {
            self.string = string
            self.offset = offset
        }
    }
    
    public var location: ChatHistoryInitialSearchLocation
    public var quote: Quote?
    public var subject: EngineMessageReplyInnerSubject?
    
    public init(location: ChatHistoryInitialSearchLocation, quote: Quote? = nil, subject: EngineMessageReplyInnerSubject? = nil) {
        self.location = location
        self.quote = quote
        self.subject = subject
    }
}

public enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(subject: MessageHistoryInitialSearchSubject, count: Int, highlight: Bool, setupReply: Bool, cachedAnchor: Bool = false)
    case Navigation(index: EngineMessageHistoryAnchorIndex, anchorIndex: EngineMessageHistoryAnchorIndex, count: Int, highlight: Bool)
    case Scroll(subject: MessageHistoryScrollToSubject, anchorIndex: EngineMessageHistoryAnchorIndex, sourceIndex: EngineMessageHistoryAnchorIndex, scrollPosition: ListViewScrollPosition, animated: Bool, highlight: Bool, setupReply: Bool)
}

public struct ChatHistoryLocationInput: Equatable {
    public var content: ChatHistoryLocation
    public var id: Int32
    
    public init(content: ChatHistoryLocation, id: Int32) {
        self.content = content
        self.id = id
    }
}
