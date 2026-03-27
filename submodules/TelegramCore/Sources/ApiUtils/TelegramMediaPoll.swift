import Foundation
import Postbox
import TelegramApi


extension TelegramMediaPollOption {
    init(apiOption: Api.PollAnswer) {
        switch apiOption {
        case let .pollAnswer(pollAnswerData):
            let (flags, text, option, date, addedBy) = (pollAnswerData.flags, pollAnswerData.text, pollAnswerData.option, pollAnswerData.date, pollAnswerData.addedBy)
            let answerText: String
            let answerEntities: [MessageTextEntity]
            switch text {
            case let .textWithEntities(textWithEntitiesData):
                let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                answerText = text
                answerEntities = messageTextEntitiesFromApiEntities(entities)
            }
            var parsedMedia: Media?
            if (flags & (1 << 0)) != 0, let apiMedia = pollAnswerData.media {
                parsedMedia = textMediaAndExpirationTimerFromApiMedia(apiMedia, PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0))).media
            }
            self.init(text: answerText, entities: answerEntities, opaqueIdentifier: option.makeData(), media: parsedMedia, date: date, addedBy: addedBy?.peerId)
        case let .inputPollAnswer(inputPollAnswerData):
            let text = inputPollAnswerData.text
            let answerText: String
            
            let answerEntities: [MessageTextEntity]
            switch text {
            case let .textWithEntities(textWithEntitiesData):
                let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                answerText = text
                answerEntities = messageTextEntitiesFromApiEntities(entities)
            }
            self.init(text: answerText, entities: answerEntities, opaqueIdentifier: Data(), date: nil, addedBy: nil)
        }
    }

    var apiOption: Api.PollAnswer {
        return .pollAnswer(.init(flags: 0, text: .textWithEntities(.init(text: self.text, entities: apiEntitiesFromMessageTextEntities(self.entities, associatedPeers: SimpleDictionary()))), option: Buffer(data: self.opaqueIdentifier), media: nil, addedBy: nil, date: nil))
    }
}

extension TelegramMediaPollOptionVoters {
    init(apiVoters: Api.PollAnswerVoters) {
        switch apiVoters {
            case let .pollAnswerVoters(pollAnswerVotersData):
                let (flags, option, voters) = (pollAnswerVotersData.flags, pollAnswerVotersData.option, pollAnswerVotersData.voters)
                let parsedRecentVoters: [PeerId] = pollAnswerVotersData.recentVoters.flatMap { peers in
                    return peers.map { $0.peerId }
                } ?? []
                self.init(selected: (flags & (1 << 0)) != 0, opaqueIdentifier: option.makeData(), count: voters, isCorrect: (flags & (1 << 1)) != 0, recentVoters: parsedRecentVoters)
        }
    }
}

extension TelegramMediaPollResults {
    init(apiResults: Api.PollResults) {
        switch apiResults {
            case let .pollResults(pollResultsData):
                let (flags, results, totalVoters, recentVoters, solution, solutionEntities) = (pollResultsData.flags, pollResultsData.results, pollResultsData.totalVoters, pollResultsData.recentVoters, pollResultsData.solution, pollResultsData.solutionEntities)
                var parsedSolution: TelegramMediaPollResults.Solution?
                if let solution = solution, let solutionEntities = solutionEntities, !solution.isEmpty {
                    var solutionMedia: Media?
                    if let apiSolutionMedia = pollResultsData.solutionMedia {
                        solutionMedia = textMediaAndExpirationTimerFromApiMedia(apiSolutionMedia, PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0))).media
                    }
                    parsedSolution = TelegramMediaPollResults.Solution(text: solution, entities: messageTextEntitiesFromApiEntities(solutionEntities), media: solutionMedia)
                }
                var hasUnseenVotes: Bool?
                if (flags & (1 << 0)) == 0 {//isMin
                    hasUnseenVotes = (flags & (1 << 6)) != 0
                }

                self.init(voters: results.flatMap({ $0.map(TelegramMediaPollOptionVoters.init(apiVoters:)) }), totalVoters: totalVoters, recentVoters: recentVoters.flatMap { recentVoters in
                    return recentVoters.map { $0.peerId }
                    } ?? [], solution: parsedSolution, hasUnseenVotes: hasUnseenVotes)
        }
    }
}
