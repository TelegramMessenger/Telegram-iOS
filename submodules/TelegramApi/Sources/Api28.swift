public extension Api {
    enum TopPeerCategoryPeers: TypeConstructorDescription {
        public class Cons_topPeerCategoryPeers: TypeConstructorDescription {
            public var category: Api.TopPeerCategory
            public var count: Int32
            public var peers: [Api.TopPeer]
            public init(category: Api.TopPeerCategory, count: Int32, peers: [Api.TopPeer]) {
                self.category = category
                self.count = count
                self.peers = peers
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("topPeerCategoryPeers", [("category", self.category as Any), ("count", self.count as Any), ("peers", self.peers as Any)])
            }
        }
        case topPeerCategoryPeers(Cons_topPeerCategoryPeers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .topPeerCategoryPeers(let _data):
                if boxed {
                    buffer.appendInt32(-75283823)
                }
                _data.category.serialize(buffer, true)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .topPeerCategoryPeers(let _data):
                return ("topPeerCategoryPeers", [("category", _data.category as Any), ("count", _data.count as Any), ("peers", _data.peers as Any)])
            }
        }

        public static func parse_topPeerCategoryPeers(_ reader: BufferReader) -> TopPeerCategoryPeers? {
            var _1: Api.TopPeerCategory?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TopPeerCategory
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.TopPeer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TopPeer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.TopPeerCategoryPeers.topPeerCategoryPeers(Cons_topPeerCategoryPeers(category: _1!, count: _2!, peers: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum Update: TypeConstructorDescription {
        public class Cons_updateBotBusinessConnect: TypeConstructorDescription {
            public var connection: Api.BotBusinessConnection
            public var qts: Int32
            public init(connection: Api.BotBusinessConnection, qts: Int32) {
                self.connection = connection
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotBusinessConnect", [("connection", self.connection as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotCallbackQuery: TypeConstructorDescription {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var peer: Api.Peer
            public var msgId: Int32
            public var chatInstance: Int64
            public var data: Buffer?
            public var gameShortName: String?
            public init(flags: Int32, queryId: Int64, userId: Int64, peer: Api.Peer, msgId: Int32, chatInstance: Int64, data: Buffer?, gameShortName: String?) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.peer = peer
                self.msgId = msgId
                self.chatInstance = chatInstance
                self.data = data
                self.gameShortName = gameShortName
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotCallbackQuery", [("flags", self.flags as Any), ("queryId", self.queryId as Any), ("userId", self.userId as Any), ("peer", self.peer as Any), ("msgId", self.msgId as Any), ("chatInstance", self.chatInstance as Any), ("data", self.data as Any), ("gameShortName", self.gameShortName as Any)])
            }
        }
        public class Cons_updateBotChatBoost: TypeConstructorDescription {
            public var peer: Api.Peer
            public var boost: Api.Boost
            public var qts: Int32
            public init(peer: Api.Peer, boost: Api.Boost, qts: Int32) {
                self.peer = peer
                self.boost = boost
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotChatBoost", [("peer", self.peer as Any), ("boost", self.boost as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotChatInviteRequester: TypeConstructorDescription {
            public var peer: Api.Peer
            public var date: Int32
            public var userId: Int64
            public var about: String
            public var invite: Api.ExportedChatInvite
            public var qts: Int32
            public init(peer: Api.Peer, date: Int32, userId: Int64, about: String, invite: Api.ExportedChatInvite, qts: Int32) {
                self.peer = peer
                self.date = date
                self.userId = userId
                self.about = about
                self.invite = invite
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotChatInviteRequester", [("peer", self.peer as Any), ("date", self.date as Any), ("userId", self.userId as Any), ("about", self.about as Any), ("invite", self.invite as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotCommands: TypeConstructorDescription {
            public var peer: Api.Peer
            public var botId: Int64
            public var commands: [Api.BotCommand]
            public init(peer: Api.Peer, botId: Int64, commands: [Api.BotCommand]) {
                self.peer = peer
                self.botId = botId
                self.commands = commands
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotCommands", [("peer", self.peer as Any), ("botId", self.botId as Any), ("commands", self.commands as Any)])
            }
        }
        public class Cons_updateBotDeleteBusinessMessage: TypeConstructorDescription {
            public var connectionId: String
            public var peer: Api.Peer
            public var messages: [Int32]
            public var qts: Int32
            public init(connectionId: String, peer: Api.Peer, messages: [Int32], qts: Int32) {
                self.connectionId = connectionId
                self.peer = peer
                self.messages = messages
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotDeleteBusinessMessage", [("connectionId", self.connectionId as Any), ("peer", self.peer as Any), ("messages", self.messages as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotEditBusinessMessage: TypeConstructorDescription {
            public var flags: Int32
            public var connectionId: String
            public var message: Api.Message
            public var replyToMessage: Api.Message?
            public var qts: Int32
            public init(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32) {
                self.flags = flags
                self.connectionId = connectionId
                self.message = message
                self.replyToMessage = replyToMessage
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotEditBusinessMessage", [("flags", self.flags as Any), ("connectionId", self.connectionId as Any), ("message", self.message as Any), ("replyToMessage", self.replyToMessage as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotInlineQuery: TypeConstructorDescription {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var query: String
            public var geo: Api.GeoPoint?
            public var peerType: Api.InlineQueryPeerType?
            public var offset: String
            public init(flags: Int32, queryId: Int64, userId: Int64, query: String, geo: Api.GeoPoint?, peerType: Api.InlineQueryPeerType?, offset: String) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.query = query
                self.geo = geo
                self.peerType = peerType
                self.offset = offset
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotInlineQuery", [("flags", self.flags as Any), ("queryId", self.queryId as Any), ("userId", self.userId as Any), ("query", self.query as Any), ("geo", self.geo as Any), ("peerType", self.peerType as Any), ("offset", self.offset as Any)])
            }
        }
        public class Cons_updateBotInlineSend: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Int64
            public var query: String
            public var geo: Api.GeoPoint?
            public var id: String
            public var msgId: Api.InputBotInlineMessageID?
            public init(flags: Int32, userId: Int64, query: String, geo: Api.GeoPoint?, id: String, msgId: Api.InputBotInlineMessageID?) {
                self.flags = flags
                self.userId = userId
                self.query = query
                self.geo = geo
                self.id = id
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotInlineSend", [("flags", self.flags as Any), ("userId", self.userId as Any), ("query", self.query as Any), ("geo", self.geo as Any), ("id", self.id as Any), ("msgId", self.msgId as Any)])
            }
        }
        public class Cons_updateBotMenuButton: TypeConstructorDescription {
            public var botId: Int64
            public var button: Api.BotMenuButton
            public init(botId: Int64, button: Api.BotMenuButton) {
                self.botId = botId
                self.button = button
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotMenuButton", [("botId", self.botId as Any), ("button", self.button as Any)])
            }
        }
        public class Cons_updateBotMessageReaction: TypeConstructorDescription {
            public var peer: Api.Peer
            public var msgId: Int32
            public var date: Int32
            public var actor: Api.Peer
            public var oldReactions: [Api.Reaction]
            public var newReactions: [Api.Reaction]
            public var qts: Int32
            public init(peer: Api.Peer, msgId: Int32, date: Int32, actor: Api.Peer, oldReactions: [Api.Reaction], newReactions: [Api.Reaction], qts: Int32) {
                self.peer = peer
                self.msgId = msgId
                self.date = date
                self.actor = actor
                self.oldReactions = oldReactions
                self.newReactions = newReactions
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotMessageReaction", [("peer", self.peer as Any), ("msgId", self.msgId as Any), ("date", self.date as Any), ("actor", self.actor as Any), ("oldReactions", self.oldReactions as Any), ("newReactions", self.newReactions as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotMessageReactions: TypeConstructorDescription {
            public var peer: Api.Peer
            public var msgId: Int32
            public var date: Int32
            public var reactions: [Api.ReactionCount]
            public var qts: Int32
            public init(peer: Api.Peer, msgId: Int32, date: Int32, reactions: [Api.ReactionCount], qts: Int32) {
                self.peer = peer
                self.msgId = msgId
                self.date = date
                self.reactions = reactions
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotMessageReactions", [("peer", self.peer as Any), ("msgId", self.msgId as Any), ("date", self.date as Any), ("reactions", self.reactions as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotNewBusinessMessage: TypeConstructorDescription {
            public var flags: Int32
            public var connectionId: String
            public var message: Api.Message
            public var replyToMessage: Api.Message?
            public var qts: Int32
            public init(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32) {
                self.flags = flags
                self.connectionId = connectionId
                self.message = message
                self.replyToMessage = replyToMessage
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotNewBusinessMessage", [("flags", self.flags as Any), ("connectionId", self.connectionId as Any), ("message", self.message as Any), ("replyToMessage", self.replyToMessage as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotPrecheckoutQuery: TypeConstructorDescription {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var payload: Buffer
            public var info: Api.PaymentRequestedInfo?
            public var shippingOptionId: String?
            public var currency: String
            public var totalAmount: Int64
            public init(flags: Int32, queryId: Int64, userId: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, currency: String, totalAmount: Int64) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.payload = payload
                self.info = info
                self.shippingOptionId = shippingOptionId
                self.currency = currency
                self.totalAmount = totalAmount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotPrecheckoutQuery", [("flags", self.flags as Any), ("queryId", self.queryId as Any), ("userId", self.userId as Any), ("payload", self.payload as Any), ("info", self.info as Any), ("shippingOptionId", self.shippingOptionId as Any), ("currency", self.currency as Any), ("totalAmount", self.totalAmount as Any)])
            }
        }
        public class Cons_updateBotPurchasedPaidMedia: TypeConstructorDescription {
            public var userId: Int64
            public var payload: String
            public var qts: Int32
            public init(userId: Int64, payload: String, qts: Int32) {
                self.userId = userId
                self.payload = payload
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotPurchasedPaidMedia", [("userId", self.userId as Any), ("payload", self.payload as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotShippingQuery: TypeConstructorDescription {
            public var queryId: Int64
            public var userId: Int64
            public var payload: Buffer
            public var shippingAddress: Api.PostAddress
            public init(queryId: Int64, userId: Int64, payload: Buffer, shippingAddress: Api.PostAddress) {
                self.queryId = queryId
                self.userId = userId
                self.payload = payload
                self.shippingAddress = shippingAddress
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotShippingQuery", [("queryId", self.queryId as Any), ("userId", self.userId as Any), ("payload", self.payload as Any), ("shippingAddress", self.shippingAddress as Any)])
            }
        }
        public class Cons_updateBotStopped: TypeConstructorDescription {
            public var userId: Int64
            public var date: Int32
            public var stopped: Api.Bool
            public var qts: Int32
            public init(userId: Int64, date: Int32, stopped: Api.Bool, qts: Int32) {
                self.userId = userId
                self.date = date
                self.stopped = stopped
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotStopped", [("userId", self.userId as Any), ("date", self.date as Any), ("stopped", self.stopped as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateBotWebhookJSON: TypeConstructorDescription {
            public var data: Api.DataJSON
            public init(data: Api.DataJSON) {
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotWebhookJSON", [("data", self.data as Any)])
            }
        }
        public class Cons_updateBotWebhookJSONQuery: TypeConstructorDescription {
            public var queryId: Int64
            public var data: Api.DataJSON
            public var timeout: Int32
            public init(queryId: Int64, data: Api.DataJSON, timeout: Int32) {
                self.queryId = queryId
                self.data = data
                self.timeout = timeout
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBotWebhookJSONQuery", [("queryId", self.queryId as Any), ("data", self.data as Any), ("timeout", self.timeout as Any)])
            }
        }
        public class Cons_updateBusinessBotCallbackQuery: TypeConstructorDescription {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var connectionId: String
            public var message: Api.Message
            public var replyToMessage: Api.Message?
            public var chatInstance: Int64
            public var data: Buffer?
            public init(flags: Int32, queryId: Int64, userId: Int64, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, chatInstance: Int64, data: Buffer?) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.connectionId = connectionId
                self.message = message
                self.replyToMessage = replyToMessage
                self.chatInstance = chatInstance
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateBusinessBotCallbackQuery", [("flags", self.flags as Any), ("queryId", self.queryId as Any), ("userId", self.userId as Any), ("connectionId", self.connectionId as Any), ("message", self.message as Any), ("replyToMessage", self.replyToMessage as Any), ("chatInstance", self.chatInstance as Any), ("data", self.data as Any)])
            }
        }
        public class Cons_updateChannel: TypeConstructorDescription {
            public var channelId: Int64
            public init(channelId: Int64) {
                self.channelId = channelId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannel", [("channelId", self.channelId as Any)])
            }
        }
        public class Cons_updateChannelAvailableMessages: TypeConstructorDescription {
            public var channelId: Int64
            public var availableMinId: Int32
            public init(channelId: Int64, availableMinId: Int32) {
                self.channelId = channelId
                self.availableMinId = availableMinId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelAvailableMessages", [("channelId", self.channelId as Any), ("availableMinId", self.availableMinId as Any)])
            }
        }
        public class Cons_updateChannelMessageForwards: TypeConstructorDescription {
            public var channelId: Int64
            public var id: Int32
            public var forwards: Int32
            public init(channelId: Int64, id: Int32, forwards: Int32) {
                self.channelId = channelId
                self.id = id
                self.forwards = forwards
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelMessageForwards", [("channelId", self.channelId as Any), ("id", self.id as Any), ("forwards", self.forwards as Any)])
            }
        }
        public class Cons_updateChannelMessageViews: TypeConstructorDescription {
            public var channelId: Int64
            public var id: Int32
            public var views: Int32
            public init(channelId: Int64, id: Int32, views: Int32) {
                self.channelId = channelId
                self.id = id
                self.views = views
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelMessageViews", [("channelId", self.channelId as Any), ("id", self.id as Any), ("views", self.views as Any)])
            }
        }
        public class Cons_updateChannelParticipant: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var date: Int32
            public var actorId: Int64
            public var userId: Int64
            public var prevParticipant: Api.ChannelParticipant?
            public var newParticipant: Api.ChannelParticipant?
            public var invite: Api.ExportedChatInvite?
            public var qts: Int32
            public init(flags: Int32, channelId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChannelParticipant?, newParticipant: Api.ChannelParticipant?, invite: Api.ExportedChatInvite?, qts: Int32) {
                self.flags = flags
                self.channelId = channelId
                self.date = date
                self.actorId = actorId
                self.userId = userId
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
                self.invite = invite
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelParticipant", [("flags", self.flags as Any), ("channelId", self.channelId as Any), ("date", self.date as Any), ("actorId", self.actorId as Any), ("userId", self.userId as Any), ("prevParticipant", self.prevParticipant as Any), ("newParticipant", self.newParticipant as Any), ("invite", self.invite as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateChannelReadMessagesContents: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var topMsgId: Int32?
            public var savedPeerId: Api.Peer?
            public var messages: [Int32]
            public init(flags: Int32, channelId: Int64, topMsgId: Int32?, savedPeerId: Api.Peer?, messages: [Int32]) {
                self.flags = flags
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.savedPeerId = savedPeerId
                self.messages = messages
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelReadMessagesContents", [("flags", self.flags as Any), ("channelId", self.channelId as Any), ("topMsgId", self.topMsgId as Any), ("savedPeerId", self.savedPeerId as Any), ("messages", self.messages as Any)])
            }
        }
        public class Cons_updateChannelTooLong: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var pts: Int32?
            public init(flags: Int32, channelId: Int64, pts: Int32?) {
                self.flags = flags
                self.channelId = channelId
                self.pts = pts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelTooLong", [("flags", self.flags as Any), ("channelId", self.channelId as Any), ("pts", self.pts as Any)])
            }
        }
        public class Cons_updateChannelUserTyping: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var topMsgId: Int32?
            public var fromId: Api.Peer
            public var action: Api.SendMessageAction
            public init(flags: Int32, channelId: Int64, topMsgId: Int32?, fromId: Api.Peer, action: Api.SendMessageAction) {
                self.flags = flags
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.fromId = fromId
                self.action = action
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelUserTyping", [("flags", self.flags as Any), ("channelId", self.channelId as Any), ("topMsgId", self.topMsgId as Any), ("fromId", self.fromId as Any), ("action", self.action as Any)])
            }
        }
        public class Cons_updateChannelViewForumAsMessages: TypeConstructorDescription {
            public var channelId: Int64
            public var enabled: Api.Bool
            public init(channelId: Int64, enabled: Api.Bool) {
                self.channelId = channelId
                self.enabled = enabled
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelViewForumAsMessages", [("channelId", self.channelId as Any), ("enabled", self.enabled as Any)])
            }
        }
        public class Cons_updateChannelWebPage: TypeConstructorDescription {
            public var channelId: Int64
            public var webpage: Api.WebPage
            public var pts: Int32
            public var ptsCount: Int32
            public init(channelId: Int64, webpage: Api.WebPage, pts: Int32, ptsCount: Int32) {
                self.channelId = channelId
                self.webpage = webpage
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChannelWebPage", [("channelId", self.channelId as Any), ("webpage", self.webpage as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateChat: TypeConstructorDescription {
            public var chatId: Int64
            public init(chatId: Int64) {
                self.chatId = chatId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChat", [("chatId", self.chatId as Any)])
            }
        }
        public class Cons_updateChatDefaultBannedRights: TypeConstructorDescription {
            public var peer: Api.Peer
            public var defaultBannedRights: Api.ChatBannedRights
            public var version: Int32
            public init(peer: Api.Peer, defaultBannedRights: Api.ChatBannedRights, version: Int32) {
                self.peer = peer
                self.defaultBannedRights = defaultBannedRights
                self.version = version
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatDefaultBannedRights", [("peer", self.peer as Any), ("defaultBannedRights", self.defaultBannedRights as Any), ("version", self.version as Any)])
            }
        }
        public class Cons_updateChatParticipant: TypeConstructorDescription {
            public var flags: Int32
            public var chatId: Int64
            public var date: Int32
            public var actorId: Int64
            public var userId: Int64
            public var prevParticipant: Api.ChatParticipant?
            public var newParticipant: Api.ChatParticipant?
            public var invite: Api.ExportedChatInvite?
            public var qts: Int32
            public init(flags: Int32, chatId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChatParticipant?, newParticipant: Api.ChatParticipant?, invite: Api.ExportedChatInvite?, qts: Int32) {
                self.flags = flags
                self.chatId = chatId
                self.date = date
                self.actorId = actorId
                self.userId = userId
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
                self.invite = invite
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatParticipant", [("flags", self.flags as Any), ("chatId", self.chatId as Any), ("date", self.date as Any), ("actorId", self.actorId as Any), ("userId", self.userId as Any), ("prevParticipant", self.prevParticipant as Any), ("newParticipant", self.newParticipant as Any), ("invite", self.invite as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateChatParticipantAdd: TypeConstructorDescription {
            public var chatId: Int64
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public var version: Int32
            public init(chatId: Int64, userId: Int64, inviterId: Int64, date: Int32, version: Int32) {
                self.chatId = chatId
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
                self.version = version
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatParticipantAdd", [("chatId", self.chatId as Any), ("userId", self.userId as Any), ("inviterId", self.inviterId as Any), ("date", self.date as Any), ("version", self.version as Any)])
            }
        }
        public class Cons_updateChatParticipantAdmin: TypeConstructorDescription {
            public var chatId: Int64
            public var userId: Int64
            public var isAdmin: Api.Bool
            public var version: Int32
            public init(chatId: Int64, userId: Int64, isAdmin: Api.Bool, version: Int32) {
                self.chatId = chatId
                self.userId = userId
                self.isAdmin = isAdmin
                self.version = version
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatParticipantAdmin", [("chatId", self.chatId as Any), ("userId", self.userId as Any), ("isAdmin", self.isAdmin as Any), ("version", self.version as Any)])
            }
        }
        public class Cons_updateChatParticipantDelete: TypeConstructorDescription {
            public var chatId: Int64
            public var userId: Int64
            public var version: Int32
            public init(chatId: Int64, userId: Int64, version: Int32) {
                self.chatId = chatId
                self.userId = userId
                self.version = version
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatParticipantDelete", [("chatId", self.chatId as Any), ("userId", self.userId as Any), ("version", self.version as Any)])
            }
        }
        public class Cons_updateChatParticipantRank: TypeConstructorDescription {
            public var chatId: Int64
            public var userId: Int64
            public var rank: String
            public var version: Int32
            public init(chatId: Int64, userId: Int64, rank: String, version: Int32) {
                self.chatId = chatId
                self.userId = userId
                self.rank = rank
                self.version = version
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatParticipantRank", [("chatId", self.chatId as Any), ("userId", self.userId as Any), ("rank", self.rank as Any), ("version", self.version as Any)])
            }
        }
        public class Cons_updateChatParticipants: TypeConstructorDescription {
            public var participants: Api.ChatParticipants
            public init(participants: Api.ChatParticipants) {
                self.participants = participants
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatParticipants", [("participants", self.participants as Any)])
            }
        }
        public class Cons_updateChatUserTyping: TypeConstructorDescription {
            public var chatId: Int64
            public var fromId: Api.Peer
            public var action: Api.SendMessageAction
            public init(chatId: Int64, fromId: Api.Peer, action: Api.SendMessageAction) {
                self.chatId = chatId
                self.fromId = fromId
                self.action = action
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateChatUserTyping", [("chatId", self.chatId as Any), ("fromId", self.fromId as Any), ("action", self.action as Any)])
            }
        }
        public class Cons_updateDcOptions: TypeConstructorDescription {
            public var dcOptions: [Api.DcOption]
            public init(dcOptions: [Api.DcOption]) {
                self.dcOptions = dcOptions
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDcOptions", [("dcOptions", self.dcOptions as Any)])
            }
        }
        public class Cons_updateDeleteChannelMessages: TypeConstructorDescription {
            public var channelId: Int64
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.channelId = channelId
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDeleteChannelMessages", [("channelId", self.channelId as Any), ("messages", self.messages as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateDeleteGroupCallMessages: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public var messages: [Int32]
            public init(call: Api.InputGroupCall, messages: [Int32]) {
                self.call = call
                self.messages = messages
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDeleteGroupCallMessages", [("call", self.call as Any), ("messages", self.messages as Any)])
            }
        }
        public class Cons_updateDeleteMessages: TypeConstructorDescription {
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDeleteMessages", [("messages", self.messages as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateDeleteQuickReply: TypeConstructorDescription {
            public var shortcutId: Int32
            public init(shortcutId: Int32) {
                self.shortcutId = shortcutId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDeleteQuickReply", [("shortcutId", self.shortcutId as Any)])
            }
        }
        public class Cons_updateDeleteQuickReplyMessages: TypeConstructorDescription {
            public var shortcutId: Int32
            public var messages: [Int32]
            public init(shortcutId: Int32, messages: [Int32]) {
                self.shortcutId = shortcutId
                self.messages = messages
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDeleteQuickReplyMessages", [("shortcutId", self.shortcutId as Any), ("messages", self.messages as Any)])
            }
        }
        public class Cons_updateDeleteScheduledMessages: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var messages: [Int32]
            public var sentMessages: [Int32]?
            public init(flags: Int32, peer: Api.Peer, messages: [Int32], sentMessages: [Int32]?) {
                self.flags = flags
                self.peer = peer
                self.messages = messages
                self.sentMessages = sentMessages
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDeleteScheduledMessages", [("flags", self.flags as Any), ("peer", self.peer as Any), ("messages", self.messages as Any), ("sentMessages", self.sentMessages as Any)])
            }
        }
        public class Cons_updateDialogFilter: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var filter: Api.DialogFilter?
            public init(flags: Int32, id: Int32, filter: Api.DialogFilter?) {
                self.flags = flags
                self.id = id
                self.filter = filter
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDialogFilter", [("flags", self.flags as Any), ("id", self.id as Any), ("filter", self.filter as Any)])
            }
        }
        public class Cons_updateDialogFilterOrder: TypeConstructorDescription {
            public var order: [Int32]
            public init(order: [Int32]) {
                self.order = order
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDialogFilterOrder", [("order", self.order as Any)])
            }
        }
        public class Cons_updateDialogPinned: TypeConstructorDescription {
            public var flags: Int32
            public var folderId: Int32?
            public var peer: Api.DialogPeer
            public init(flags: Int32, folderId: Int32?, peer: Api.DialogPeer) {
                self.flags = flags
                self.folderId = folderId
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDialogPinned", [("flags", self.flags as Any), ("folderId", self.folderId as Any), ("peer", self.peer as Any)])
            }
        }
        public class Cons_updateDialogUnreadMark: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.DialogPeer
            public var savedPeerId: Api.Peer?
            public init(flags: Int32, peer: Api.DialogPeer, savedPeerId: Api.Peer?) {
                self.flags = flags
                self.peer = peer
                self.savedPeerId = savedPeerId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDialogUnreadMark", [("flags", self.flags as Any), ("peer", self.peer as Any), ("savedPeerId", self.savedPeerId as Any)])
            }
        }
        public class Cons_updateDraftMessage: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMsgId: Int32?
            public var savedPeerId: Api.Peer?
            public var draft: Api.DraftMessage
            public init(flags: Int32, peer: Api.Peer, topMsgId: Int32?, savedPeerId: Api.Peer?, draft: Api.DraftMessage) {
                self.flags = flags
                self.peer = peer
                self.topMsgId = topMsgId
                self.savedPeerId = savedPeerId
                self.draft = draft
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateDraftMessage", [("flags", self.flags as Any), ("peer", self.peer as Any), ("topMsgId", self.topMsgId as Any), ("savedPeerId", self.savedPeerId as Any), ("draft", self.draft as Any)])
            }
        }
        public class Cons_updateEditChannelMessage: TypeConstructorDescription {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateEditChannelMessage", [("message", self.message as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateEditMessage: TypeConstructorDescription {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateEditMessage", [("message", self.message as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateEmojiGameInfo: TypeConstructorDescription {
            public var info: Api.messages.EmojiGameInfo
            public init(info: Api.messages.EmojiGameInfo) {
                self.info = info
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateEmojiGameInfo", [("info", self.info as Any)])
            }
        }
        public class Cons_updateEncryptedChatTyping: TypeConstructorDescription {
            public var chatId: Int32
            public init(chatId: Int32) {
                self.chatId = chatId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateEncryptedChatTyping", [("chatId", self.chatId as Any)])
            }
        }
        public class Cons_updateEncryptedMessagesRead: TypeConstructorDescription {
            public var chatId: Int32
            public var maxDate: Int32
            public var date: Int32
            public init(chatId: Int32, maxDate: Int32, date: Int32) {
                self.chatId = chatId
                self.maxDate = maxDate
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateEncryptedMessagesRead", [("chatId", self.chatId as Any), ("maxDate", self.maxDate as Any), ("date", self.date as Any)])
            }
        }
        public class Cons_updateEncryption: TypeConstructorDescription {
            public var chat: Api.EncryptedChat
            public var date: Int32
            public init(chat: Api.EncryptedChat, date: Int32) {
                self.chat = chat
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateEncryption", [("chat", self.chat as Any), ("date", self.date as Any)])
            }
        }
        public class Cons_updateFolderPeers: TypeConstructorDescription {
            public var folderPeers: [Api.FolderPeer]
            public var pts: Int32
            public var ptsCount: Int32
            public init(folderPeers: [Api.FolderPeer], pts: Int32, ptsCount: Int32) {
                self.folderPeers = folderPeers
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateFolderPeers", [("folderPeers", self.folderPeers as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateGeoLiveViewed: TypeConstructorDescription {
            public var peer: Api.Peer
            public var msgId: Int32
            public init(peer: Api.Peer, msgId: Int32) {
                self.peer = peer
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateGeoLiveViewed", [("peer", self.peer as Any), ("msgId", self.msgId as Any)])
            }
        }
        public class Cons_updateGroupCall: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer?
            public var call: Api.GroupCall
            public init(flags: Int32, peer: Api.Peer?, call: Api.GroupCall) {
                self.flags = flags
                self.peer = peer
                self.call = call
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateGroupCall", [("flags", self.flags as Any), ("peer", self.peer as Any), ("call", self.call as Any)])
            }
        }
        public class Cons_updateGroupCallChainBlocks: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public var subChainId: Int32
            public var blocks: [Buffer]
            public var nextOffset: Int32
            public init(call: Api.InputGroupCall, subChainId: Int32, blocks: [Buffer], nextOffset: Int32) {
                self.call = call
                self.subChainId = subChainId
                self.blocks = blocks
                self.nextOffset = nextOffset
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateGroupCallChainBlocks", [("call", self.call as Any), ("subChainId", self.subChainId as Any), ("blocks", self.blocks as Any), ("nextOffset", self.nextOffset as Any)])
            }
        }
        public class Cons_updateGroupCallConnection: TypeConstructorDescription {
            public var flags: Int32
            public var params: Api.DataJSON
            public init(flags: Int32, params: Api.DataJSON) {
                self.flags = flags
                self.params = params
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateGroupCallConnection", [("flags", self.flags as Any), ("params", self.params as Any)])
            }
        }
        public class Cons_updateGroupCallEncryptedMessage: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public var fromId: Api.Peer
            public var encryptedMessage: Buffer
            public init(call: Api.InputGroupCall, fromId: Api.Peer, encryptedMessage: Buffer) {
                self.call = call
                self.fromId = fromId
                self.encryptedMessage = encryptedMessage
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateGroupCallEncryptedMessage", [("call", self.call as Any), ("fromId", self.fromId as Any), ("encryptedMessage", self.encryptedMessage as Any)])
            }
        }
        public class Cons_updateGroupCallMessage: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public var message: Api.GroupCallMessage
            public init(call: Api.InputGroupCall, message: Api.GroupCallMessage) {
                self.call = call
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateGroupCallMessage", [("call", self.call as Any), ("message", self.message as Any)])
            }
        }
        public class Cons_updateGroupCallParticipants: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public var participants: [Api.GroupCallParticipant]
            public var version: Int32
            public init(call: Api.InputGroupCall, participants: [Api.GroupCallParticipant], version: Int32) {
                self.call = call
                self.participants = participants
                self.version = version
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateGroupCallParticipants", [("call", self.call as Any), ("participants", self.participants as Any), ("version", self.version as Any)])
            }
        }
        public class Cons_updateInlineBotCallbackQuery: TypeConstructorDescription {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var msgId: Api.InputBotInlineMessageID
            public var chatInstance: Int64
            public var data: Buffer?
            public var gameShortName: String?
            public init(flags: Int32, queryId: Int64, userId: Int64, msgId: Api.InputBotInlineMessageID, chatInstance: Int64, data: Buffer?, gameShortName: String?) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.msgId = msgId
                self.chatInstance = chatInstance
                self.data = data
                self.gameShortName = gameShortName
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateInlineBotCallbackQuery", [("flags", self.flags as Any), ("queryId", self.queryId as Any), ("userId", self.userId as Any), ("msgId", self.msgId as Any), ("chatInstance", self.chatInstance as Any), ("data", self.data as Any), ("gameShortName", self.gameShortName as Any)])
            }
        }
        public class Cons_updateLangPack: TypeConstructorDescription {
            public var difference: Api.LangPackDifference
            public init(difference: Api.LangPackDifference) {
                self.difference = difference
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateLangPack", [("difference", self.difference as Any)])
            }
        }
        public class Cons_updateLangPackTooLong: TypeConstructorDescription {
            public var langCode: String
            public init(langCode: String) {
                self.langCode = langCode
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateLangPackTooLong", [("langCode", self.langCode as Any)])
            }
        }
        public class Cons_updateMessageExtendedMedia: TypeConstructorDescription {
            public var peer: Api.Peer
            public var msgId: Int32
            public var extendedMedia: [Api.MessageExtendedMedia]
            public init(peer: Api.Peer, msgId: Int32, extendedMedia: [Api.MessageExtendedMedia]) {
                self.peer = peer
                self.msgId = msgId
                self.extendedMedia = extendedMedia
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateMessageExtendedMedia", [("peer", self.peer as Any), ("msgId", self.msgId as Any), ("extendedMedia", self.extendedMedia as Any)])
            }
        }
        public class Cons_updateMessageID: TypeConstructorDescription {
            public var id: Int32
            public var randomId: Int64
            public init(id: Int32, randomId: Int64) {
                self.id = id
                self.randomId = randomId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateMessageID", [("id", self.id as Any), ("randomId", self.randomId as Any)])
            }
        }
        public class Cons_updateMessagePoll: TypeConstructorDescription {
            public var flags: Int32
            public var pollId: Int64
            public var poll: Api.Poll?
            public var results: Api.PollResults
            public init(flags: Int32, pollId: Int64, poll: Api.Poll?, results: Api.PollResults) {
                self.flags = flags
                self.pollId = pollId
                self.poll = poll
                self.results = results
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateMessagePoll", [("flags", self.flags as Any), ("pollId", self.pollId as Any), ("poll", self.poll as Any), ("results", self.results as Any)])
            }
        }
        public class Cons_updateMessagePollVote: TypeConstructorDescription {
            public var pollId: Int64
            public var peer: Api.Peer
            public var options: [Buffer]
            public var qts: Int32
            public init(pollId: Int64, peer: Api.Peer, options: [Buffer], qts: Int32) {
                self.pollId = pollId
                self.peer = peer
                self.options = options
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateMessagePollVote", [("pollId", self.pollId as Any), ("peer", self.peer as Any), ("options", self.options as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateMessageReactions: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var msgId: Int32
            public var topMsgId: Int32?
            public var savedPeerId: Api.Peer?
            public var reactions: Api.MessageReactions
            public init(flags: Int32, peer: Api.Peer, msgId: Int32, topMsgId: Int32?, savedPeerId: Api.Peer?, reactions: Api.MessageReactions) {
                self.flags = flags
                self.peer = peer
                self.msgId = msgId
                self.topMsgId = topMsgId
                self.savedPeerId = savedPeerId
                self.reactions = reactions
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateMessageReactions", [("flags", self.flags as Any), ("peer", self.peer as Any), ("msgId", self.msgId as Any), ("topMsgId", self.topMsgId as Any), ("savedPeerId", self.savedPeerId as Any), ("reactions", self.reactions as Any)])
            }
        }
        public class Cons_updateMonoForumNoPaidException: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var savedPeerId: Api.Peer
            public init(flags: Int32, channelId: Int64, savedPeerId: Api.Peer) {
                self.flags = flags
                self.channelId = channelId
                self.savedPeerId = savedPeerId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateMonoForumNoPaidException", [("flags", self.flags as Any), ("channelId", self.channelId as Any), ("savedPeerId", self.savedPeerId as Any)])
            }
        }
        public class Cons_updateMoveStickerSetToTop: TypeConstructorDescription {
            public var flags: Int32
            public var stickerset: Int64
            public init(flags: Int32, stickerset: Int64) {
                self.flags = flags
                self.stickerset = stickerset
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateMoveStickerSetToTop", [("flags", self.flags as Any), ("stickerset", self.stickerset as Any)])
            }
        }
        public class Cons_updateNewAuthorization: TypeConstructorDescription {
            public var flags: Int32
            public var hash: Int64
            public var date: Int32?
            public var device: String?
            public var location: String?
            public init(flags: Int32, hash: Int64, date: Int32?, device: String?, location: String?) {
                self.flags = flags
                self.hash = hash
                self.date = date
                self.device = device
                self.location = location
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewAuthorization", [("flags", self.flags as Any), ("hash", self.hash as Any), ("date", self.date as Any), ("device", self.device as Any), ("location", self.location as Any)])
            }
        }
        public class Cons_updateNewChannelMessage: TypeConstructorDescription {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewChannelMessage", [("message", self.message as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateNewEncryptedMessage: TypeConstructorDescription {
            public var message: Api.EncryptedMessage
            public var qts: Int32
            public init(message: Api.EncryptedMessage, qts: Int32) {
                self.message = message
                self.qts = qts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewEncryptedMessage", [("message", self.message as Any), ("qts", self.qts as Any)])
            }
        }
        public class Cons_updateNewMessage: TypeConstructorDescription {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewMessage", [("message", self.message as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateNewQuickReply: TypeConstructorDescription {
            public var quickReply: Api.QuickReply
            public init(quickReply: Api.QuickReply) {
                self.quickReply = quickReply
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewQuickReply", [("quickReply", self.quickReply as Any)])
            }
        }
        public class Cons_updateNewScheduledMessage: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewScheduledMessage", [("message", self.message as Any)])
            }
        }
        public class Cons_updateNewStickerSet: TypeConstructorDescription {
            public var stickerset: Api.messages.StickerSet
            public init(stickerset: Api.messages.StickerSet) {
                self.stickerset = stickerset
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewStickerSet", [("stickerset", self.stickerset as Any)])
            }
        }
        public class Cons_updateNewStoryReaction: TypeConstructorDescription {
            public var storyId: Int32
            public var peer: Api.Peer
            public var reaction: Api.Reaction
            public init(storyId: Int32, peer: Api.Peer, reaction: Api.Reaction) {
                self.storyId = storyId
                self.peer = peer
                self.reaction = reaction
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNewStoryReaction", [("storyId", self.storyId as Any), ("peer", self.peer as Any), ("reaction", self.reaction as Any)])
            }
        }
        public class Cons_updateNotifySettings: TypeConstructorDescription {
            public var peer: Api.NotifyPeer
            public var notifySettings: Api.PeerNotifySettings
            public init(peer: Api.NotifyPeer, notifySettings: Api.PeerNotifySettings) {
                self.peer = peer
                self.notifySettings = notifySettings
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateNotifySettings", [("peer", self.peer as Any), ("notifySettings", self.notifySettings as Any)])
            }
        }
        public class Cons_updatePaidReactionPrivacy: TypeConstructorDescription {
            public var `private`: Api.PaidReactionPrivacy
            public init(`private`: Api.PaidReactionPrivacy) {
                self.`private` = `private`
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePaidReactionPrivacy", [("`private`", self.`private` as Any)])
            }
        }
        public class Cons_updatePeerBlocked: TypeConstructorDescription {
            public var flags: Int32
            public var peerId: Api.Peer
            public init(flags: Int32, peerId: Api.Peer) {
                self.flags = flags
                self.peerId = peerId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePeerBlocked", [("flags", self.flags as Any), ("peerId", self.peerId as Any)])
            }
        }
        public class Cons_updatePeerHistoryTTL: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var ttlPeriod: Int32?
            public init(flags: Int32, peer: Api.Peer, ttlPeriod: Int32?) {
                self.flags = flags
                self.peer = peer
                self.ttlPeriod = ttlPeriod
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePeerHistoryTTL", [("flags", self.flags as Any), ("peer", self.peer as Any), ("ttlPeriod", self.ttlPeriod as Any)])
            }
        }
        public class Cons_updatePeerLocated: TypeConstructorDescription {
            public var peers: [Api.PeerLocated]
            public init(peers: [Api.PeerLocated]) {
                self.peers = peers
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePeerLocated", [("peers", self.peers as Any)])
            }
        }
        public class Cons_updatePeerSettings: TypeConstructorDescription {
            public var peer: Api.Peer
            public var settings: Api.PeerSettings
            public init(peer: Api.Peer, settings: Api.PeerSettings) {
                self.peer = peer
                self.settings = settings
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePeerSettings", [("peer", self.peer as Any), ("settings", self.settings as Any)])
            }
        }
        public class Cons_updatePeerWallpaper: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var wallpaper: Api.WallPaper?
            public init(flags: Int32, peer: Api.Peer, wallpaper: Api.WallPaper?) {
                self.flags = flags
                self.peer = peer
                self.wallpaper = wallpaper
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePeerWallpaper", [("flags", self.flags as Any), ("peer", self.peer as Any), ("wallpaper", self.wallpaper as Any)])
            }
        }
        public class Cons_updatePendingJoinRequests: TypeConstructorDescription {
            public var peer: Api.Peer
            public var requestsPending: Int32
            public var recentRequesters: [Int64]
            public init(peer: Api.Peer, requestsPending: Int32, recentRequesters: [Int64]) {
                self.peer = peer
                self.requestsPending = requestsPending
                self.recentRequesters = recentRequesters
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePendingJoinRequests", [("peer", self.peer as Any), ("requestsPending", self.requestsPending as Any), ("recentRequesters", self.recentRequesters as Any)])
            }
        }
        public class Cons_updatePhoneCall: TypeConstructorDescription {
            public var phoneCall: Api.PhoneCall
            public init(phoneCall: Api.PhoneCall) {
                self.phoneCall = phoneCall
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePhoneCall", [("phoneCall", self.phoneCall as Any)])
            }
        }
        public class Cons_updatePhoneCallSignalingData: TypeConstructorDescription {
            public var phoneCallId: Int64
            public var data: Buffer
            public init(phoneCallId: Int64, data: Buffer) {
                self.phoneCallId = phoneCallId
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePhoneCallSignalingData", [("phoneCallId", self.phoneCallId as Any), ("data", self.data as Any)])
            }
        }
        public class Cons_updatePinnedChannelMessages: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(flags: Int32, channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.flags = flags
                self.channelId = channelId
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePinnedChannelMessages", [("flags", self.flags as Any), ("channelId", self.channelId as Any), ("messages", self.messages as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updatePinnedDialogs: TypeConstructorDescription {
            public var flags: Int32
            public var folderId: Int32?
            public var order: [Api.DialogPeer]?
            public init(flags: Int32, folderId: Int32?, order: [Api.DialogPeer]?) {
                self.flags = flags
                self.folderId = folderId
                self.order = order
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePinnedDialogs", [("flags", self.flags as Any), ("folderId", self.folderId as Any), ("order", self.order as Any)])
            }
        }
        public class Cons_updatePinnedForumTopic: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var topicId: Int32
            public init(flags: Int32, peer: Api.Peer, topicId: Int32) {
                self.flags = flags
                self.peer = peer
                self.topicId = topicId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePinnedForumTopic", [("flags", self.flags as Any), ("peer", self.peer as Any), ("topicId", self.topicId as Any)])
            }
        }
        public class Cons_updatePinnedForumTopics: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var order: [Int32]?
            public init(flags: Int32, peer: Api.Peer, order: [Int32]?) {
                self.flags = flags
                self.peer = peer
                self.order = order
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePinnedForumTopics", [("flags", self.flags as Any), ("peer", self.peer as Any), ("order", self.order as Any)])
            }
        }
        public class Cons_updatePinnedMessages: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(flags: Int32, peer: Api.Peer, messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.flags = flags
                self.peer = peer
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePinnedMessages", [("flags", self.flags as Any), ("peer", self.peer as Any), ("messages", self.messages as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updatePinnedSavedDialogs: TypeConstructorDescription {
            public var flags: Int32
            public var order: [Api.DialogPeer]?
            public init(flags: Int32, order: [Api.DialogPeer]?) {
                self.flags = flags
                self.order = order
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePinnedSavedDialogs", [("flags", self.flags as Any), ("order", self.order as Any)])
            }
        }
        public class Cons_updatePrivacy: TypeConstructorDescription {
            public var key: Api.PrivacyKey
            public var rules: [Api.PrivacyRule]
            public init(key: Api.PrivacyKey, rules: [Api.PrivacyRule]) {
                self.key = key
                self.rules = rules
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updatePrivacy", [("key", self.key as Any), ("rules", self.rules as Any)])
            }
        }
        public class Cons_updateQuickReplies: TypeConstructorDescription {
            public var quickReplies: [Api.QuickReply]
            public init(quickReplies: [Api.QuickReply]) {
                self.quickReplies = quickReplies
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateQuickReplies", [("quickReplies", self.quickReplies as Any)])
            }
        }
        public class Cons_updateQuickReplyMessage: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateQuickReplyMessage", [("message", self.message as Any)])
            }
        }
        public class Cons_updateReadChannelDiscussionInbox: TypeConstructorDescription {
            public var flags: Int32
            public var channelId: Int64
            public var topMsgId: Int32
            public var readMaxId: Int32
            public var broadcastId: Int64?
            public var broadcastPost: Int32?
            public init(flags: Int32, channelId: Int64, topMsgId: Int32, readMaxId: Int32, broadcastId: Int64?, broadcastPost: Int32?) {
                self.flags = flags
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.readMaxId = readMaxId
                self.broadcastId = broadcastId
                self.broadcastPost = broadcastPost
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadChannelDiscussionInbox", [("flags", self.flags as Any), ("channelId", self.channelId as Any), ("topMsgId", self.topMsgId as Any), ("readMaxId", self.readMaxId as Any), ("broadcastId", self.broadcastId as Any), ("broadcastPost", self.broadcastPost as Any)])
            }
        }
        public class Cons_updateReadChannelDiscussionOutbox: TypeConstructorDescription {
            public var channelId: Int64
            public var topMsgId: Int32
            public var readMaxId: Int32
            public init(channelId: Int64, topMsgId: Int32, readMaxId: Int32) {
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.readMaxId = readMaxId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadChannelDiscussionOutbox", [("channelId", self.channelId as Any), ("topMsgId", self.topMsgId as Any), ("readMaxId", self.readMaxId as Any)])
            }
        }
        public class Cons_updateReadChannelInbox: TypeConstructorDescription {
            public var flags: Int32
            public var folderId: Int32?
            public var channelId: Int64
            public var maxId: Int32
            public var stillUnreadCount: Int32
            public var pts: Int32
            public init(flags: Int32, folderId: Int32?, channelId: Int64, maxId: Int32, stillUnreadCount: Int32, pts: Int32) {
                self.flags = flags
                self.folderId = folderId
                self.channelId = channelId
                self.maxId = maxId
                self.stillUnreadCount = stillUnreadCount
                self.pts = pts
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadChannelInbox", [("flags", self.flags as Any), ("folderId", self.folderId as Any), ("channelId", self.channelId as Any), ("maxId", self.maxId as Any), ("stillUnreadCount", self.stillUnreadCount as Any), ("pts", self.pts as Any)])
            }
        }
        public class Cons_updateReadChannelOutbox: TypeConstructorDescription {
            public var channelId: Int64
            public var maxId: Int32
            public init(channelId: Int64, maxId: Int32) {
                self.channelId = channelId
                self.maxId = maxId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadChannelOutbox", [("channelId", self.channelId as Any), ("maxId", self.maxId as Any)])
            }
        }
        public class Cons_updateReadHistoryInbox: TypeConstructorDescription {
            public var flags: Int32
            public var folderId: Int32?
            public var peer: Api.Peer
            public var topMsgId: Int32?
            public var maxId: Int32
            public var stillUnreadCount: Int32
            public var pts: Int32
            public var ptsCount: Int32
            public init(flags: Int32, folderId: Int32?, peer: Api.Peer, topMsgId: Int32?, maxId: Int32, stillUnreadCount: Int32, pts: Int32, ptsCount: Int32) {
                self.flags = flags
                self.folderId = folderId
                self.peer = peer
                self.topMsgId = topMsgId
                self.maxId = maxId
                self.stillUnreadCount = stillUnreadCount
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadHistoryInbox", [("flags", self.flags as Any), ("folderId", self.folderId as Any), ("peer", self.peer as Any), ("topMsgId", self.topMsgId as Any), ("maxId", self.maxId as Any), ("stillUnreadCount", self.stillUnreadCount as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateReadHistoryOutbox: TypeConstructorDescription {
            public var peer: Api.Peer
            public var maxId: Int32
            public var pts: Int32
            public var ptsCount: Int32
            public init(peer: Api.Peer, maxId: Int32, pts: Int32, ptsCount: Int32) {
                self.peer = peer
                self.maxId = maxId
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadHistoryOutbox", [("peer", self.peer as Any), ("maxId", self.maxId as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateReadMessagesContents: TypeConstructorDescription {
            public var flags: Int32
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32?
            public init(flags: Int32, messages: [Int32], pts: Int32, ptsCount: Int32, date: Int32?) {
                self.flags = flags
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadMessagesContents", [("flags", self.flags as Any), ("messages", self.messages as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any), ("date", self.date as Any)])
            }
        }
        public class Cons_updateReadMonoForumInbox: TypeConstructorDescription {
            public var channelId: Int64
            public var savedPeerId: Api.Peer
            public var readMaxId: Int32
            public init(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32) {
                self.channelId = channelId
                self.savedPeerId = savedPeerId
                self.readMaxId = readMaxId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadMonoForumInbox", [("channelId", self.channelId as Any), ("savedPeerId", self.savedPeerId as Any), ("readMaxId", self.readMaxId as Any)])
            }
        }
        public class Cons_updateReadMonoForumOutbox: TypeConstructorDescription {
            public var channelId: Int64
            public var savedPeerId: Api.Peer
            public var readMaxId: Int32
            public init(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32) {
                self.channelId = channelId
                self.savedPeerId = savedPeerId
                self.readMaxId = readMaxId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadMonoForumOutbox", [("channelId", self.channelId as Any), ("savedPeerId", self.savedPeerId as Any), ("readMaxId", self.readMaxId as Any)])
            }
        }
        public class Cons_updateReadStories: TypeConstructorDescription {
            public var peer: Api.Peer
            public var maxId: Int32
            public init(peer: Api.Peer, maxId: Int32) {
                self.peer = peer
                self.maxId = maxId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateReadStories", [("peer", self.peer as Any), ("maxId", self.maxId as Any)])
            }
        }
        public class Cons_updateSavedDialogPinned: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.DialogPeer
            public init(flags: Int32, peer: Api.DialogPeer) {
                self.flags = flags
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateSavedDialogPinned", [("flags", self.flags as Any), ("peer", self.peer as Any)])
            }
        }
        public class Cons_updateSentPhoneCode: TypeConstructorDescription {
            public var sentCode: Api.auth.SentCode
            public init(sentCode: Api.auth.SentCode) {
                self.sentCode = sentCode
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateSentPhoneCode", [("sentCode", self.sentCode as Any)])
            }
        }
        public class Cons_updateSentStoryReaction: TypeConstructorDescription {
            public var peer: Api.Peer
            public var storyId: Int32
            public var reaction: Api.Reaction
            public init(peer: Api.Peer, storyId: Int32, reaction: Api.Reaction) {
                self.peer = peer
                self.storyId = storyId
                self.reaction = reaction
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateSentStoryReaction", [("peer", self.peer as Any), ("storyId", self.storyId as Any), ("reaction", self.reaction as Any)])
            }
        }
        public class Cons_updateServiceNotification: TypeConstructorDescription {
            public var flags: Int32
            public var inboxDate: Int32?
            public var type: String
            public var message: String
            public var media: Api.MessageMedia
            public var entities: [Api.MessageEntity]
            public init(flags: Int32, inboxDate: Int32?, type: String, message: String, media: Api.MessageMedia, entities: [Api.MessageEntity]) {
                self.flags = flags
                self.inboxDate = inboxDate
                self.type = type
                self.message = message
                self.media = media
                self.entities = entities
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateServiceNotification", [("flags", self.flags as Any), ("inboxDate", self.inboxDate as Any), ("type", self.type as Any), ("message", self.message as Any), ("media", self.media as Any), ("entities", self.entities as Any)])
            }
        }
        public class Cons_updateSmsJob: TypeConstructorDescription {
            public var jobId: String
            public init(jobId: String) {
                self.jobId = jobId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateSmsJob", [("jobId", self.jobId as Any)])
            }
        }
        public class Cons_updateStarGiftAuctionState: TypeConstructorDescription {
            public var giftId: Int64
            public var state: Api.StarGiftAuctionState
            public init(giftId: Int64, state: Api.StarGiftAuctionState) {
                self.giftId = giftId
                self.state = state
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStarGiftAuctionState", [("giftId", self.giftId as Any), ("state", self.state as Any)])
            }
        }
        public class Cons_updateStarGiftAuctionUserState: TypeConstructorDescription {
            public var giftId: Int64
            public var userState: Api.StarGiftAuctionUserState
            public init(giftId: Int64, userState: Api.StarGiftAuctionUserState) {
                self.giftId = giftId
                self.userState = userState
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStarGiftAuctionUserState", [("giftId", self.giftId as Any), ("userState", self.userState as Any)])
            }
        }
        public class Cons_updateStarsBalance: TypeConstructorDescription {
            public var balance: Api.StarsAmount
            public init(balance: Api.StarsAmount) {
                self.balance = balance
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStarsBalance", [("balance", self.balance as Any)])
            }
        }
        public class Cons_updateStarsRevenueStatus: TypeConstructorDescription {
            public var peer: Api.Peer
            public var status: Api.StarsRevenueStatus
            public init(peer: Api.Peer, status: Api.StarsRevenueStatus) {
                self.peer = peer
                self.status = status
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStarsRevenueStatus", [("peer", self.peer as Any), ("status", self.status as Any)])
            }
        }
        public class Cons_updateStickerSets: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStickerSets", [("flags", self.flags as Any)])
            }
        }
        public class Cons_updateStickerSetsOrder: TypeConstructorDescription {
            public var flags: Int32
            public var order: [Int64]
            public init(flags: Int32, order: [Int64]) {
                self.flags = flags
                self.order = order
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStickerSetsOrder", [("flags", self.flags as Any), ("order", self.order as Any)])
            }
        }
        public class Cons_updateStoriesStealthMode: TypeConstructorDescription {
            public var stealthMode: Api.StoriesStealthMode
            public init(stealthMode: Api.StoriesStealthMode) {
                self.stealthMode = stealthMode
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStoriesStealthMode", [("stealthMode", self.stealthMode as Any)])
            }
        }
        public class Cons_updateStory: TypeConstructorDescription {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStory", [("peer", self.peer as Any), ("story", self.story as Any)])
            }
        }
        public class Cons_updateStoryID: TypeConstructorDescription {
            public var id: Int32
            public var randomId: Int64
            public init(id: Int32, randomId: Int64) {
                self.id = id
                self.randomId = randomId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateStoryID", [("id", self.id as Any), ("randomId", self.randomId as Any)])
            }
        }
        public class Cons_updateTheme: TypeConstructorDescription {
            public var theme: Api.Theme
            public init(theme: Api.Theme) {
                self.theme = theme
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateTheme", [("theme", self.theme as Any)])
            }
        }
        public class Cons_updateTranscribedAudio: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var msgId: Int32
            public var transcriptionId: Int64
            public var text: String
            public init(flags: Int32, peer: Api.Peer, msgId: Int32, transcriptionId: Int64, text: String) {
                self.flags = flags
                self.peer = peer
                self.msgId = msgId
                self.transcriptionId = transcriptionId
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateTranscribedAudio", [("flags", self.flags as Any), ("peer", self.peer as Any), ("msgId", self.msgId as Any), ("transcriptionId", self.transcriptionId as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_updateUser: TypeConstructorDescription {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateUser", [("userId", self.userId as Any)])
            }
        }
        public class Cons_updateUserEmojiStatus: TypeConstructorDescription {
            public var userId: Int64
            public var emojiStatus: Api.EmojiStatus
            public init(userId: Int64, emojiStatus: Api.EmojiStatus) {
                self.userId = userId
                self.emojiStatus = emojiStatus
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateUserEmojiStatus", [("userId", self.userId as Any), ("emojiStatus", self.emojiStatus as Any)])
            }
        }
        public class Cons_updateUserName: TypeConstructorDescription {
            public var userId: Int64
            public var firstName: String
            public var lastName: String
            public var usernames: [Api.Username]
            public init(userId: Int64, firstName: String, lastName: String, usernames: [Api.Username]) {
                self.userId = userId
                self.firstName = firstName
                self.lastName = lastName
                self.usernames = usernames
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateUserName", [("userId", self.userId as Any), ("firstName", self.firstName as Any), ("lastName", self.lastName as Any), ("usernames", self.usernames as Any)])
            }
        }
        public class Cons_updateUserPhone: TypeConstructorDescription {
            public var userId: Int64
            public var phone: String
            public init(userId: Int64, phone: String) {
                self.userId = userId
                self.phone = phone
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateUserPhone", [("userId", self.userId as Any), ("phone", self.phone as Any)])
            }
        }
        public class Cons_updateUserStatus: TypeConstructorDescription {
            public var userId: Int64
            public var status: Api.UserStatus
            public init(userId: Int64, status: Api.UserStatus) {
                self.userId = userId
                self.status = status
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateUserStatus", [("userId", self.userId as Any), ("status", self.status as Any)])
            }
        }
        public class Cons_updateUserTyping: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Int64
            public var topMsgId: Int32?
            public var action: Api.SendMessageAction
            public init(flags: Int32, userId: Int64, topMsgId: Int32?, action: Api.SendMessageAction) {
                self.flags = flags
                self.userId = userId
                self.topMsgId = topMsgId
                self.action = action
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateUserTyping", [("flags", self.flags as Any), ("userId", self.userId as Any), ("topMsgId", self.topMsgId as Any), ("action", self.action as Any)])
            }
        }
        public class Cons_updateWebPage: TypeConstructorDescription {
            public var webpage: Api.WebPage
            public var pts: Int32
            public var ptsCount: Int32
            public init(webpage: Api.WebPage, pts: Int32, ptsCount: Int32) {
                self.webpage = webpage
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateWebPage", [("webpage", self.webpage as Any), ("pts", self.pts as Any), ("ptsCount", self.ptsCount as Any)])
            }
        }
        public class Cons_updateWebViewResultSent: TypeConstructorDescription {
            public var queryId: Int64
            public init(queryId: Int64) {
                self.queryId = queryId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("updateWebViewResultSent", [("queryId", self.queryId as Any)])
            }
        }
        case updateAttachMenuBots
        case updateAutoSaveSettings
        case updateBotBusinessConnect(Cons_updateBotBusinessConnect)
        case updateBotCallbackQuery(Cons_updateBotCallbackQuery)
        case updateBotChatBoost(Cons_updateBotChatBoost)
        case updateBotChatInviteRequester(Cons_updateBotChatInviteRequester)
        case updateBotCommands(Cons_updateBotCommands)
        case updateBotDeleteBusinessMessage(Cons_updateBotDeleteBusinessMessage)
        case updateBotEditBusinessMessage(Cons_updateBotEditBusinessMessage)
        case updateBotInlineQuery(Cons_updateBotInlineQuery)
        case updateBotInlineSend(Cons_updateBotInlineSend)
        case updateBotMenuButton(Cons_updateBotMenuButton)
        case updateBotMessageReaction(Cons_updateBotMessageReaction)
        case updateBotMessageReactions(Cons_updateBotMessageReactions)
        case updateBotNewBusinessMessage(Cons_updateBotNewBusinessMessage)
        case updateBotPrecheckoutQuery(Cons_updateBotPrecheckoutQuery)
        case updateBotPurchasedPaidMedia(Cons_updateBotPurchasedPaidMedia)
        case updateBotShippingQuery(Cons_updateBotShippingQuery)
        case updateBotStopped(Cons_updateBotStopped)
        case updateBotWebhookJSON(Cons_updateBotWebhookJSON)
        case updateBotWebhookJSONQuery(Cons_updateBotWebhookJSONQuery)
        case updateBusinessBotCallbackQuery(Cons_updateBusinessBotCallbackQuery)
        case updateChannel(Cons_updateChannel)
        case updateChannelAvailableMessages(Cons_updateChannelAvailableMessages)
        case updateChannelMessageForwards(Cons_updateChannelMessageForwards)
        case updateChannelMessageViews(Cons_updateChannelMessageViews)
        case updateChannelParticipant(Cons_updateChannelParticipant)
        case updateChannelReadMessagesContents(Cons_updateChannelReadMessagesContents)
        case updateChannelTooLong(Cons_updateChannelTooLong)
        case updateChannelUserTyping(Cons_updateChannelUserTyping)
        case updateChannelViewForumAsMessages(Cons_updateChannelViewForumAsMessages)
        case updateChannelWebPage(Cons_updateChannelWebPage)
        case updateChat(Cons_updateChat)
        case updateChatDefaultBannedRights(Cons_updateChatDefaultBannedRights)
        case updateChatParticipant(Cons_updateChatParticipant)
        case updateChatParticipantAdd(Cons_updateChatParticipantAdd)
        case updateChatParticipantAdmin(Cons_updateChatParticipantAdmin)
        case updateChatParticipantDelete(Cons_updateChatParticipantDelete)
        case updateChatParticipantRank(Cons_updateChatParticipantRank)
        case updateChatParticipants(Cons_updateChatParticipants)
        case updateChatUserTyping(Cons_updateChatUserTyping)
        case updateConfig
        case updateContactsReset
        case updateDcOptions(Cons_updateDcOptions)
        case updateDeleteChannelMessages(Cons_updateDeleteChannelMessages)
        case updateDeleteGroupCallMessages(Cons_updateDeleteGroupCallMessages)
        case updateDeleteMessages(Cons_updateDeleteMessages)
        case updateDeleteQuickReply(Cons_updateDeleteQuickReply)
        case updateDeleteQuickReplyMessages(Cons_updateDeleteQuickReplyMessages)
        case updateDeleteScheduledMessages(Cons_updateDeleteScheduledMessages)
        case updateDialogFilter(Cons_updateDialogFilter)
        case updateDialogFilterOrder(Cons_updateDialogFilterOrder)
        case updateDialogFilters
        case updateDialogPinned(Cons_updateDialogPinned)
        case updateDialogUnreadMark(Cons_updateDialogUnreadMark)
        case updateDraftMessage(Cons_updateDraftMessage)
        case updateEditChannelMessage(Cons_updateEditChannelMessage)
        case updateEditMessage(Cons_updateEditMessage)
        case updateEmojiGameInfo(Cons_updateEmojiGameInfo)
        case updateEncryptedChatTyping(Cons_updateEncryptedChatTyping)
        case updateEncryptedMessagesRead(Cons_updateEncryptedMessagesRead)
        case updateEncryption(Cons_updateEncryption)
        case updateFavedStickers
        case updateFolderPeers(Cons_updateFolderPeers)
        case updateGeoLiveViewed(Cons_updateGeoLiveViewed)
        case updateGroupCall(Cons_updateGroupCall)
        case updateGroupCallChainBlocks(Cons_updateGroupCallChainBlocks)
        case updateGroupCallConnection(Cons_updateGroupCallConnection)
        case updateGroupCallEncryptedMessage(Cons_updateGroupCallEncryptedMessage)
        case updateGroupCallMessage(Cons_updateGroupCallMessage)
        case updateGroupCallParticipants(Cons_updateGroupCallParticipants)
        case updateInlineBotCallbackQuery(Cons_updateInlineBotCallbackQuery)
        case updateLangPack(Cons_updateLangPack)
        case updateLangPackTooLong(Cons_updateLangPackTooLong)
        case updateLoginToken
        case updateMessageExtendedMedia(Cons_updateMessageExtendedMedia)
        case updateMessageID(Cons_updateMessageID)
        case updateMessagePoll(Cons_updateMessagePoll)
        case updateMessagePollVote(Cons_updateMessagePollVote)
        case updateMessageReactions(Cons_updateMessageReactions)
        case updateMonoForumNoPaidException(Cons_updateMonoForumNoPaidException)
        case updateMoveStickerSetToTop(Cons_updateMoveStickerSetToTop)
        case updateNewAuthorization(Cons_updateNewAuthorization)
        case updateNewChannelMessage(Cons_updateNewChannelMessage)
        case updateNewEncryptedMessage(Cons_updateNewEncryptedMessage)
        case updateNewMessage(Cons_updateNewMessage)
        case updateNewQuickReply(Cons_updateNewQuickReply)
        case updateNewScheduledMessage(Cons_updateNewScheduledMessage)
        case updateNewStickerSet(Cons_updateNewStickerSet)
        case updateNewStoryReaction(Cons_updateNewStoryReaction)
        case updateNotifySettings(Cons_updateNotifySettings)
        case updatePaidReactionPrivacy(Cons_updatePaidReactionPrivacy)
        case updatePeerBlocked(Cons_updatePeerBlocked)
        case updatePeerHistoryTTL(Cons_updatePeerHistoryTTL)
        case updatePeerLocated(Cons_updatePeerLocated)
        case updatePeerSettings(Cons_updatePeerSettings)
        case updatePeerWallpaper(Cons_updatePeerWallpaper)
        case updatePendingJoinRequests(Cons_updatePendingJoinRequests)
        case updatePhoneCall(Cons_updatePhoneCall)
        case updatePhoneCallSignalingData(Cons_updatePhoneCallSignalingData)
        case updatePinnedChannelMessages(Cons_updatePinnedChannelMessages)
        case updatePinnedDialogs(Cons_updatePinnedDialogs)
        case updatePinnedForumTopic(Cons_updatePinnedForumTopic)
        case updatePinnedForumTopics(Cons_updatePinnedForumTopics)
        case updatePinnedMessages(Cons_updatePinnedMessages)
        case updatePinnedSavedDialogs(Cons_updatePinnedSavedDialogs)
        case updatePrivacy(Cons_updatePrivacy)
        case updatePtsChanged
        case updateQuickReplies(Cons_updateQuickReplies)
        case updateQuickReplyMessage(Cons_updateQuickReplyMessage)
        case updateReadChannelDiscussionInbox(Cons_updateReadChannelDiscussionInbox)
        case updateReadChannelDiscussionOutbox(Cons_updateReadChannelDiscussionOutbox)
        case updateReadChannelInbox(Cons_updateReadChannelInbox)
        case updateReadChannelOutbox(Cons_updateReadChannelOutbox)
        case updateReadFeaturedEmojiStickers
        case updateReadFeaturedStickers
        case updateReadHistoryInbox(Cons_updateReadHistoryInbox)
        case updateReadHistoryOutbox(Cons_updateReadHistoryOutbox)
        case updateReadMessagesContents(Cons_updateReadMessagesContents)
        case updateReadMonoForumInbox(Cons_updateReadMonoForumInbox)
        case updateReadMonoForumOutbox(Cons_updateReadMonoForumOutbox)
        case updateReadStories(Cons_updateReadStories)
        case updateRecentEmojiStatuses
        case updateRecentReactions
        case updateRecentStickers
        case updateSavedDialogPinned(Cons_updateSavedDialogPinned)
        case updateSavedGifs
        case updateSavedReactionTags
        case updateSavedRingtones
        case updateSentPhoneCode(Cons_updateSentPhoneCode)
        case updateSentStoryReaction(Cons_updateSentStoryReaction)
        case updateServiceNotification(Cons_updateServiceNotification)
        case updateSmsJob(Cons_updateSmsJob)
        case updateStarGiftAuctionState(Cons_updateStarGiftAuctionState)
        case updateStarGiftAuctionUserState(Cons_updateStarGiftAuctionUserState)
        case updateStarGiftCraftFail
        case updateStarsBalance(Cons_updateStarsBalance)
        case updateStarsRevenueStatus(Cons_updateStarsRevenueStatus)
        case updateStickerSets(Cons_updateStickerSets)
        case updateStickerSetsOrder(Cons_updateStickerSetsOrder)
        case updateStoriesStealthMode(Cons_updateStoriesStealthMode)
        case updateStory(Cons_updateStory)
        case updateStoryID(Cons_updateStoryID)
        case updateTheme(Cons_updateTheme)
        case updateTranscribedAudio(Cons_updateTranscribedAudio)
        case updateUser(Cons_updateUser)
        case updateUserEmojiStatus(Cons_updateUserEmojiStatus)
        case updateUserName(Cons_updateUserName)
        case updateUserPhone(Cons_updateUserPhone)
        case updateUserStatus(Cons_updateUserStatus)
        case updateUserTyping(Cons_updateUserTyping)
        case updateWebPage(Cons_updateWebPage)
        case updateWebViewResultSent(Cons_updateWebViewResultSent)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .updateAttachMenuBots:
                if boxed {
                    buffer.appendInt32(397910539)
                }
                break
            case .updateAutoSaveSettings:
                if boxed {
                    buffer.appendInt32(-335171433)
                }
                break
            case .updateBotBusinessConnect(let _data):
                if boxed {
                    buffer.appendInt32(-1964652166)
                }
                _data.connection.serialize(buffer, true)
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotCallbackQuery(let _data):
                if boxed {
                    buffer.appendInt32(-1177566067)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.chatInstance, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.data!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.gameShortName!, buffer: buffer, boxed: false)
                }
                break
            case .updateBotChatBoost(let _data):
                if boxed {
                    buffer.appendInt32(-1873947492)
                }
                _data.peer.serialize(buffer, true)
                _data.boost.serialize(buffer, true)
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotChatInviteRequester(let _data):
                if boxed {
                    buffer.appendInt32(299870598)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.about, buffer: buffer, boxed: false)
                _data.invite.serialize(buffer, true)
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotCommands(let _data):
                if boxed {
                    buffer.appendInt32(1299263278)
                }
                _data.peer.serialize(buffer, true)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.commands.count))
                for item in _data.commands {
                    item.serialize(buffer, true)
                }
                break
            case .updateBotDeleteBusinessMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1607821266)
                }
                serializeString(_data.connectionId, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotEditBusinessMessage(let _data):
                if boxed {
                    buffer.appendInt32(132077692)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.connectionId, buffer: buffer, boxed: false)
                _data.message.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.replyToMessage!.serialize(buffer, true)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotInlineQuery(let _data):
                if boxed {
                    buffer.appendInt32(1232025500)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.query, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.geo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.peerType!.serialize(buffer, true)
                }
                serializeString(_data.offset, buffer: buffer, boxed: false)
                break
            case .updateBotInlineSend(let _data):
                if boxed {
                    buffer.appendInt32(317794823)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.query, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.geo!.serialize(buffer, true)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.msgId!.serialize(buffer, true)
                }
                break
            case .updateBotMenuButton(let _data):
                if boxed {
                    buffer.appendInt32(347625491)
                }
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                _data.button.serialize(buffer, true)
                break
            case .updateBotMessageReaction(let _data):
                if boxed {
                    buffer.appendInt32(-1407069234)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.actor.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.oldReactions.count))
                for item in _data.oldReactions {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.newReactions.count))
                for item in _data.newReactions {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotMessageReactions(let _data):
                if boxed {
                    buffer.appendInt32(164329305)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.reactions.count))
                for item in _data.reactions {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotNewBusinessMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1646578564)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.connectionId, buffer: buffer, boxed: false)
                _data.message.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.replyToMessage!.serialize(buffer, true)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotPrecheckoutQuery(let _data):
                if boxed {
                    buffer.appendInt32(-1934976362)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeBytes(_data.payload, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.info!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.shippingOptionId!, buffer: buffer, boxed: false)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                break
            case .updateBotPurchasedPaidMedia(let _data):
                if boxed {
                    buffer.appendInt32(675009298)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.payload, buffer: buffer, boxed: false)
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotShippingQuery(let _data):
                if boxed {
                    buffer.appendInt32(-1246823043)
                }
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeBytes(_data.payload, buffer: buffer, boxed: false)
                _data.shippingAddress.serialize(buffer, true)
                break
            case .updateBotStopped(let _data):
                if boxed {
                    buffer.appendInt32(-997782967)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.stopped.serialize(buffer, true)
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateBotWebhookJSON(let _data):
                if boxed {
                    buffer.appendInt32(-2095595325)
                }
                _data.data.serialize(buffer, true)
                break
            case .updateBotWebhookJSONQuery(let _data):
                if boxed {
                    buffer.appendInt32(-1684914010)
                }
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                _data.data.serialize(buffer, true)
                serializeInt32(_data.timeout, buffer: buffer, boxed: false)
                break
            case .updateBusinessBotCallbackQuery(let _data):
                if boxed {
                    buffer.appendInt32(513998247)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.connectionId, buffer: buffer, boxed: false)
                _data.message.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyToMessage!.serialize(buffer, true)
                }
                serializeInt64(_data.chatInstance, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.data!, buffer: buffer, boxed: false)
                }
                break
            case .updateChannel(let _data):
                if boxed {
                    buffer.appendInt32(1666927625)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                break
            case .updateChannelAvailableMessages(let _data):
                if boxed {
                    buffer.appendInt32(-1304443240)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.availableMinId, buffer: buffer, boxed: false)
                break
            case .updateChannelMessageForwards(let _data):
                if boxed {
                    buffer.appendInt32(-761649164)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.forwards, buffer: buffer, boxed: false)
                break
            case .updateChannelMessageViews(let _data):
                if boxed {
                    buffer.appendInt32(-232346616)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.views, buffer: buffer, boxed: false)
                break
            case .updateChannelParticipant(let _data):
                if boxed {
                    buffer.appendInt32(-1738720581)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.actorId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.prevParticipant!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.newParticipant!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.invite!.serialize(buffer, true)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateChannelReadMessagesContents(let _data):
                if boxed {
                    buffer.appendInt32(636691703)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.savedPeerId!.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .updateChannelTooLong(let _data):
                if boxed {
                    buffer.appendInt32(277713951)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.pts!, buffer: buffer, boxed: false)
                }
                break
            case .updateChannelUserTyping(let _data):
                if boxed {
                    buffer.appendInt32(-1937192669)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                _data.fromId.serialize(buffer, true)
                _data.action.serialize(buffer, true)
                break
            case .updateChannelViewForumAsMessages(let _data):
                if boxed {
                    buffer.appendInt32(129403168)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                _data.enabled.serialize(buffer, true)
                break
            case .updateChannelWebPage(let _data):
                if boxed {
                    buffer.appendInt32(791390623)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                _data.webpage.serialize(buffer, true)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateChat(let _data):
                if boxed {
                    buffer.appendInt32(-124097970)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                break
            case .updateChatDefaultBannedRights(let _data):
                if boxed {
                    buffer.appendInt32(1421875280)
                }
                _data.peer.serialize(buffer, true)
                _data.defaultBannedRights.serialize(buffer, true)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            case .updateChatParticipant(let _data):
                if boxed {
                    buffer.appendInt32(-796432838)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.actorId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.prevParticipant!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.newParticipant!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.invite!.serialize(buffer, true)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateChatParticipantAdd(let _data):
                if boxed {
                    buffer.appendInt32(1037718609)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.inviterId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            case .updateChatParticipantAdmin(let _data):
                if boxed {
                    buffer.appendInt32(-674602590)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.isAdmin.serialize(buffer, true)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            case .updateChatParticipantDelete(let _data):
                if boxed {
                    buffer.appendInt32(-483443337)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            case .updateChatParticipantRank(let _data):
                if boxed {
                    buffer.appendInt32(-1115461703)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.rank, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            case .updateChatParticipants(let _data):
                if boxed {
                    buffer.appendInt32(125178264)
                }
                _data.participants.serialize(buffer, true)
                break
            case .updateChatUserTyping(let _data):
                if boxed {
                    buffer.appendInt32(-2092401936)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                _data.fromId.serialize(buffer, true)
                _data.action.serialize(buffer, true)
                break
            case .updateConfig:
                if boxed {
                    buffer.appendInt32(-1574314746)
                }
                break
            case .updateContactsReset:
                if boxed {
                    buffer.appendInt32(1887741886)
                }
                break
            case .updateDcOptions(let _data):
                if boxed {
                    buffer.appendInt32(-1906403213)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dcOptions.count))
                for item in _data.dcOptions {
                    item.serialize(buffer, true)
                }
                break
            case .updateDeleteChannelMessages(let _data):
                if boxed {
                    buffer.appendInt32(-1020437742)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateDeleteGroupCallMessages(let _data):
                if boxed {
                    buffer.appendInt32(1048963372)
                }
                _data.call.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .updateDeleteMessages(let _data):
                if boxed {
                    buffer.appendInt32(-1576161051)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateDeleteQuickReply(let _data):
                if boxed {
                    buffer.appendInt32(1407644140)
                }
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                break
            case .updateDeleteQuickReplyMessages(let _data):
                if boxed {
                    buffer.appendInt32(1450174413)
                }
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .updateDeleteScheduledMessages(let _data):
                if boxed {
                    buffer.appendInt32(-223929981)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.sentMessages!.count))
                    for item in _data.sentMessages! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                break
            case .updateDialogFilter(let _data):
                if boxed {
                    buffer.appendInt32(654302845)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.filter!.serialize(buffer, true)
                }
                break
            case .updateDialogFilterOrder(let _data):
                if boxed {
                    buffer.appendInt32(-1512627963)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.order.count))
                for item in _data.order {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .updateDialogFilters:
                if boxed {
                    buffer.appendInt32(889491791)
                }
                break
            case .updateDialogPinned(let _data):
                if boxed {
                    buffer.appendInt32(1852826908)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                _data.peer.serialize(buffer, true)
                break
            case .updateDialogUnreadMark(let _data):
                if boxed {
                    buffer.appendInt32(-1235684802)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.savedPeerId!.serialize(buffer, true)
                }
                break
            case .updateDraftMessage(let _data):
                if boxed {
                    buffer.appendInt32(-302247650)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.savedPeerId!.serialize(buffer, true)
                }
                _data.draft.serialize(buffer, true)
                break
            case .updateEditChannelMessage(let _data):
                if boxed {
                    buffer.appendInt32(457133559)
                }
                _data.message.serialize(buffer, true)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateEditMessage(let _data):
                if boxed {
                    buffer.appendInt32(-469536605)
                }
                _data.message.serialize(buffer, true)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateEmojiGameInfo(let _data):
                if boxed {
                    buffer.appendInt32(-73640838)
                }
                _data.info.serialize(buffer, true)
                break
            case .updateEncryptedChatTyping(let _data):
                if boxed {
                    buffer.appendInt32(386986326)
                }
                serializeInt32(_data.chatId, buffer: buffer, boxed: false)
                break
            case .updateEncryptedMessagesRead(let _data):
                if boxed {
                    buffer.appendInt32(956179895)
                }
                serializeInt32(_data.chatId, buffer: buffer, boxed: false)
                serializeInt32(_data.maxDate, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .updateEncryption(let _data):
                if boxed {
                    buffer.appendInt32(-1264392051)
                }
                _data.chat.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .updateFavedStickers:
                if boxed {
                    buffer.appendInt32(-451831443)
                }
                break
            case .updateFolderPeers(let _data):
                if boxed {
                    buffer.appendInt32(422972864)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.folderPeers.count))
                for item in _data.folderPeers {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateGeoLiveViewed(let _data):
                if boxed {
                    buffer.appendInt32(-2027964103)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            case .updateGroupCall(let _data):
                if boxed {
                    buffer.appendInt32(-1658710304)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.peer!.serialize(buffer, true)
                }
                _data.call.serialize(buffer, true)
                break
            case .updateGroupCallChainBlocks(let _data):
                if boxed {
                    buffer.appendInt32(-1535694705)
                }
                _data.call.serialize(buffer, true)
                serializeInt32(_data.subChainId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    serializeBytes(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.nextOffset, buffer: buffer, boxed: false)
                break
            case .updateGroupCallConnection(let _data):
                if boxed {
                    buffer.appendInt32(192428418)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.params.serialize(buffer, true)
                break
            case .updateGroupCallEncryptedMessage(let _data):
                if boxed {
                    buffer.appendInt32(-917002394)
                }
                _data.call.serialize(buffer, true)
                _data.fromId.serialize(buffer, true)
                serializeBytes(_data.encryptedMessage, buffer: buffer, boxed: false)
                break
            case .updateGroupCallMessage(let _data):
                if boxed {
                    buffer.appendInt32(-667783411)
                }
                _data.call.serialize(buffer, true)
                _data.message.serialize(buffer, true)
                break
            case .updateGroupCallParticipants(let _data):
                if boxed {
                    buffer.appendInt32(-219423922)
                }
                _data.call.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.participants.count))
                for item in _data.participants {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            case .updateInlineBotCallbackQuery(let _data):
                if boxed {
                    buffer.appendInt32(1763610706)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.msgId.serialize(buffer, true)
                serializeInt64(_data.chatInstance, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.data!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.gameShortName!, buffer: buffer, boxed: false)
                }
                break
            case .updateLangPack(let _data):
                if boxed {
                    buffer.appendInt32(1442983757)
                }
                _data.difference.serialize(buffer, true)
                break
            case .updateLangPackTooLong(let _data):
                if boxed {
                    buffer.appendInt32(1180041828)
                }
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                break
            case .updateLoginToken:
                if boxed {
                    buffer.appendInt32(1448076945)
                }
                break
            case .updateMessageExtendedMedia(let _data):
                if boxed {
                    buffer.appendInt32(-710666460)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.extendedMedia.count))
                for item in _data.extendedMedia {
                    item.serialize(buffer, true)
                }
                break
            case .updateMessageID(let _data):
                if boxed {
                    buffer.appendInt32(1318109142)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                break
            case .updateMessagePoll(let _data):
                if boxed {
                    buffer.appendInt32(-1398708869)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.pollId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.poll!.serialize(buffer, true)
                }
                _data.results.serialize(buffer, true)
                break
            case .updateMessagePollVote(let _data):
                if boxed {
                    buffer.appendInt32(619974263)
                }
                serializeInt64(_data.pollId, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.options.count))
                for item in _data.options {
                    serializeBytes(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateMessageReactions(let _data):
                if boxed {
                    buffer.appendInt32(506035194)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.savedPeerId!.serialize(buffer, true)
                }
                _data.reactions.serialize(buffer, true)
                break
            case .updateMonoForumNoPaidException(let _data):
                if boxed {
                    buffer.appendInt32(-1618924792)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                _data.savedPeerId.serialize(buffer, true)
                break
            case .updateMoveStickerSetToTop(let _data):
                if boxed {
                    buffer.appendInt32(-2030252155)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stickerset, buffer: buffer, boxed: false)
                break
            case .updateNewAuthorization(let _data):
                if boxed {
                    buffer.appendInt32(-1991136273)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.date!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.device!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.location!, buffer: buffer, boxed: false)
                }
                break
            case .updateNewChannelMessage(let _data):
                if boxed {
                    buffer.appendInt32(1656358105)
                }
                _data.message.serialize(buffer, true)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateNewEncryptedMessage(let _data):
                if boxed {
                    buffer.appendInt32(314359194)
                }
                _data.message.serialize(buffer, true)
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                break
            case .updateNewMessage(let _data):
                if boxed {
                    buffer.appendInt32(522914557)
                }
                _data.message.serialize(buffer, true)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateNewQuickReply(let _data):
                if boxed {
                    buffer.appendInt32(-180508905)
                }
                _data.quickReply.serialize(buffer, true)
                break
            case .updateNewScheduledMessage(let _data):
                if boxed {
                    buffer.appendInt32(967122427)
                }
                _data.message.serialize(buffer, true)
                break
            case .updateNewStickerSet(let _data):
                if boxed {
                    buffer.appendInt32(1753886890)
                }
                _data.stickerset.serialize(buffer, true)
                break
            case .updateNewStoryReaction(let _data):
                if boxed {
                    buffer.appendInt32(405070859)
                }
                serializeInt32(_data.storyId, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                _data.reaction.serialize(buffer, true)
                break
            case .updateNotifySettings(let _data):
                if boxed {
                    buffer.appendInt32(-1094555409)
                }
                _data.peer.serialize(buffer, true)
                _data.notifySettings.serialize(buffer, true)
                break
            case .updatePaidReactionPrivacy(let _data):
                if boxed {
                    buffer.appendInt32(-1955438642)
                }
                _data.`private`.serialize(buffer, true)
                break
            case .updatePeerBlocked(let _data):
                if boxed {
                    buffer.appendInt32(-337610926)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peerId.serialize(buffer, true)
                break
            case .updatePeerHistoryTTL(let _data):
                if boxed {
                    buffer.appendInt32(-1147422299)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                break
            case .updatePeerLocated(let _data):
                if boxed {
                    buffer.appendInt32(-1263546448)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
                    item.serialize(buffer, true)
                }
                break
            case .updatePeerSettings(let _data):
                if boxed {
                    buffer.appendInt32(1786671974)
                }
                _data.peer.serialize(buffer, true)
                _data.settings.serialize(buffer, true)
                break
            case .updatePeerWallpaper(let _data):
                if boxed {
                    buffer.appendInt32(-1371598819)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.wallpaper!.serialize(buffer, true)
                }
                break
            case .updatePendingJoinRequests(let _data):
                if boxed {
                    buffer.appendInt32(1885586395)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.requestsPending, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.recentRequesters.count))
                for item in _data.recentRequesters {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .updatePhoneCall(let _data):
                if boxed {
                    buffer.appendInt32(-1425052898)
                }
                _data.phoneCall.serialize(buffer, true)
                break
            case .updatePhoneCallSignalingData(let _data):
                if boxed {
                    buffer.appendInt32(643940105)
                }
                serializeInt64(_data.phoneCallId, buffer: buffer, boxed: false)
                serializeBytes(_data.data, buffer: buffer, boxed: false)
                break
            case .updatePinnedChannelMessages(let _data):
                if boxed {
                    buffer.appendInt32(1538885128)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updatePinnedDialogs(let _data):
                if boxed {
                    buffer.appendInt32(-99664734)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.order!.count))
                    for item in _data.order! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .updatePinnedForumTopic(let _data):
                if boxed {
                    buffer.appendInt32(1748708434)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topicId, buffer: buffer, boxed: false)
                break
            case .updatePinnedForumTopics(let _data):
                if boxed {
                    buffer.appendInt32(-554613808)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.order!.count))
                    for item in _data.order! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                break
            case .updatePinnedMessages(let _data):
                if boxed {
                    buffer.appendInt32(-309990731)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updatePinnedSavedDialogs(let _data):
                if boxed {
                    buffer.appendInt32(1751942566)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.order!.count))
                    for item in _data.order! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .updatePrivacy(let _data):
                if boxed {
                    buffer.appendInt32(-298113238)
                }
                _data.key.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rules.count))
                for item in _data.rules {
                    item.serialize(buffer, true)
                }
                break
            case .updatePtsChanged:
                if boxed {
                    buffer.appendInt32(861169551)
                }
                break
            case .updateQuickReplies(let _data):
                if boxed {
                    buffer.appendInt32(-112784718)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.quickReplies.count))
                for item in _data.quickReplies {
                    item.serialize(buffer, true)
                }
                break
            case .updateQuickReplyMessage(let _data):
                if boxed {
                    buffer.appendInt32(1040518415)
                }
                _data.message.serialize(buffer, true)
                break
            case .updateReadChannelDiscussionInbox(let _data):
                if boxed {
                    buffer.appendInt32(-693004986)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.topMsgId, buffer: buffer, boxed: false)
                serializeInt32(_data.readMaxId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.broadcastId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.broadcastPost!, buffer: buffer, boxed: false)
                }
                break
            case .updateReadChannelDiscussionOutbox(let _data):
                if boxed {
                    buffer.appendInt32(1767677564)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.topMsgId, buffer: buffer, boxed: false)
                serializeInt32(_data.readMaxId, buffer: buffer, boxed: false)
                break
            case .updateReadChannelInbox(let _data):
                if boxed {
                    buffer.appendInt32(-1842450928)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.maxId, buffer: buffer, boxed: false)
                serializeInt32(_data.stillUnreadCount, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                break
            case .updateReadChannelOutbox(let _data):
                if boxed {
                    buffer.appendInt32(-1218471511)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.maxId, buffer: buffer, boxed: false)
                break
            case .updateReadFeaturedEmojiStickers:
                if boxed {
                    buffer.appendInt32(-78886548)
                }
                break
            case .updateReadFeaturedStickers:
                if boxed {
                    buffer.appendInt32(1461528386)
                }
                break
            case .updateReadHistoryInbox(let _data):
                if boxed {
                    buffer.appendInt32(-1635468135)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.maxId, buffer: buffer, boxed: false)
                serializeInt32(_data.stillUnreadCount, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateReadHistoryOutbox(let _data):
                if boxed {
                    buffer.appendInt32(791617983)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.maxId, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateReadMessagesContents(let _data):
                if boxed {
                    buffer.appendInt32(-131960447)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.date!, buffer: buffer, boxed: false)
                }
                break
            case .updateReadMonoForumInbox(let _data):
                if boxed {
                    buffer.appendInt32(2008081266)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                _data.savedPeerId.serialize(buffer, true)
                serializeInt32(_data.readMaxId, buffer: buffer, boxed: false)
                break
            case .updateReadMonoForumOutbox(let _data):
                if boxed {
                    buffer.appendInt32(-1532521610)
                }
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                _data.savedPeerId.serialize(buffer, true)
                serializeInt32(_data.readMaxId, buffer: buffer, boxed: false)
                break
            case .updateReadStories(let _data):
                if boxed {
                    buffer.appendInt32(-145845461)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.maxId, buffer: buffer, boxed: false)
                break
            case .updateRecentEmojiStatuses:
                if boxed {
                    buffer.appendInt32(821314523)
                }
                break
            case .updateRecentReactions:
                if boxed {
                    buffer.appendInt32(1870160884)
                }
                break
            case .updateRecentStickers:
                if boxed {
                    buffer.appendInt32(-1706939360)
                }
                break
            case .updateSavedDialogPinned(let _data):
                if boxed {
                    buffer.appendInt32(-1364222348)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                break
            case .updateSavedGifs:
                if boxed {
                    buffer.appendInt32(-1821035490)
                }
                break
            case .updateSavedReactionTags:
                if boxed {
                    buffer.appendInt32(969307186)
                }
                break
            case .updateSavedRingtones:
                if boxed {
                    buffer.appendInt32(1960361625)
                }
                break
            case .updateSentPhoneCode(let _data):
                if boxed {
                    buffer.appendInt32(1347068303)
                }
                _data.sentCode.serialize(buffer, true)
                break
            case .updateSentStoryReaction(let _data):
                if boxed {
                    buffer.appendInt32(2103604867)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.storyId, buffer: buffer, boxed: false)
                _data.reaction.serialize(buffer, true)
                break
            case .updateServiceNotification(let _data):
                if boxed {
                    buffer.appendInt32(-337352679)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.inboxDate!, buffer: buffer, boxed: false)
                }
                serializeString(_data.type, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                _data.media.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.entities.count))
                for item in _data.entities {
                    item.serialize(buffer, true)
                }
                break
            case .updateSmsJob(let _data):
                if boxed {
                    buffer.appendInt32(-245208620)
                }
                serializeString(_data.jobId, buffer: buffer, boxed: false)
                break
            case .updateStarGiftAuctionState(let _data):
                if boxed {
                    buffer.appendInt32(1222788802)
                }
                serializeInt64(_data.giftId, buffer: buffer, boxed: false)
                _data.state.serialize(buffer, true)
                break
            case .updateStarGiftAuctionUserState(let _data):
                if boxed {
                    buffer.appendInt32(-598150370)
                }
                serializeInt64(_data.giftId, buffer: buffer, boxed: false)
                _data.userState.serialize(buffer, true)
                break
            case .updateStarGiftCraftFail:
                if boxed {
                    buffer.appendInt32(-1408818108)
                }
                break
            case .updateStarsBalance(let _data):
                if boxed {
                    buffer.appendInt32(1317053305)
                }
                _data.balance.serialize(buffer, true)
                break
            case .updateStarsRevenueStatus(let _data):
                if boxed {
                    buffer.appendInt32(-1518030823)
                }
                _data.peer.serialize(buffer, true)
                _data.status.serialize(buffer, true)
                break
            case .updateStickerSets(let _data):
                if boxed {
                    buffer.appendInt32(834816008)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .updateStickerSetsOrder(let _data):
                if boxed {
                    buffer.appendInt32(196268545)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.order.count))
                for item in _data.order {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .updateStoriesStealthMode(let _data):
                if boxed {
                    buffer.appendInt32(738741697)
                }
                _data.stealthMode.serialize(buffer, true)
                break
            case .updateStory(let _data):
                if boxed {
                    buffer.appendInt32(1974712216)
                }
                _data.peer.serialize(buffer, true)
                _data.story.serialize(buffer, true)
                break
            case .updateStoryID(let _data):
                if boxed {
                    buffer.appendInt32(468923833)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                break
            case .updateTheme(let _data):
                if boxed {
                    buffer.appendInt32(-2112423005)
                }
                _data.theme.serialize(buffer, true)
                break
            case .updateTranscribedAudio(let _data):
                if boxed {
                    buffer.appendInt32(8703322)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.transcriptionId, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .updateUser(let _data):
                if boxed {
                    buffer.appendInt32(542282808)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .updateUserEmojiStatus(let _data):
                if boxed {
                    buffer.appendInt32(674706841)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.emojiStatus.serialize(buffer, true)
                break
            case .updateUserName(let _data):
                if boxed {
                    buffer.appendInt32(-1484486364)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.firstName, buffer: buffer, boxed: false)
                serializeString(_data.lastName, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.usernames.count))
                for item in _data.usernames {
                    item.serialize(buffer, true)
                }
                break
            case .updateUserPhone(let _data):
                if boxed {
                    buffer.appendInt32(88680979)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.phone, buffer: buffer, boxed: false)
                break
            case .updateUserStatus(let _data):
                if boxed {
                    buffer.appendInt32(-440534818)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.status.serialize(buffer, true)
                break
            case .updateUserTyping(let _data):
                if boxed {
                    buffer.appendInt32(706199388)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                _data.action.serialize(buffer, true)
                break
            case .updateWebPage(let _data):
                if boxed {
                    buffer.appendInt32(2139689491)
                }
                _data.webpage.serialize(buffer, true)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            case .updateWebViewResultSent(let _data):
                if boxed {
                    buffer.appendInt32(361936797)
                }
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .updateAttachMenuBots:
                return ("updateAttachMenuBots", [])
            case .updateAutoSaveSettings:
                return ("updateAutoSaveSettings", [])
            case .updateBotBusinessConnect(let _data):
                return ("updateBotBusinessConnect", [("connection", _data.connection as Any), ("qts", _data.qts as Any)])
            case .updateBotCallbackQuery(let _data):
                return ("updateBotCallbackQuery", [("flags", _data.flags as Any), ("queryId", _data.queryId as Any), ("userId", _data.userId as Any), ("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("chatInstance", _data.chatInstance as Any), ("data", _data.data as Any), ("gameShortName", _data.gameShortName as Any)])
            case .updateBotChatBoost(let _data):
                return ("updateBotChatBoost", [("peer", _data.peer as Any), ("boost", _data.boost as Any), ("qts", _data.qts as Any)])
            case .updateBotChatInviteRequester(let _data):
                return ("updateBotChatInviteRequester", [("peer", _data.peer as Any), ("date", _data.date as Any), ("userId", _data.userId as Any), ("about", _data.about as Any), ("invite", _data.invite as Any), ("qts", _data.qts as Any)])
            case .updateBotCommands(let _data):
                return ("updateBotCommands", [("peer", _data.peer as Any), ("botId", _data.botId as Any), ("commands", _data.commands as Any)])
            case .updateBotDeleteBusinessMessage(let _data):
                return ("updateBotDeleteBusinessMessage", [("connectionId", _data.connectionId as Any), ("peer", _data.peer as Any), ("messages", _data.messages as Any), ("qts", _data.qts as Any)])
            case .updateBotEditBusinessMessage(let _data):
                return ("updateBotEditBusinessMessage", [("flags", _data.flags as Any), ("connectionId", _data.connectionId as Any), ("message", _data.message as Any), ("replyToMessage", _data.replyToMessage as Any), ("qts", _data.qts as Any)])
            case .updateBotInlineQuery(let _data):
                return ("updateBotInlineQuery", [("flags", _data.flags as Any), ("queryId", _data.queryId as Any), ("userId", _data.userId as Any), ("query", _data.query as Any), ("geo", _data.geo as Any), ("peerType", _data.peerType as Any), ("offset", _data.offset as Any)])
            case .updateBotInlineSend(let _data):
                return ("updateBotInlineSend", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("query", _data.query as Any), ("geo", _data.geo as Any), ("id", _data.id as Any), ("msgId", _data.msgId as Any)])
            case .updateBotMenuButton(let _data):
                return ("updateBotMenuButton", [("botId", _data.botId as Any), ("button", _data.button as Any)])
            case .updateBotMessageReaction(let _data):
                return ("updateBotMessageReaction", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("date", _data.date as Any), ("actor", _data.actor as Any), ("oldReactions", _data.oldReactions as Any), ("newReactions", _data.newReactions as Any), ("qts", _data.qts as Any)])
            case .updateBotMessageReactions(let _data):
                return ("updateBotMessageReactions", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("date", _data.date as Any), ("reactions", _data.reactions as Any), ("qts", _data.qts as Any)])
            case .updateBotNewBusinessMessage(let _data):
                return ("updateBotNewBusinessMessage", [("flags", _data.flags as Any), ("connectionId", _data.connectionId as Any), ("message", _data.message as Any), ("replyToMessage", _data.replyToMessage as Any), ("qts", _data.qts as Any)])
            case .updateBotPrecheckoutQuery(let _data):
                return ("updateBotPrecheckoutQuery", [("flags", _data.flags as Any), ("queryId", _data.queryId as Any), ("userId", _data.userId as Any), ("payload", _data.payload as Any), ("info", _data.info as Any), ("shippingOptionId", _data.shippingOptionId as Any), ("currency", _data.currency as Any), ("totalAmount", _data.totalAmount as Any)])
            case .updateBotPurchasedPaidMedia(let _data):
                return ("updateBotPurchasedPaidMedia", [("userId", _data.userId as Any), ("payload", _data.payload as Any), ("qts", _data.qts as Any)])
            case .updateBotShippingQuery(let _data):
                return ("updateBotShippingQuery", [("queryId", _data.queryId as Any), ("userId", _data.userId as Any), ("payload", _data.payload as Any), ("shippingAddress", _data.shippingAddress as Any)])
            case .updateBotStopped(let _data):
                return ("updateBotStopped", [("userId", _data.userId as Any), ("date", _data.date as Any), ("stopped", _data.stopped as Any), ("qts", _data.qts as Any)])
            case .updateBotWebhookJSON(let _data):
                return ("updateBotWebhookJSON", [("data", _data.data as Any)])
            case .updateBotWebhookJSONQuery(let _data):
                return ("updateBotWebhookJSONQuery", [("queryId", _data.queryId as Any), ("data", _data.data as Any), ("timeout", _data.timeout as Any)])
            case .updateBusinessBotCallbackQuery(let _data):
                return ("updateBusinessBotCallbackQuery", [("flags", _data.flags as Any), ("queryId", _data.queryId as Any), ("userId", _data.userId as Any), ("connectionId", _data.connectionId as Any), ("message", _data.message as Any), ("replyToMessage", _data.replyToMessage as Any), ("chatInstance", _data.chatInstance as Any), ("data", _data.data as Any)])
            case .updateChannel(let _data):
                return ("updateChannel", [("channelId", _data.channelId as Any)])
            case .updateChannelAvailableMessages(let _data):
                return ("updateChannelAvailableMessages", [("channelId", _data.channelId as Any), ("availableMinId", _data.availableMinId as Any)])
            case .updateChannelMessageForwards(let _data):
                return ("updateChannelMessageForwards", [("channelId", _data.channelId as Any), ("id", _data.id as Any), ("forwards", _data.forwards as Any)])
            case .updateChannelMessageViews(let _data):
                return ("updateChannelMessageViews", [("channelId", _data.channelId as Any), ("id", _data.id as Any), ("views", _data.views as Any)])
            case .updateChannelParticipant(let _data):
                return ("updateChannelParticipant", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("date", _data.date as Any), ("actorId", _data.actorId as Any), ("userId", _data.userId as Any), ("prevParticipant", _data.prevParticipant as Any), ("newParticipant", _data.newParticipant as Any), ("invite", _data.invite as Any), ("qts", _data.qts as Any)])
            case .updateChannelReadMessagesContents(let _data):
                return ("updateChannelReadMessagesContents", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("topMsgId", _data.topMsgId as Any), ("savedPeerId", _data.savedPeerId as Any), ("messages", _data.messages as Any)])
            case .updateChannelTooLong(let _data):
                return ("updateChannelTooLong", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("pts", _data.pts as Any)])
            case .updateChannelUserTyping(let _data):
                return ("updateChannelUserTyping", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("topMsgId", _data.topMsgId as Any), ("fromId", _data.fromId as Any), ("action", _data.action as Any)])
            case .updateChannelViewForumAsMessages(let _data):
                return ("updateChannelViewForumAsMessages", [("channelId", _data.channelId as Any), ("enabled", _data.enabled as Any)])
            case .updateChannelWebPage(let _data):
                return ("updateChannelWebPage", [("channelId", _data.channelId as Any), ("webpage", _data.webpage as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateChat(let _data):
                return ("updateChat", [("chatId", _data.chatId as Any)])
            case .updateChatDefaultBannedRights(let _data):
                return ("updateChatDefaultBannedRights", [("peer", _data.peer as Any), ("defaultBannedRights", _data.defaultBannedRights as Any), ("version", _data.version as Any)])
            case .updateChatParticipant(let _data):
                return ("updateChatParticipant", [("flags", _data.flags as Any), ("chatId", _data.chatId as Any), ("date", _data.date as Any), ("actorId", _data.actorId as Any), ("userId", _data.userId as Any), ("prevParticipant", _data.prevParticipant as Any), ("newParticipant", _data.newParticipant as Any), ("invite", _data.invite as Any), ("qts", _data.qts as Any)])
            case .updateChatParticipantAdd(let _data):
                return ("updateChatParticipantAdd", [("chatId", _data.chatId as Any), ("userId", _data.userId as Any), ("inviterId", _data.inviterId as Any), ("date", _data.date as Any), ("version", _data.version as Any)])
            case .updateChatParticipantAdmin(let _data):
                return ("updateChatParticipantAdmin", [("chatId", _data.chatId as Any), ("userId", _data.userId as Any), ("isAdmin", _data.isAdmin as Any), ("version", _data.version as Any)])
            case .updateChatParticipantDelete(let _data):
                return ("updateChatParticipantDelete", [("chatId", _data.chatId as Any), ("userId", _data.userId as Any), ("version", _data.version as Any)])
            case .updateChatParticipantRank(let _data):
                return ("updateChatParticipantRank", [("chatId", _data.chatId as Any), ("userId", _data.userId as Any), ("rank", _data.rank as Any), ("version", _data.version as Any)])
            case .updateChatParticipants(let _data):
                return ("updateChatParticipants", [("participants", _data.participants as Any)])
            case .updateChatUserTyping(let _data):
                return ("updateChatUserTyping", [("chatId", _data.chatId as Any), ("fromId", _data.fromId as Any), ("action", _data.action as Any)])
            case .updateConfig:
                return ("updateConfig", [])
            case .updateContactsReset:
                return ("updateContactsReset", [])
            case .updateDcOptions(let _data):
                return ("updateDcOptions", [("dcOptions", _data.dcOptions as Any)])
            case .updateDeleteChannelMessages(let _data):
                return ("updateDeleteChannelMessages", [("channelId", _data.channelId as Any), ("messages", _data.messages as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateDeleteGroupCallMessages(let _data):
                return ("updateDeleteGroupCallMessages", [("call", _data.call as Any), ("messages", _data.messages as Any)])
            case .updateDeleteMessages(let _data):
                return ("updateDeleteMessages", [("messages", _data.messages as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateDeleteQuickReply(let _data):
                return ("updateDeleteQuickReply", [("shortcutId", _data.shortcutId as Any)])
            case .updateDeleteQuickReplyMessages(let _data):
                return ("updateDeleteQuickReplyMessages", [("shortcutId", _data.shortcutId as Any), ("messages", _data.messages as Any)])
            case .updateDeleteScheduledMessages(let _data):
                return ("updateDeleteScheduledMessages", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("messages", _data.messages as Any), ("sentMessages", _data.sentMessages as Any)])
            case .updateDialogFilter(let _data):
                return ("updateDialogFilter", [("flags", _data.flags as Any), ("id", _data.id as Any), ("filter", _data.filter as Any)])
            case .updateDialogFilterOrder(let _data):
                return ("updateDialogFilterOrder", [("order", _data.order as Any)])
            case .updateDialogFilters:
                return ("updateDialogFilters", [])
            case .updateDialogPinned(let _data):
                return ("updateDialogPinned", [("flags", _data.flags as Any), ("folderId", _data.folderId as Any), ("peer", _data.peer as Any)])
            case .updateDialogUnreadMark(let _data):
                return ("updateDialogUnreadMark", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("savedPeerId", _data.savedPeerId as Any)])
            case .updateDraftMessage(let _data):
                return ("updateDraftMessage", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("topMsgId", _data.topMsgId as Any), ("savedPeerId", _data.savedPeerId as Any), ("draft", _data.draft as Any)])
            case .updateEditChannelMessage(let _data):
                return ("updateEditChannelMessage", [("message", _data.message as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateEditMessage(let _data):
                return ("updateEditMessage", [("message", _data.message as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateEmojiGameInfo(let _data):
                return ("updateEmojiGameInfo", [("info", _data.info as Any)])
            case .updateEncryptedChatTyping(let _data):
                return ("updateEncryptedChatTyping", [("chatId", _data.chatId as Any)])
            case .updateEncryptedMessagesRead(let _data):
                return ("updateEncryptedMessagesRead", [("chatId", _data.chatId as Any), ("maxDate", _data.maxDate as Any), ("date", _data.date as Any)])
            case .updateEncryption(let _data):
                return ("updateEncryption", [("chat", _data.chat as Any), ("date", _data.date as Any)])
            case .updateFavedStickers:
                return ("updateFavedStickers", [])
            case .updateFolderPeers(let _data):
                return ("updateFolderPeers", [("folderPeers", _data.folderPeers as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateGeoLiveViewed(let _data):
                return ("updateGeoLiveViewed", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any)])
            case .updateGroupCall(let _data):
                return ("updateGroupCall", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("call", _data.call as Any)])
            case .updateGroupCallChainBlocks(let _data):
                return ("updateGroupCallChainBlocks", [("call", _data.call as Any), ("subChainId", _data.subChainId as Any), ("blocks", _data.blocks as Any), ("nextOffset", _data.nextOffset as Any)])
            case .updateGroupCallConnection(let _data):
                return ("updateGroupCallConnection", [("flags", _data.flags as Any), ("params", _data.params as Any)])
            case .updateGroupCallEncryptedMessage(let _data):
                return ("updateGroupCallEncryptedMessage", [("call", _data.call as Any), ("fromId", _data.fromId as Any), ("encryptedMessage", _data.encryptedMessage as Any)])
            case .updateGroupCallMessage(let _data):
                return ("updateGroupCallMessage", [("call", _data.call as Any), ("message", _data.message as Any)])
            case .updateGroupCallParticipants(let _data):
                return ("updateGroupCallParticipants", [("call", _data.call as Any), ("participants", _data.participants as Any), ("version", _data.version as Any)])
            case .updateInlineBotCallbackQuery(let _data):
                return ("updateInlineBotCallbackQuery", [("flags", _data.flags as Any), ("queryId", _data.queryId as Any), ("userId", _data.userId as Any), ("msgId", _data.msgId as Any), ("chatInstance", _data.chatInstance as Any), ("data", _data.data as Any), ("gameShortName", _data.gameShortName as Any)])
            case .updateLangPack(let _data):
                return ("updateLangPack", [("difference", _data.difference as Any)])
            case .updateLangPackTooLong(let _data):
                return ("updateLangPackTooLong", [("langCode", _data.langCode as Any)])
            case .updateLoginToken:
                return ("updateLoginToken", [])
            case .updateMessageExtendedMedia(let _data):
                return ("updateMessageExtendedMedia", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("extendedMedia", _data.extendedMedia as Any)])
            case .updateMessageID(let _data):
                return ("updateMessageID", [("id", _data.id as Any), ("randomId", _data.randomId as Any)])
            case .updateMessagePoll(let _data):
                return ("updateMessagePoll", [("flags", _data.flags as Any), ("pollId", _data.pollId as Any), ("poll", _data.poll as Any), ("results", _data.results as Any)])
            case .updateMessagePollVote(let _data):
                return ("updateMessagePollVote", [("pollId", _data.pollId as Any), ("peer", _data.peer as Any), ("options", _data.options as Any), ("qts", _data.qts as Any)])
            case .updateMessageReactions(let _data):
                return ("updateMessageReactions", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("topMsgId", _data.topMsgId as Any), ("savedPeerId", _data.savedPeerId as Any), ("reactions", _data.reactions as Any)])
            case .updateMonoForumNoPaidException(let _data):
                return ("updateMonoForumNoPaidException", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("savedPeerId", _data.savedPeerId as Any)])
            case .updateMoveStickerSetToTop(let _data):
                return ("updateMoveStickerSetToTop", [("flags", _data.flags as Any), ("stickerset", _data.stickerset as Any)])
            case .updateNewAuthorization(let _data):
                return ("updateNewAuthorization", [("flags", _data.flags as Any), ("hash", _data.hash as Any), ("date", _data.date as Any), ("device", _data.device as Any), ("location", _data.location as Any)])
            case .updateNewChannelMessage(let _data):
                return ("updateNewChannelMessage", [("message", _data.message as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateNewEncryptedMessage(let _data):
                return ("updateNewEncryptedMessage", [("message", _data.message as Any), ("qts", _data.qts as Any)])
            case .updateNewMessage(let _data):
                return ("updateNewMessage", [("message", _data.message as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateNewQuickReply(let _data):
                return ("updateNewQuickReply", [("quickReply", _data.quickReply as Any)])
            case .updateNewScheduledMessage(let _data):
                return ("updateNewScheduledMessage", [("message", _data.message as Any)])
            case .updateNewStickerSet(let _data):
                return ("updateNewStickerSet", [("stickerset", _data.stickerset as Any)])
            case .updateNewStoryReaction(let _data):
                return ("updateNewStoryReaction", [("storyId", _data.storyId as Any), ("peer", _data.peer as Any), ("reaction", _data.reaction as Any)])
            case .updateNotifySettings(let _data):
                return ("updateNotifySettings", [("peer", _data.peer as Any), ("notifySettings", _data.notifySettings as Any)])
            case .updatePaidReactionPrivacy(let _data):
                return ("updatePaidReactionPrivacy", [("`private`", _data.`private` as Any)])
            case .updatePeerBlocked(let _data):
                return ("updatePeerBlocked", [("flags", _data.flags as Any), ("peerId", _data.peerId as Any)])
            case .updatePeerHistoryTTL(let _data):
                return ("updatePeerHistoryTTL", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("ttlPeriod", _data.ttlPeriod as Any)])
            case .updatePeerLocated(let _data):
                return ("updatePeerLocated", [("peers", _data.peers as Any)])
            case .updatePeerSettings(let _data):
                return ("updatePeerSettings", [("peer", _data.peer as Any), ("settings", _data.settings as Any)])
            case .updatePeerWallpaper(let _data):
                return ("updatePeerWallpaper", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("wallpaper", _data.wallpaper as Any)])
            case .updatePendingJoinRequests(let _data):
                return ("updatePendingJoinRequests", [("peer", _data.peer as Any), ("requestsPending", _data.requestsPending as Any), ("recentRequesters", _data.recentRequesters as Any)])
            case .updatePhoneCall(let _data):
                return ("updatePhoneCall", [("phoneCall", _data.phoneCall as Any)])
            case .updatePhoneCallSignalingData(let _data):
                return ("updatePhoneCallSignalingData", [("phoneCallId", _data.phoneCallId as Any), ("data", _data.data as Any)])
            case .updatePinnedChannelMessages(let _data):
                return ("updatePinnedChannelMessages", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("messages", _data.messages as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updatePinnedDialogs(let _data):
                return ("updatePinnedDialogs", [("flags", _data.flags as Any), ("folderId", _data.folderId as Any), ("order", _data.order as Any)])
            case .updatePinnedForumTopic(let _data):
                return ("updatePinnedForumTopic", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("topicId", _data.topicId as Any)])
            case .updatePinnedForumTopics(let _data):
                return ("updatePinnedForumTopics", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("order", _data.order as Any)])
            case .updatePinnedMessages(let _data):
                return ("updatePinnedMessages", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("messages", _data.messages as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updatePinnedSavedDialogs(let _data):
                return ("updatePinnedSavedDialogs", [("flags", _data.flags as Any), ("order", _data.order as Any)])
            case .updatePrivacy(let _data):
                return ("updatePrivacy", [("key", _data.key as Any), ("rules", _data.rules as Any)])
            case .updatePtsChanged:
                return ("updatePtsChanged", [])
            case .updateQuickReplies(let _data):
                return ("updateQuickReplies", [("quickReplies", _data.quickReplies as Any)])
            case .updateQuickReplyMessage(let _data):
                return ("updateQuickReplyMessage", [("message", _data.message as Any)])
            case .updateReadChannelDiscussionInbox(let _data):
                return ("updateReadChannelDiscussionInbox", [("flags", _data.flags as Any), ("channelId", _data.channelId as Any), ("topMsgId", _data.topMsgId as Any), ("readMaxId", _data.readMaxId as Any), ("broadcastId", _data.broadcastId as Any), ("broadcastPost", _data.broadcastPost as Any)])
            case .updateReadChannelDiscussionOutbox(let _data):
                return ("updateReadChannelDiscussionOutbox", [("channelId", _data.channelId as Any), ("topMsgId", _data.topMsgId as Any), ("readMaxId", _data.readMaxId as Any)])
            case .updateReadChannelInbox(let _data):
                return ("updateReadChannelInbox", [("flags", _data.flags as Any), ("folderId", _data.folderId as Any), ("channelId", _data.channelId as Any), ("maxId", _data.maxId as Any), ("stillUnreadCount", _data.stillUnreadCount as Any), ("pts", _data.pts as Any)])
            case .updateReadChannelOutbox(let _data):
                return ("updateReadChannelOutbox", [("channelId", _data.channelId as Any), ("maxId", _data.maxId as Any)])
            case .updateReadFeaturedEmojiStickers:
                return ("updateReadFeaturedEmojiStickers", [])
            case .updateReadFeaturedStickers:
                return ("updateReadFeaturedStickers", [])
            case .updateReadHistoryInbox(let _data):
                return ("updateReadHistoryInbox", [("flags", _data.flags as Any), ("folderId", _data.folderId as Any), ("peer", _data.peer as Any), ("topMsgId", _data.topMsgId as Any), ("maxId", _data.maxId as Any), ("stillUnreadCount", _data.stillUnreadCount as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateReadHistoryOutbox(let _data):
                return ("updateReadHistoryOutbox", [("peer", _data.peer as Any), ("maxId", _data.maxId as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateReadMessagesContents(let _data):
                return ("updateReadMessagesContents", [("flags", _data.flags as Any), ("messages", _data.messages as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any), ("date", _data.date as Any)])
            case .updateReadMonoForumInbox(let _data):
                return ("updateReadMonoForumInbox", [("channelId", _data.channelId as Any), ("savedPeerId", _data.savedPeerId as Any), ("readMaxId", _data.readMaxId as Any)])
            case .updateReadMonoForumOutbox(let _data):
                return ("updateReadMonoForumOutbox", [("channelId", _data.channelId as Any), ("savedPeerId", _data.savedPeerId as Any), ("readMaxId", _data.readMaxId as Any)])
            case .updateReadStories(let _data):
                return ("updateReadStories", [("peer", _data.peer as Any), ("maxId", _data.maxId as Any)])
            case .updateRecentEmojiStatuses:
                return ("updateRecentEmojiStatuses", [])
            case .updateRecentReactions:
                return ("updateRecentReactions", [])
            case .updateRecentStickers:
                return ("updateRecentStickers", [])
            case .updateSavedDialogPinned(let _data):
                return ("updateSavedDialogPinned", [("flags", _data.flags as Any), ("peer", _data.peer as Any)])
            case .updateSavedGifs:
                return ("updateSavedGifs", [])
            case .updateSavedReactionTags:
                return ("updateSavedReactionTags", [])
            case .updateSavedRingtones:
                return ("updateSavedRingtones", [])
            case .updateSentPhoneCode(let _data):
                return ("updateSentPhoneCode", [("sentCode", _data.sentCode as Any)])
            case .updateSentStoryReaction(let _data):
                return ("updateSentStoryReaction", [("peer", _data.peer as Any), ("storyId", _data.storyId as Any), ("reaction", _data.reaction as Any)])
            case .updateServiceNotification(let _data):
                return ("updateServiceNotification", [("flags", _data.flags as Any), ("inboxDate", _data.inboxDate as Any), ("type", _data.type as Any), ("message", _data.message as Any), ("media", _data.media as Any), ("entities", _data.entities as Any)])
            case .updateSmsJob(let _data):
                return ("updateSmsJob", [("jobId", _data.jobId as Any)])
            case .updateStarGiftAuctionState(let _data):
                return ("updateStarGiftAuctionState", [("giftId", _data.giftId as Any), ("state", _data.state as Any)])
            case .updateStarGiftAuctionUserState(let _data):
                return ("updateStarGiftAuctionUserState", [("giftId", _data.giftId as Any), ("userState", _data.userState as Any)])
            case .updateStarGiftCraftFail:
                return ("updateStarGiftCraftFail", [])
            case .updateStarsBalance(let _data):
                return ("updateStarsBalance", [("balance", _data.balance as Any)])
            case .updateStarsRevenueStatus(let _data):
                return ("updateStarsRevenueStatus", [("peer", _data.peer as Any), ("status", _data.status as Any)])
            case .updateStickerSets(let _data):
                return ("updateStickerSets", [("flags", _data.flags as Any)])
            case .updateStickerSetsOrder(let _data):
                return ("updateStickerSetsOrder", [("flags", _data.flags as Any), ("order", _data.order as Any)])
            case .updateStoriesStealthMode(let _data):
                return ("updateStoriesStealthMode", [("stealthMode", _data.stealthMode as Any)])
            case .updateStory(let _data):
                return ("updateStory", [("peer", _data.peer as Any), ("story", _data.story as Any)])
            case .updateStoryID(let _data):
                return ("updateStoryID", [("id", _data.id as Any), ("randomId", _data.randomId as Any)])
            case .updateTheme(let _data):
                return ("updateTheme", [("theme", _data.theme as Any)])
            case .updateTranscribedAudio(let _data):
                return ("updateTranscribedAudio", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("transcriptionId", _data.transcriptionId as Any), ("text", _data.text as Any)])
            case .updateUser(let _data):
                return ("updateUser", [("userId", _data.userId as Any)])
            case .updateUserEmojiStatus(let _data):
                return ("updateUserEmojiStatus", [("userId", _data.userId as Any), ("emojiStatus", _data.emojiStatus as Any)])
            case .updateUserName(let _data):
                return ("updateUserName", [("userId", _data.userId as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("usernames", _data.usernames as Any)])
            case .updateUserPhone(let _data):
                return ("updateUserPhone", [("userId", _data.userId as Any), ("phone", _data.phone as Any)])
            case .updateUserStatus(let _data):
                return ("updateUserStatus", [("userId", _data.userId as Any), ("status", _data.status as Any)])
            case .updateUserTyping(let _data):
                return ("updateUserTyping", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("topMsgId", _data.topMsgId as Any), ("action", _data.action as Any)])
            case .updateWebPage(let _data):
                return ("updateWebPage", [("webpage", _data.webpage as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any)])
            case .updateWebViewResultSent(let _data):
                return ("updateWebViewResultSent", [("queryId", _data.queryId as Any)])
            }
        }

        public static func parse_updateAttachMenuBots(_ reader: BufferReader) -> Update? {
            return Api.Update.updateAttachMenuBots
        }
        public static func parse_updateAutoSaveSettings(_ reader: BufferReader) -> Update? {
            return Api.Update.updateAutoSaveSettings
        }
        public static func parse_updateBotBusinessConnect(_ reader: BufferReader) -> Update? {
            var _1: Api.BotBusinessConnection?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.BotBusinessConnection
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateBotBusinessConnect(Cons_updateBotBusinessConnect(connection: _1!, qts: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {
                _7 = parseBytes(reader)
            }
            var _8: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _8 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBotCallbackQuery(Cons_updateBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, peer: _4!, msgId: _5!, chatInstance: _6!, data: _7, gameShortName: _8))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotChatBoost(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.Boost?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Boost
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotChatBoost(Cons_updateBotChatBoost(peer: _1!, boost: _2!, qts: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotChatInviteRequester(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateBotChatInviteRequester(Cons_updateBotChatInviteRequester(peer: _1!, date: _2!, userId: _3!, about: _4!, invite: _5!, qts: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotCommands(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.BotCommand]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotCommand.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotCommands(Cons_updateBotCommands(peer: _1!, botId: _2!, commands: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotDeleteBusinessMessage(_ reader: BufferReader) -> Update? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotDeleteBusinessMessage(Cons_updateBotDeleteBusinessMessage(connectionId: _1!, peer: _2!, messages: _3!, qts: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotEditBusinessMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Message?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _4: Api.Message?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Message
                }
            }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateBotEditBusinessMessage(Cons_updateBotEditBusinessMessage(flags: _1!, connectionId: _2!, message: _3!, replyToMessage: _4, qts: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotInlineQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.GeoPoint
                }
            }
            var _6: Api.InlineQueryPeerType?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.InlineQueryPeerType
                }
            }
            var _7: String?
            _7 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateBotInlineQuery(Cons_updateBotInlineQuery(flags: _1!, queryId: _2!, userId: _3!, query: _4!, geo: _5, peerType: _6, offset: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotInlineSend(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.GeoPoint
                }
            }
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.InputBotInlineMessageID?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateBotInlineSend(Cons_updateBotInlineSend(flags: _1!, userId: _2!, query: _3!, geo: _4, id: _5!, msgId: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotMenuButton(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.BotMenuButton?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BotMenuButton
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateBotMenuButton(Cons_updateBotMenuButton(botId: _1!, button: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotMessageReaction(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: [Api.Reaction]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Reaction.self)
            }
            var _6: [Api.Reaction]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Reaction.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateBotMessageReaction(Cons_updateBotMessageReaction(peer: _1!, msgId: _2!, date: _3!, actor: _4!, oldReactions: _5!, newReactions: _6!, qts: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotMessageReactions(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.ReactionCount]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReactionCount.self)
            }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateBotMessageReactions(Cons_updateBotMessageReactions(peer: _1!, msgId: _2!, date: _3!, reactions: _4!, qts: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotNewBusinessMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Message?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _4: Api.Message?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Message
                }
            }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateBotNewBusinessMessage(Cons_updateBotNewBusinessMessage(flags: _1!, connectionId: _2!, message: _3!, replyToMessage: _4, qts: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotPrecheckoutQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
                }
            }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            _7 = parseString(reader)
            var _8: Int64?
            _8 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBotPrecheckoutQuery(Cons_updateBotPrecheckoutQuery(flags: _1!, queryId: _2!, userId: _3!, payload: _4!, info: _5, shippingOptionId: _6, currency: _7!, totalAmount: _8!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotPurchasedPaidMedia(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotPurchasedPaidMedia(Cons_updateBotPurchasedPaidMedia(userId: _1!, payload: _2!, qts: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotShippingQuery(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Api.PostAddress?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PostAddress
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotShippingQuery(Cons_updateBotShippingQuery(queryId: _1!, userId: _2!, payload: _3!, shippingAddress: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotStopped(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotStopped(Cons_updateBotStopped(userId: _1!, date: _2!, stopped: _3!, qts: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotWebhookJSON(_ reader: BufferReader) -> Update? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateBotWebhookJSON(Cons_updateBotWebhookJSON(data: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotWebhookJSONQuery(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotWebhookJSONQuery(Cons_updateBotWebhookJSONQuery(queryId: _1!, data: _2!, timeout: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateBusinessBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.Message?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _6: Api.Message?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Message
                }
            }
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {
                _8 = parseBytes(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBusinessBotCallbackQuery(Cons_updateBusinessBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, connectionId: _4!, message: _5!, replyToMessage: _6, chatInstance: _7!, data: _8))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannel(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChannel(Cons_updateChannel(channelId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelAvailableMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateChannelAvailableMessages(Cons_updateChannelAvailableMessages(channelId: _1!, availableMinId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelMessageForwards(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelMessageForwards(Cons_updateChannelMessageForwards(channelId: _1!, id: _2!, forwards: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelMessageViews(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelMessageViews(Cons_updateChannelMessageViews(channelId: _1!, id: _2!, views: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelParticipant(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.ChannelParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
                }
            }
            var _7: Api.ChannelParticipant?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
                }
            }
            var _8: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                }
            }
            var _9: Int32?
            _9 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Update.updateChannelParticipant(Cons_updateChannelParticipant(flags: _1!, channelId: _2!, date: _3!, actorId: _4!, userId: _5!, prevParticipant: _6, newParticipant: _7, invite: _8, qts: _9!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelReadMessagesContents(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _5: [Int32]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateChannelReadMessagesContents(Cons_updateChannelReadMessagesContents(flags: _1!, channelId: _2!, topMsgId: _3, savedPeerId: _4, messages: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelTooLong(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelTooLong(Cons_updateChannelTooLong(flags: _1!, channelId: _2!, pts: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateChannelUserTyping(Cons_updateChannelUserTyping(flags: _1!, channelId: _2!, topMsgId: _3, fromId: _4!, action: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelViewForumAsMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateChannelViewForumAsMessages(Cons_updateChannelViewForumAsMessages(channelId: _1!, enabled: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelWebPage(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.WebPage?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateChannelWebPage(Cons_updateChannelWebPage(channelId: _1!, webpage: _2!, pts: _3!, ptsCount: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChat(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChat(Cons_updateChat(chatId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatDefaultBannedRights(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatDefaultBannedRights(Cons_updateChatDefaultBannedRights(peer: _1!, defaultBannedRights: _2!, version: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipant(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
                }
            }
            var _7: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
                }
            }
            var _8: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                }
            }
            var _9: Int32?
            _9 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Update.updateChatParticipant(Cons_updateChatParticipant(flags: _1!, chatId: _2!, date: _3!, actorId: _4!, userId: _5!, prevParticipant: _6, newParticipant: _7, invite: _8, qts: _9!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantAdd(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateChatParticipantAdd(Cons_updateChatParticipantAdd(chatId: _1!, userId: _2!, inviterId: _3!, date: _4!, version: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantAdmin(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateChatParticipantAdmin(Cons_updateChatParticipantAdmin(chatId: _1!, userId: _2!, isAdmin: _3!, version: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantDelete(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatParticipantDelete(Cons_updateChatParticipantDelete(chatId: _1!, userId: _2!, version: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantRank(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateChatParticipantRank(Cons_updateChatParticipantRank(chatId: _1!, userId: _2!, rank: _3!, version: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipants(_ reader: BufferReader) -> Update? {
            var _1: Api.ChatParticipants?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatParticipants
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChatParticipants(Cons_updateChatParticipants(participants: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatUserTyping(Cons_updateChatUserTyping(chatId: _1!, fromId: _2!, action: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateConfig(_ reader: BufferReader) -> Update? {
            return Api.Update.updateConfig
        }
        public static func parse_updateContactsReset(_ reader: BufferReader) -> Update? {
            return Api.Update.updateContactsReset
        }
        public static func parse_updateDcOptions(_ reader: BufferReader) -> Update? {
            var _1: [Api.DcOption]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DcOption.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDcOptions(Cons_updateDcOptions(dcOptions: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteChannelMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateDeleteChannelMessages(Cons_updateDeleteChannelMessages(channelId: _1!, messages: _2!, pts: _3!, ptsCount: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteGroupCallMessages(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateDeleteGroupCallMessages(Cons_updateDeleteGroupCallMessages(call: _1!, messages: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteMessages(_ reader: BufferReader) -> Update? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDeleteMessages(Cons_updateDeleteMessages(messages: _1!, pts: _2!, ptsCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteQuickReply(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDeleteQuickReply(Cons_updateDeleteQuickReply(shortcutId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteQuickReplyMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateDeleteQuickReplyMessages(Cons_updateDeleteQuickReplyMessages(shortcutId: _1!, messages: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteScheduledMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _4: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateDeleteScheduledMessages(Cons_updateDeleteScheduledMessages(flags: _1!, peer: _2!, messages: _3!, sentMessages: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilter(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.DialogFilter?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.DialogFilter
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogFilter(Cons_updateDialogFilter(flags: _1!, id: _2!, filter: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilterOrder(_ reader: BufferReader) -> Update? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDialogFilterOrder(Cons_updateDialogFilterOrder(order: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilters(_ reader: BufferReader) -> Update? {
            return Api.Update.updateDialogFilters
        }
        public static func parse_updateDialogPinned(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogPinned(Cons_updateDialogPinned(flags: _1!, folderId: _2, peer: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogUnreadMark(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogUnreadMark(Cons_updateDialogUnreadMark(flags: _1!, peer: _2!, savedPeerId: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_updateDraftMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _5: Api.DraftMessage?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateDraftMessage(Cons_updateDraftMessage(flags: _1!, peer: _2!, topMsgId: _3, savedPeerId: _4, draft: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateEditChannelMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEditChannelMessage(Cons_updateEditChannelMessage(message: _1!, pts: _2!, ptsCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateEditMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEditMessage(Cons_updateEditMessage(message: _1!, pts: _2!, ptsCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateEmojiGameInfo(_ reader: BufferReader) -> Update? {
            var _1: Api.messages.EmojiGameInfo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.messages.EmojiGameInfo
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateEmojiGameInfo(Cons_updateEmojiGameInfo(info: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryptedChatTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateEncryptedChatTyping(Cons_updateEncryptedChatTyping(chatId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryptedMessagesRead(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEncryptedMessagesRead(Cons_updateEncryptedMessagesRead(chatId: _1!, maxDate: _2!, date: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryption(_ reader: BufferReader) -> Update? {
            var _1: Api.EncryptedChat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EncryptedChat
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateEncryption(Cons_updateEncryption(chat: _1!, date: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateFavedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateFavedStickers
        }
        public static func parse_updateFolderPeers(_ reader: BufferReader) -> Update? {
            var _1: [Api.FolderPeer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FolderPeer.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateFolderPeers(Cons_updateFolderPeers(folderPeers: _1!, pts: _2!, ptsCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateGeoLiveViewed(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGeoLiveViewed(Cons_updateGeoLiveViewed(peer: _1!, msgId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCall(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Api.GroupCall?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.GroupCall
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateGroupCall(Cons_updateGroupCall(flags: _1!, peer: _2, call: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallChainBlocks(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Buffer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateGroupCallChainBlocks(Cons_updateGroupCallChainBlocks(call: _1!, subChainId: _2!, blocks: _3!, nextOffset: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallConnection(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGroupCallConnection(Cons_updateGroupCallConnection(flags: _1!, params: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallEncryptedMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateGroupCallEncryptedMessage(Cons_updateGroupCallEncryptedMessage(call: _1!, fromId: _2!, encryptedMessage: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: Api.GroupCallMessage?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GroupCallMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGroupCallMessage(Cons_updateGroupCallMessage(call: _1!, message: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallParticipants(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateGroupCallParticipants(Cons_updateGroupCallParticipants(call: _1!, participants: _2!, version: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateInlineBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.InputBotInlineMessageID?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
            }
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseBytes(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _7 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateInlineBotCallbackQuery(Cons_updateInlineBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, msgId: _4!, chatInstance: _5!, data: _6, gameShortName: _7))
            }
            else {
                return nil
            }
        }
        public static func parse_updateLangPack(_ reader: BufferReader) -> Update? {
            var _1: Api.LangPackDifference?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.LangPackDifference
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateLangPack(Cons_updateLangPack(difference: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateLangPackTooLong(_ reader: BufferReader) -> Update? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateLangPackTooLong(Cons_updateLangPackTooLong(langCode: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateLoginToken(_ reader: BufferReader) -> Update? {
            return Api.Update.updateLoginToken
        }
        public static func parse_updateMessageExtendedMedia(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessageExtendedMedia]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageExtendedMedia.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateMessageExtendedMedia(Cons_updateMessageExtendedMedia(peer: _1!, msgId: _2!, extendedMedia: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessageID(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateMessageID(Cons_updateMessageID(id: _1!, randomId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessagePoll(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Poll?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Poll
                }
            }
            var _4: Api.PollResults?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PollResults
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateMessagePoll(Cons_updateMessagePoll(flags: _1!, pollId: _2!, poll: _3, results: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessagePollVote(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Buffer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateMessagePollVote(Cons_updateMessagePollVote(pollId: _1!, peer: _2!, options: _3!, qts: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessageReactions(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _6: Api.MessageReactions?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.MessageReactions
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateMessageReactions(Cons_updateMessageReactions(flags: _1!, peer: _2!, msgId: _3!, topMsgId: _4, savedPeerId: _5, reactions: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateMonoForumNoPaidException(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateMonoForumNoPaidException(Cons_updateMonoForumNoPaidException(flags: _1!, channelId: _2!, savedPeerId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateMoveStickerSetToTop(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateMoveStickerSetToTop(Cons_updateMoveStickerSetToTop(flags: _1!, stickerset: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewAuthorization(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateNewAuthorization(Cons_updateNewAuthorization(flags: _1!, hash: _2!, date: _3, device: _4, location: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewChannelMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateNewChannelMessage(Cons_updateNewChannelMessage(message: _1!, pts: _2!, ptsCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewEncryptedMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.EncryptedMessage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EncryptedMessage
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateNewEncryptedMessage(Cons_updateNewEncryptedMessage(message: _1!, qts: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateNewMessage(Cons_updateNewMessage(message: _1!, pts: _2!, ptsCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewQuickReply(_ reader: BufferReader) -> Update? {
            var _1: Api.QuickReply?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.QuickReply
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewQuickReply(Cons_updateNewQuickReply(quickReply: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewScheduledMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewScheduledMessage(Cons_updateNewScheduledMessage(message: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewStickerSet(_ reader: BufferReader) -> Update? {
            var _1: Api.messages.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewStickerSet(Cons_updateNewStickerSet(stickerset: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewStoryReaction(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateNewStoryReaction(Cons_updateNewStoryReaction(storyId: _1!, peer: _2!, reaction: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateNotifySettings(_ reader: BufferReader) -> Update? {
            var _1: Api.NotifyPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.NotifyPeer
            }
            var _2: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateNotifySettings(Cons_updateNotifySettings(peer: _1!, notifySettings: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePaidReactionPrivacy(_ reader: BufferReader) -> Update? {
            var _1: Api.PaidReactionPrivacy?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PaidReactionPrivacy
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePaidReactionPrivacy(Cons_updatePaidReactionPrivacy(private: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerBlocked(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePeerBlocked(Cons_updatePeerBlocked(flags: _1!, peerId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerHistoryTTL(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePeerHistoryTTL(Cons_updatePeerHistoryTTL(flags: _1!, peer: _2!, ttlPeriod: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerLocated(_ reader: BufferReader) -> Update? {
            var _1: [Api.PeerLocated]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerLocated.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePeerLocated(Cons_updatePeerLocated(peers: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerSettings(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePeerSettings(Cons_updatePeerSettings(peer: _1!, settings: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerWallpaper(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.WallPaper?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.WallPaper
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePeerWallpaper(Cons_updatePeerWallpaper(flags: _1!, peer: _2!, wallpaper: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePendingJoinRequests(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Int64]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePendingJoinRequests(Cons_updatePendingJoinRequests(peer: _1!, requestsPending: _2!, recentRequesters: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePhoneCall(_ reader: BufferReader) -> Update? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePhoneCall(Cons_updatePhoneCall(phoneCall: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePhoneCallSignalingData(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePhoneCallSignalingData(Cons_updatePhoneCallSignalingData(phoneCallId: _1!, data: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedChannelMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updatePinnedChannelMessages(Cons_updatePinnedChannelMessages(flags: _1!, channelId: _2!, messages: _3!, pts: _4!, ptsCount: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedDialogs(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            var _3: [Api.DialogPeer]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogPeer.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePinnedDialogs(Cons_updatePinnedDialogs(flags: _1!, folderId: _2, order: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedForumTopic(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePinnedForumTopic(Cons_updatePinnedForumTopic(flags: _1!, peer: _2!, topicId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedForumTopics(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePinnedForumTopics(Cons_updatePinnedForumTopics(flags: _1!, peer: _2!, order: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updatePinnedMessages(Cons_updatePinnedMessages(flags: _1!, peer: _2!, messages: _3!, pts: _4!, ptsCount: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedSavedDialogs(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.DialogPeer]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogPeer.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePinnedSavedDialogs(Cons_updatePinnedSavedDialogs(flags: _1!, order: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePrivacy(_ reader: BufferReader) -> Update? {
            var _1: Api.PrivacyKey?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PrivacyKey
            }
            var _2: [Api.PrivacyRule]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePrivacy(Cons_updatePrivacy(key: _1!, rules: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatePtsChanged(_ reader: BufferReader) -> Update? {
            return Api.Update.updatePtsChanged
        }
        public static func parse_updateQuickReplies(_ reader: BufferReader) -> Update? {
            var _1: [Api.QuickReply]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.QuickReply.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateQuickReplies(Cons_updateQuickReplies(quickReplies: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateQuickReplyMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateQuickReplyMessage(Cons_updateQuickReplyMessage(message: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelDiscussionInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt64()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateReadChannelDiscussionInbox(Cons_updateReadChannelDiscussionInbox(flags: _1!, channelId: _2!, topMsgId: _3!, readMaxId: _4!, broadcastId: _5, broadcastPost: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelDiscussionOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateReadChannelDiscussionOutbox(Cons_updateReadChannelDiscussionOutbox(channelId: _1!, topMsgId: _2!, readMaxId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateReadChannelInbox(Cons_updateReadChannelInbox(flags: _1!, folderId: _2, channelId: _3!, maxId: _4!, stillUnreadCount: _5!, pts: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateReadChannelOutbox(Cons_updateReadChannelOutbox(channelId: _1!, maxId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadFeaturedEmojiStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateReadFeaturedEmojiStickers
        }
        public static func parse_updateReadFeaturedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateReadFeaturedStickers
        }
        public static func parse_updateReadHistoryInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateReadHistoryInbox(Cons_updateReadHistoryInbox(flags: _1!, folderId: _2, peer: _3!, topMsgId: _4, maxId: _5!, stillUnreadCount: _6!, pts: _7!, ptsCount: _8!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadHistoryOutbox(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateReadHistoryOutbox(Cons_updateReadHistoryOutbox(peer: _1!, maxId: _2!, pts: _3!, ptsCount: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadMessagesContents(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateReadMessagesContents(Cons_updateReadMessagesContents(flags: _1!, messages: _2!, pts: _3!, ptsCount: _4!, date: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadMonoForumInbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateReadMonoForumInbox(Cons_updateReadMonoForumInbox(channelId: _1!, savedPeerId: _2!, readMaxId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadMonoForumOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateReadMonoForumOutbox(Cons_updateReadMonoForumOutbox(channelId: _1!, savedPeerId: _2!, readMaxId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadStories(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateReadStories(Cons_updateReadStories(peer: _1!, maxId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateRecentEmojiStatuses(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentEmojiStatuses
        }
        public static func parse_updateRecentReactions(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentReactions
        }
        public static func parse_updateRecentStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentStickers
        }
        public static func parse_updateSavedDialogPinned(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateSavedDialogPinned(Cons_updateSavedDialogPinned(flags: _1!, peer: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateSavedGifs(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedGifs
        }
        public static func parse_updateSavedReactionTags(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedReactionTags
        }
        public static func parse_updateSavedRingtones(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedRingtones
        }
        public static func parse_updateSentPhoneCode(_ reader: BufferReader) -> Update? {
            var _1: Api.auth.SentCode?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.auth.SentCode
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateSentPhoneCode(Cons_updateSentPhoneCode(sentCode: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateSentStoryReaction(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateSentStoryReaction(Cons_updateSentStoryReaction(peer: _1!, storyId: _2!, reaction: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateServiceNotification(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _6: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateServiceNotification(Cons_updateServiceNotification(flags: _1!, inboxDate: _2, type: _3!, message: _4!, media: _5!, entities: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateSmsJob(_ reader: BufferReader) -> Update? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateSmsJob(Cons_updateSmsJob(jobId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStarGiftAuctionState(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.StarGiftAuctionState?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionState
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStarGiftAuctionState(Cons_updateStarGiftAuctionState(giftId: _1!, state: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStarGiftAuctionUserState(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.StarGiftAuctionUserState?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionUserState
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStarGiftAuctionUserState(Cons_updateStarGiftAuctionUserState(giftId: _1!, userState: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStarGiftCraftFail(_ reader: BufferReader) -> Update? {
            return Api.Update.updateStarGiftCraftFail
        }
        public static func parse_updateStarsBalance(_ reader: BufferReader) -> Update? {
            var _1: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateStarsBalance(Cons_updateStarsBalance(balance: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStarsRevenueStatus(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StarsRevenueStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarsRevenueStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStarsRevenueStatus(Cons_updateStarsRevenueStatus(peer: _1!, status: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStickerSets(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateStickerSets(Cons_updateStickerSets(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStickerSetsOrder(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStickerSetsOrder(Cons_updateStickerSetsOrder(flags: _1!, order: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStoriesStealthMode(_ reader: BufferReader) -> Update? {
            var _1: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateStoriesStealthMode(Cons_updateStoriesStealthMode(stealthMode: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStory(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StoryItem?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStory(Cons_updateStory(peer: _1!, story: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateStoryID(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStoryID(Cons_updateStoryID(id: _1!, randomId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateTheme(_ reader: BufferReader) -> Update? {
            var _1: Api.Theme?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Theme
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateTheme(Cons_updateTheme(theme: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateTranscribedAudio(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateTranscribedAudio(Cons_updateTranscribedAudio(flags: _1!, peer: _2!, msgId: _3!, transcriptionId: _4!, text: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateUser(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateUser(Cons_updateUser(userId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserEmojiStatus(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.EmojiStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserEmojiStatus(Cons_updateUserEmojiStatus(userId: _1!, emojiStatus: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserName(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Username]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateUserName(Cons_updateUserName(userId: _1!, firstName: _2!, lastName: _3!, usernames: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserPhone(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserPhone(Cons_updateUserPhone(userId: _1!, phone: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserStatus(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.UserStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.UserStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserStatus(Cons_updateUserStatus(userId: _1!, status: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateUserTyping(Cons_updateUserTyping(flags: _1!, userId: _2!, topMsgId: _3, action: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateWebPage(_ reader: BufferReader) -> Update? {
            var _1: Api.WebPage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateWebPage(Cons_updateWebPage(webpage: _1!, pts: _2!, ptsCount: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateWebViewResultSent(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateWebViewResultSent(Cons_updateWebViewResultSent(queryId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
