import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum ReportContentResult {
    public struct Option: Equatable {
        public let text: String
        public let option: Data
    }
    
    case options(title: String, options: [Option])
    case addComment(optional: Bool, option: Data)
    case reported
}

public enum ReportContentError {
    case generic
    case messageIdRequired
}

public enum ReportContentSubject: Equatable {
    case peer(EnginePeer.Id)
    case messages([EngineMessage.Id])
    case stories(EnginePeer.Id, [Int32])
    
    public var peerId: EnginePeer.Id {
        switch self {
        case let .peer(peerId):
            return peerId
        case let .messages(messageIds):
            return messageIds.first!.peerId
        case let .stories(peerId, _):
            return peerId
        }
    }
}

func _internal_reportContent(account: Account, subject: ReportContentSubject, option: Data?, message: String?) -> Signal<ReportContentResult, ReportContentError> {
    return account.postbox.transaction { transaction -> Signal<ReportContentResult, ReportContentError> in
        guard let peer = transaction.getPeer(subject.peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        
        let request: Signal<Api.ReportResult, MTRpcError>
        if case let .stories(_, ids) = subject {
            request = account.network.request(Api.functions.stories.report(peer: inputPeer, id: ids, option: Buffer(data: option), message: message ?? ""))
        } else {
            var ids: [Int32] = []
            if case let .messages(messageIds) = subject {
                ids = messageIds.map { $0.id }
            }
            request = account.network.request(Api.functions.messages.report(peer: inputPeer, id: ids, option: Buffer(data: option), message: message ?? ""))
        }
        
        return request
        |> mapError { error -> ReportContentError in
            if error.errorDescription == "MESSAGE_ID_REQUIRED" {
                return .messageIdRequired
            }
            return .generic
        }
        |> map { result -> ReportContentResult in
            switch result {
            case let .reportResultChooseOption(title, options):
                return .options(title: title, options: options.map {
                    switch $0 {
                    case let .messageReportOption(text, option):
                        return ReportContentResult.Option(text: text, option: option.makeData())
                    }
                })
            case let .reportResultAddComment(flags, option):
                return .addComment(optional: (flags & (1 << 0)) != 0, option: option.makeData())
            case .reportResultReported:
                return .reported
            }
        }
    }
    |> castError(ReportContentError.self)
    |> switchToLatest
}
