import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

func multipartDownloadFromCloudLocation(account: Account, location: TelegramCloudMediaLocation, size: Int?, data: Data? = nil, offset: Int = 0) -> Signal<Data, NoError> {
    return account.network.download(datacenterId: location.datacenterId)
        |> mapToSignal { download -> Signal<Data, NoError> in
            if let size = size {
                let partLength = 32 * 1024
                var currentOffset = offset
                var signal: Signal<Data, NoError>!
                while currentOffset < size {
                    let part = download.part(location: location.apiInputLocation, offset: currentOffset, length: partLength)
                    if signal != nil {
                        signal = signal |> then(part)
                    } else {
                        signal = part
                    }
                    currentOffset += partLength
                }
                
                return signal |> reduceLeft(value: data ?? Data(), f: { current, next, emit -> Data in
                    var updatedData = current
                    updatedData.append(next)
                    emit(updatedData)
                    return updatedData
                })
            } else {
                let part = download.request(Api.functions.upload.getFile(location: location.apiInputLocation, offset: Int32(0), limit: 1024 * 1024))
                    |> retryRequest
                let data = part |> map { result -> Data in
                    switch result {
                    case let .file(_, _, bytes):
                        return bytes.makeData()
                    }
                }
                return data
            }
    }
}
