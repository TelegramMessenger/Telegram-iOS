import Foundation
import Postbox
import TelegramApi


extension TelegramMediaPollOption {
    init(apiOption: Api.PollAnswer) {
        switch apiOption {
        case let .pollAnswer(text, option):
            let answerText: String
            let answerEntities: [MessageTextEntity]
            switch text {
            case let .textWithEntities(text, entities):
                answerText = text
                answerEntities = messageTextEntitiesFromApiEntities(entities)
            }
            
            self.init(text: answerText, entities: answerEntities, opaqueIdentifier: option.makeData())
        }
    }
    
    var apiOption: Api.PollAnswer {
        return .pollAnswer(text: .textWithEntities(text: self.text, entities: apiEntitiesFromMessageTextEntities(self.entities, associatedPeers: SimpleDictionary())), option: Buffer(data: self.opaqueIdentifier))
    }
}

extension TelegramMediaPollOptionVoters {
    init(apiVoters: Api.PollAnswerVoters) {
        switch apiVoters {
            case let .pollAnswerVoters(flags, option, voters):
                self.init(selected: (flags & (1 << 0)) != 0, opaqueIdentifier: option.makeData(), count: voters, isCorrect: (flags & (1 << 1)) != 0)
        }
    }
}

extension TelegramMediaPollResults {
    init(apiResults: Api.PollResults) {
        switch apiResults {
            case let .pollResults(_, results, totalVoters, recentVoters, solution, solutionEntities):
                var parsedSolution: TelegramMediaPollResults.Solution?
                if let solution = solution, let solutionEntities = solutionEntities, !solution.isEmpty {
                    parsedSolution = TelegramMediaPollResults.Solution(text: solution, entities: messageTextEntitiesFromApiEntities(solutionEntities))
                }
                
                self.init(voters: results.flatMap({ $0.map(TelegramMediaPollOptionVoters.init(apiVoters:)) }), totalVoters: totalVoters, recentVoters: recentVoters.flatMap { recentVoters in
                    return recentVoters.map { $0.peerId }
                    } ?? [], solution: parsedSolution)
        }
    }
}
