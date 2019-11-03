import Foundation
import Postbox
import TelegramApi

import SyncCore

extension TelegramMediaPollOption {
    init(apiOption: Api.PollAnswer) {
        switch apiOption {
            case let .pollAnswer(text, option):
                self.init(text: text, opaqueIdentifier: option.makeData())
        }
    }
    
    var apiOption: Api.PollAnswer {
        return .pollAnswer(text: self.text, option: Buffer(data: self.opaqueIdentifier))
    }
}

extension TelegramMediaPollOptionVoters {
    init(apiVoters: Api.PollAnswerVoters) {
        switch apiVoters {
            case let .pollAnswerVoters(flags, option, voters):
                self.init(selected: (flags & (1 << 0)) != 0, opaqueIdentifier: option.makeData(), count: voters)
        }
    }
}

extension TelegramMediaPollResults {
    init(apiResults: Api.PollResults) {
        switch apiResults {
            case let .pollResults(_, results, totalVoters):
                self.init(voters: results.flatMap({ $0.map(TelegramMediaPollOptionVoters.init(apiVoters:)) }), totalVoters: totalVoters)
        }
    }
}
