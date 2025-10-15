public extension Api.smsjobs {
    enum EligibilityToJoin: TypeConstructorDescription {
        case eligibleToJoin(termsUrl: String, monthlySentSms: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .eligibleToJoin(let termsUrl, let monthlySentSms):
                    if boxed {
                        buffer.appendInt32(-594852657)
                    }
                    serializeString(termsUrl, buffer: buffer, boxed: false)
                    serializeInt32(monthlySentSms, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .eligibleToJoin(let termsUrl, let monthlySentSms):
                return ("eligibleToJoin", [("termsUrl", termsUrl as Any), ("monthlySentSms", monthlySentSms as Any)])
    }
    }
    
        public static func parse_eligibleToJoin(_ reader: BufferReader) -> EligibilityToJoin? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.smsjobs.EligibilityToJoin.eligibleToJoin(termsUrl: _1!, monthlySentSms: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.smsjobs {
    enum Status: TypeConstructorDescription {
        case status(flags: Int32, recentSent: Int32, recentSince: Int32, recentRemains: Int32, totalSent: Int32, totalSince: Int32, lastGiftSlug: String?, termsUrl: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .status(let flags, let recentSent, let recentSince, let recentRemains, let totalSent, let totalSince, let lastGiftSlug, let termsUrl):
                    if boxed {
                        buffer.appendInt32(720277905)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(recentSent, buffer: buffer, boxed: false)
                    serializeInt32(recentSince, buffer: buffer, boxed: false)
                    serializeInt32(recentRemains, buffer: buffer, boxed: false)
                    serializeInt32(totalSent, buffer: buffer, boxed: false)
                    serializeInt32(totalSince, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(lastGiftSlug!, buffer: buffer, boxed: false)}
                    serializeString(termsUrl, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .status(let flags, let recentSent, let recentSince, let recentRemains, let totalSent, let totalSince, let lastGiftSlug, let termsUrl):
                return ("status", [("flags", flags as Any), ("recentSent", recentSent as Any), ("recentSince", recentSince as Any), ("recentRemains", recentRemains as Any), ("totalSent", totalSent as Any), ("totalSince", totalSince as Any), ("lastGiftSlug", lastGiftSlug as Any), ("termsUrl", termsUrl as Any)])
    }
    }
    
        public static func parse_status(_ reader: BufferReader) -> Status? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            var _8: String?
            _8 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.smsjobs.Status.status(flags: _1!, recentSent: _2!, recentSince: _3!, recentRemains: _4!, totalSent: _5!, totalSince: _6!, lastGiftSlug: _7, termsUrl: _8!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum BroadcastStats: TypeConstructorDescription {
        case broadcastStats(period: Api.StatsDateRangeDays, followers: Api.StatsAbsValueAndPrev, viewsPerPost: Api.StatsAbsValueAndPrev, sharesPerPost: Api.StatsAbsValueAndPrev, reactionsPerPost: Api.StatsAbsValueAndPrev, viewsPerStory: Api.StatsAbsValueAndPrev, sharesPerStory: Api.StatsAbsValueAndPrev, reactionsPerStory: Api.StatsAbsValueAndPrev, enabledNotifications: Api.StatsPercentValue, growthGraph: Api.StatsGraph, followersGraph: Api.StatsGraph, muteGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, interactionsGraph: Api.StatsGraph, ivInteractionsGraph: Api.StatsGraph, viewsBySourceGraph: Api.StatsGraph, newFollowersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph, storyInteractionsGraph: Api.StatsGraph, storyReactionsByEmotionGraph: Api.StatsGraph, recentPostsInteractions: [Api.PostInteractionCounters])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let reactionsPerPost, let viewsPerStory, let sharesPerStory, let reactionsPerStory, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let reactionsByEmotionGraph, let storyInteractionsGraph, let storyReactionsByEmotionGraph, let recentPostsInteractions):
                    if boxed {
                        buffer.appendInt32(963421692)
                    }
                    period.serialize(buffer, true)
                    followers.serialize(buffer, true)
                    viewsPerPost.serialize(buffer, true)
                    sharesPerPost.serialize(buffer, true)
                    reactionsPerPost.serialize(buffer, true)
                    viewsPerStory.serialize(buffer, true)
                    sharesPerStory.serialize(buffer, true)
                    reactionsPerStory.serialize(buffer, true)
                    enabledNotifications.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    followersGraph.serialize(buffer, true)
                    muteGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    interactionsGraph.serialize(buffer, true)
                    ivInteractionsGraph.serialize(buffer, true)
                    viewsBySourceGraph.serialize(buffer, true)
                    newFollowersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    reactionsByEmotionGraph.serialize(buffer, true)
                    storyInteractionsGraph.serialize(buffer, true)
                    storyReactionsByEmotionGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentPostsInteractions.count))
                    for item in recentPostsInteractions {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let reactionsPerPost, let viewsPerStory, let sharesPerStory, let reactionsPerStory, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let reactionsByEmotionGraph, let storyInteractionsGraph, let storyReactionsByEmotionGraph, let recentPostsInteractions):
                return ("broadcastStats", [("period", period as Any), ("followers", followers as Any), ("viewsPerPost", viewsPerPost as Any), ("sharesPerPost", sharesPerPost as Any), ("reactionsPerPost", reactionsPerPost as Any), ("viewsPerStory", viewsPerStory as Any), ("sharesPerStory", sharesPerStory as Any), ("reactionsPerStory", reactionsPerStory as Any), ("enabledNotifications", enabledNotifications as Any), ("growthGraph", growthGraph as Any), ("followersGraph", followersGraph as Any), ("muteGraph", muteGraph as Any), ("topHoursGraph", topHoursGraph as Any), ("interactionsGraph", interactionsGraph as Any), ("ivInteractionsGraph", ivInteractionsGraph as Any), ("viewsBySourceGraph", viewsBySourceGraph as Any), ("newFollowersBySourceGraph", newFollowersBySourceGraph as Any), ("languagesGraph", languagesGraph as Any), ("reactionsByEmotionGraph", reactionsByEmotionGraph as Any), ("storyInteractionsGraph", storyInteractionsGraph as Any), ("storyReactionsByEmotionGraph", storyReactionsByEmotionGraph as Any), ("recentPostsInteractions", recentPostsInteractions as Any)])
    }
    }
    
        public static func parse_broadcastStats(_ reader: BufferReader) -> BroadcastStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _6: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _7: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _8: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _9: Api.StatsPercentValue?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _15: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _16: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _17: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _17 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _18: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _18 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _19: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _20: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _20 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _21: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _21 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _22: [Api.PostInteractionCounters]?
            if let _ = reader.readInt32() {
                _22 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PostInteractionCounters.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            let _c18 = _18 != nil
            let _c19 = _19 != nil
            let _c20 = _20 != nil
            let _c21 = _21 != nil
            let _c22 = _22 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
                return Api.stats.BroadcastStats.broadcastStats(period: _1!, followers: _2!, viewsPerPost: _3!, sharesPerPost: _4!, reactionsPerPost: _5!, viewsPerStory: _6!, sharesPerStory: _7!, reactionsPerStory: _8!, enabledNotifications: _9!, growthGraph: _10!, followersGraph: _11!, muteGraph: _12!, topHoursGraph: _13!, interactionsGraph: _14!, ivInteractionsGraph: _15!, viewsBySourceGraph: _16!, newFollowersBySourceGraph: _17!, languagesGraph: _18!, reactionsByEmotionGraph: _19!, storyInteractionsGraph: _20!, storyReactionsByEmotionGraph: _21!, recentPostsInteractions: _22!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum MegagroupStats: TypeConstructorDescription {
        case megagroupStats(period: Api.StatsDateRangeDays, members: Api.StatsAbsValueAndPrev, messages: Api.StatsAbsValueAndPrev, viewers: Api.StatsAbsValueAndPrev, posters: Api.StatsAbsValueAndPrev, growthGraph: Api.StatsGraph, membersGraph: Api.StatsGraph, newMembersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, messagesGraph: Api.StatsGraph, actionsGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, weekdaysGraph: Api.StatsGraph, topPosters: [Api.StatsGroupTopPoster], topAdmins: [Api.StatsGroupTopAdmin], topInviters: [Api.StatsGroupTopInviter], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                    if boxed {
                        buffer.appendInt32(-276825834)
                    }
                    period.serialize(buffer, true)
                    members.serialize(buffer, true)
                    messages.serialize(buffer, true)
                    viewers.serialize(buffer, true)
                    posters.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    membersGraph.serialize(buffer, true)
                    newMembersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    messagesGraph.serialize(buffer, true)
                    actionsGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    weekdaysGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topPosters.count))
                    for item in topPosters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topAdmins.count))
                    for item in topAdmins {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topInviters.count))
                    for item in topInviters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                return ("megagroupStats", [("period", period as Any), ("members", members as Any), ("messages", messages as Any), ("viewers", viewers as Any), ("posters", posters as Any), ("growthGraph", growthGraph as Any), ("membersGraph", membersGraph as Any), ("newMembersBySourceGraph", newMembersBySourceGraph as Any), ("languagesGraph", languagesGraph as Any), ("messagesGraph", messagesGraph as Any), ("actionsGraph", actionsGraph as Any), ("topHoursGraph", topHoursGraph as Any), ("weekdaysGraph", weekdaysGraph as Any), ("topPosters", topPosters as Any), ("topAdmins", topAdmins as Any), ("topInviters", topInviters as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_megagroupStats(_ reader: BufferReader) -> MegagroupStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _6: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _7: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _8: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _9: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: [Api.StatsGroupTopPoster]?
            if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopPoster.self)
            }
            var _15: [Api.StatsGroupTopAdmin]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopAdmin.self)
            }
            var _16: [Api.StatsGroupTopInviter]?
            if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopInviter.self)
            }
            var _17: [Api.User]?
            if let _ = reader.readInt32() {
                _17 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return Api.stats.MegagroupStats.megagroupStats(period: _1!, members: _2!, messages: _3!, viewers: _4!, posters: _5!, growthGraph: _6!, membersGraph: _7!, newMembersBySourceGraph: _8!, languagesGraph: _9!, messagesGraph: _10!, actionsGraph: _11!, topHoursGraph: _12!, weekdaysGraph: _13!, topPosters: _14!, topAdmins: _15!, topInviters: _16!, users: _17!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum MessageStats: TypeConstructorDescription {
        case messageStats(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageStats(let viewsGraph, let reactionsByEmotionGraph):
                    if boxed {
                        buffer.appendInt32(2145983508)
                    }
                    viewsGraph.serialize(buffer, true)
                    reactionsByEmotionGraph.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageStats(let viewsGraph, let reactionsByEmotionGraph):
                return ("messageStats", [("viewsGraph", viewsGraph as Any), ("reactionsByEmotionGraph", reactionsByEmotionGraph as Any)])
    }
    }
    
        public static func parse_messageStats(_ reader: BufferReader) -> MessageStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _2: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stats.MessageStats.messageStats(viewsGraph: _1!, reactionsByEmotionGraph: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum PublicForwards: TypeConstructorDescription {
        case publicForwards(flags: Int32, count: Int32, forwards: [Api.PublicForward], nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .publicForwards(let flags, let count, let forwards, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1828487648)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(forwards.count))
                    for item in forwards {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .publicForwards(let flags, let count, let forwards, let nextOffset, let chats, let users):
                return ("publicForwards", [("flags", flags as Any), ("count", count as Any), ("forwards", forwards as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_publicForwards(_ reader: BufferReader) -> PublicForwards? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.PublicForward]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PublicForward.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stats.PublicForwards.publicForwards(flags: _1!, count: _2!, forwards: _3!, nextOffset: _4, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum StoryStats: TypeConstructorDescription {
        case storyStats(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyStats(let viewsGraph, let reactionsByEmotionGraph):
                    if boxed {
                        buffer.appendInt32(1355613820)
                    }
                    viewsGraph.serialize(buffer, true)
                    reactionsByEmotionGraph.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyStats(let viewsGraph, let reactionsByEmotionGraph):
                return ("storyStats", [("viewsGraph", viewsGraph as Any), ("reactionsByEmotionGraph", reactionsByEmotionGraph as Any)])
    }
    }
    
        public static func parse_storyStats(_ reader: BufferReader) -> StoryStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _2: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stats.StoryStats.storyStats(viewsGraph: _1!, reactionsByEmotionGraph: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stickers {
    enum SuggestedShortName: TypeConstructorDescription {
        case suggestedShortName(shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .suggestedShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2046910401)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .suggestedShortName(let shortName):
                return ("suggestedShortName", [("shortName", shortName as Any)])
    }
    }
    
        public static func parse_suggestedShortName(_ reader: BufferReader) -> SuggestedShortName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.stickers.SuggestedShortName.suggestedShortName(shortName: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.storage {
    enum FileType: TypeConstructorDescription {
        case fileGif
        case fileJpeg
        case fileMov
        case fileMp3
        case fileMp4
        case filePartial
        case filePdf
        case filePng
        case fileUnknown
        case fileWebp
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileGif:
                    if boxed {
                        buffer.appendInt32(-891180321)
                    }
                    
                    break
                case .fileJpeg:
                    if boxed {
                        buffer.appendInt32(8322574)
                    }
                    
                    break
                case .fileMov:
                    if boxed {
                        buffer.appendInt32(1258941372)
                    }
                    
                    break
                case .fileMp3:
                    if boxed {
                        buffer.appendInt32(1384777335)
                    }
                    
                    break
                case .fileMp4:
                    if boxed {
                        buffer.appendInt32(-1278304028)
                    }
                    
                    break
                case .filePartial:
                    if boxed {
                        buffer.appendInt32(1086091090)
                    }
                    
                    break
                case .filePdf:
                    if boxed {
                        buffer.appendInt32(-1373745011)
                    }
                    
                    break
                case .filePng:
                    if boxed {
                        buffer.appendInt32(172975040)
                    }
                    
                    break
                case .fileUnknown:
                    if boxed {
                        buffer.appendInt32(-1432995067)
                    }
                    
                    break
                case .fileWebp:
                    if boxed {
                        buffer.appendInt32(276907596)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileGif:
                return ("fileGif", [])
                case .fileJpeg:
                return ("fileJpeg", [])
                case .fileMov:
                return ("fileMov", [])
                case .fileMp3:
                return ("fileMp3", [])
                case .fileMp4:
                return ("fileMp4", [])
                case .filePartial:
                return ("filePartial", [])
                case .filePdf:
                return ("filePdf", [])
                case .filePng:
                return ("filePng", [])
                case .fileUnknown:
                return ("fileUnknown", [])
                case .fileWebp:
                return ("fileWebp", [])
    }
    }
    
        public static func parse_fileGif(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileGif
        }
        public static func parse_fileJpeg(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileJpeg
        }
        public static func parse_fileMov(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMov
        }
        public static func parse_fileMp3(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp3
        }
        public static func parse_fileMp4(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp4
        }
        public static func parse_filePartial(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePartial
        }
        public static func parse_filePdf(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePdf
        }
        public static func parse_filePng(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePng
        }
        public static func parse_fileUnknown(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileUnknown
        }
        public static func parse_fileWebp(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileWebp
        }
    
    }
}
public extension Api.stories {
    enum Albums: TypeConstructorDescription {
        case albums(hash: Int64, albums: [Api.StoryAlbum])
        case albumsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .albums(let hash, let albums):
                    if boxed {
                        buffer.appendInt32(-1013417414)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(albums.count))
                    for item in albums {
                        item.serialize(buffer, true)
                    }
                    break
                case .albumsNotModified:
                    if boxed {
                        buffer.appendInt32(1448008427)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .albums(let hash, let albums):
                return ("albums", [("hash", hash as Any), ("albums", albums as Any)])
                case .albumsNotModified:
                return ("albumsNotModified", [])
    }
    }
    
        public static func parse_albums(_ reader: BufferReader) -> Albums? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StoryAlbum]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryAlbum.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stories.Albums.albums(hash: _1!, albums: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_albumsNotModified(_ reader: BufferReader) -> Albums? {
            return Api.stories.Albums.albumsNotModified
        }
    
    }
}
public extension Api.stories {
    enum AllStories: TypeConstructorDescription {
        case allStories(flags: Int32, count: Int32, state: String, peerStories: [Api.PeerStories], chats: [Api.Chat], users: [Api.User], stealthMode: Api.StoriesStealthMode)
        case allStoriesNotModified(flags: Int32, state: String, stealthMode: Api.StoriesStealthMode)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .allStories(let flags, let count, let state, let peerStories, let chats, let users, let stealthMode):
                    if boxed {
                        buffer.appendInt32(1862033025)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeString(state, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peerStories.count))
                    for item in peerStories {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    stealthMode.serialize(buffer, true)
                    break
                case .allStoriesNotModified(let flags, let state, let stealthMode):
                    if boxed {
                        buffer.appendInt32(291044926)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(state, buffer: buffer, boxed: false)
                    stealthMode.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .allStories(let flags, let count, let state, let peerStories, let chats, let users, let stealthMode):
                return ("allStories", [("flags", flags as Any), ("count", count as Any), ("state", state as Any), ("peerStories", peerStories as Any), ("chats", chats as Any), ("users", users as Any), ("stealthMode", stealthMode as Any)])
                case .allStoriesNotModified(let flags, let state, let stealthMode):
                return ("allStoriesNotModified", [("flags", flags as Any), ("state", state as Any), ("stealthMode", stealthMode as Any)])
    }
    }
    
        public static func parse_allStories(_ reader: BufferReader) -> AllStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.PeerStories]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerStories.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _7: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.stories.AllStories.allStories(flags: _1!, count: _2!, state: _3!, peerStories: _4!, chats: _5!, users: _6!, stealthMode: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_allStoriesNotModified(_ reader: BufferReader) -> AllStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.stories.AllStories.allStoriesNotModified(flags: _1!, state: _2!, stealthMode: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum CanSendStoryCount: TypeConstructorDescription {
        case canSendStoryCount(countRemains: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .canSendStoryCount(let countRemains):
                    if boxed {
                        buffer.appendInt32(-1014513586)
                    }
                    serializeInt32(countRemains, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .canSendStoryCount(let countRemains):
                return ("canSendStoryCount", [("countRemains", countRemains as Any)])
    }
    }
    
        public static func parse_canSendStoryCount(_ reader: BufferReader) -> CanSendStoryCount? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.stories.CanSendStoryCount.canSendStoryCount(countRemains: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum FoundStories: TypeConstructorDescription {
        case foundStories(flags: Int32, count: Int32, stories: [Api.FoundStory], nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .foundStories(let flags, let count, let stories, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-488736969)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stories.count))
                    for item in stories {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .foundStories(let flags, let count, let stories, let nextOffset, let chats, let users):
                return ("foundStories", [("flags", flags as Any), ("count", count as Any), ("stories", stories as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_foundStories(_ reader: BufferReader) -> FoundStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.FoundStory]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FoundStory.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.FoundStories.foundStories(flags: _1!, count: _2!, stories: _3!, nextOffset: _4, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum PeerStories: TypeConstructorDescription {
        case peerStories(stories: Api.PeerStories, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerStories(let stories, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-890861720)
                    }
                    stories.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerStories(let stories, let chats, let users):
                return ("peerStories", [("stories", stories as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_peerStories(_ reader: BufferReader) -> PeerStories? {
            var _1: Api.PeerStories?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerStories
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.stories.PeerStories.peerStories(stories: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum Stories: TypeConstructorDescription {
        case stories(flags: Int32, count: Int32, stories: [Api.StoryItem], pinnedToTop: [Int32]?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stories(let flags, let count, let stories, let pinnedToTop, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1673780490)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stories.count))
                    for item in stories {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(pinnedToTop!.count))
                    for item in pinnedToTop! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stories(let flags, let count, let stories, let pinnedToTop, let chats, let users):
                return ("stories", [("flags", flags as Any), ("count", count as Any), ("stories", stories as Any), ("pinnedToTop", pinnedToTop as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_stories(_ reader: BufferReader) -> Stories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StoryItem]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryItem.self)
            }
            var _4: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.Stories.stories(flags: _1!, count: _2!, stories: _3!, pinnedToTop: _4, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum StoryReactionsList: TypeConstructorDescription {
        case storyReactionsList(flags: Int32, count: Int32, reactions: [Api.StoryReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyReactionsList(let flags, let count, let reactions, let chats, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(-1436583780)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reactions.count))
                    for item in reactions {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyReactionsList(let flags, let count, let reactions, let chats, let users, let nextOffset):
                return ("storyReactionsList", [("flags", flags as Any), ("count", count as Any), ("reactions", reactions as Any), ("chats", chats as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_storyReactionsList(_ reader: BufferReader) -> StoryReactionsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StoryReaction]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryReaction.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.StoryReactionsList.storyReactionsList(flags: _1!, count: _2!, reactions: _3!, chats: _4!, users: _5!, nextOffset: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum StoryViews: TypeConstructorDescription {
        case storyViews(views: [Api.StoryViews], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyViews(let views, let users):
                    if boxed {
                        buffer.appendInt32(-560009955)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(views.count))
                    for item in views {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyViews(let views, let users):
                return ("storyViews", [("views", views as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_storyViews(_ reader: BufferReader) -> StoryViews? {
            var _1: [Api.StoryViews]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryViews.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stories.StoryViews.storyViews(views: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum StoryViewsList: TypeConstructorDescription {
        case storyViewsList(flags: Int32, count: Int32, viewsCount: Int32, forwardsCount: Int32, reactionsCount: Int32, views: [Api.StoryView], chats: [Api.Chat], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyViewsList(let flags, let count, let viewsCount, let forwardsCount, let reactionsCount, let views, let chats, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(1507299269)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeInt32(viewsCount, buffer: buffer, boxed: false)
                    serializeInt32(forwardsCount, buffer: buffer, boxed: false)
                    serializeInt32(reactionsCount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(views.count))
                    for item in views {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyViewsList(let flags, let count, let viewsCount, let forwardsCount, let reactionsCount, let views, let chats, let users, let nextOffset):
                return ("storyViewsList", [("flags", flags as Any), ("count", count as Any), ("viewsCount", viewsCount as Any), ("forwardsCount", forwardsCount as Any), ("reactionsCount", reactionsCount as Any), ("views", views as Any), ("chats", chats as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_storyViewsList(_ reader: BufferReader) -> StoryViewsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.StoryView]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryView.self)
            }
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _9: String?
            if Int(_1!) & Int(1 << 0) != 0 {_9 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 0) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.stories.StoryViewsList.storyViewsList(flags: _1!, count: _2!, viewsCount: _3!, forwardsCount: _4!, reactionsCount: _5!, views: _6!, chats: _7!, users: _8!, nextOffset: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.updates {
    indirect enum ChannelDifference: TypeConstructorDescription {
        case channelDifference(flags: Int32, pts: Int32, timeout: Int32?, newMessages: [Api.Message], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User])
        case channelDifferenceEmpty(flags: Int32, pts: Int32, timeout: Int32?)
        case channelDifferenceTooLong(flags: Int32, timeout: Int32?, dialog: Api.Dialog, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                    if boxed {
                        buffer.appendInt32(543450958)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                    if boxed {
                        buffer.appendInt32(1041346555)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    break
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1531132162)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    dialog.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                return ("channelDifference", [("flags", flags as Any), ("pts", pts as Any), ("timeout", timeout as Any), ("newMessages", newMessages as Any), ("otherUpdates", otherUpdates as Any), ("chats", chats as Any), ("users", users as Any)])
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                return ("channelDifferenceEmpty", [("flags", flags as Any), ("pts", pts as Any), ("timeout", timeout as Any)])
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                return ("channelDifferenceTooLong", [("flags", flags as Any), ("timeout", timeout as Any), ("dialog", dialog as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_channelDifference(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Update]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.updates.ChannelDifference.channelDifference(flags: _1!, pts: _2!, timeout: _3, newMessages: _4!, otherUpdates: _5!, chats: _6!, users: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceEmpty(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.updates.ChannelDifference.channelDifferenceEmpty(flags: _1!, pts: _2!, timeout: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceTooLong(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Api.Dialog?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Dialog
            }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.ChannelDifference.channelDifferenceTooLong(flags: _1!, timeout: _2, dialog: _3!, messages: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
