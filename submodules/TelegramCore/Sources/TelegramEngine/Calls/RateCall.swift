import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

func _internal_rateCall(account: Account, callId: CallId, starsCount: Int32, comment: String = "", userInitiated: Bool) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    if userInitiated {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.phone.setCallRating(flags: flags, peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), rating: starsCount, comment: comment))
    |> retryRequest
    |> map { _ in }
}

public enum SaveCallDebugLogResult {
    case done
    case sendFullLog
}

func _internal_saveCallDebugLog(network: Network, callId: CallId, log: String) -> Signal<SaveCallDebugLogResult, NoError> {
    if log.count > 1024 * 16 {
        return .complete()
    }
    return network.request(Api.functions.phone.saveCallDebug(peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), debug: .dataJSON(data: log)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolTrue)
    }
    |> map { result -> SaveCallDebugLogResult in
        switch result {
        case .boolFalse:
            return .sendFullLog
        case .boolTrue:
            return .done
        }
    }
}

func _internal_saveCompleteCallDebugLog(account: Account, callId: CallId, logPath: String) -> Signal<Never, NoError> {
    let tempFile = TempBox.shared.tempFile(fileName: "log.txt.gz")
    
    do {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: logPath), options: .mappedIfSafe) else {
            Logger.shared.log("saveCompleteCallDebugLog", "Failed to open log file")
            
            return .complete()
        }
        
        guard let gzippedData = MTGzip.compress(data) else {
            Logger.shared.log("saveCompleteCallDebugLog", "Failed to compress log file")
            
            return .complete()
        }
        
        guard let _ = try? gzippedData.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) else {
            Logger.shared.log("saveCompleteCallDebugLog", "Failed to write compressed log file")
            
            return .complete()
        }
    }
    
    guard let size = fileSize(tempFile.path) else {
        Logger.shared.log("saveCompleteCallDebugLog", "Could not get log file size")
        
        return .complete()
    }
    
    return multipartUpload(network: account.network, postbox: account.postbox, source: .tempFile(tempFile), encrypt: false, tag: nil, hintFileSize: size, hintFileIsLarge: false, forceNoBigParts: true, useLargerParts: false)
    |> mapToSignal { value -> Signal<Never, MultipartUploadError> in
        switch value {
        case .progress:
            return .complete()
        case let .inputFile(inputFile):
            return account.network.request(Api.functions.phone.saveCallLog(peer: Api.InputPhoneCall.inputPhoneCall(id: callId.id, accessHash: callId.accessHash), file: inputFile))
            |> mapError { _ -> MultipartUploadError in
                return .generic
            }
            |> ignoreValues
        case .inputSecretFile:
            return .fail(.generic)
        }
    }
    |> `catch` { _ -> Signal<Never, NoError> in
        return .complete()
    }
}
