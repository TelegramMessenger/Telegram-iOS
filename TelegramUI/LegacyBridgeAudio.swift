import Foundation
import SwiftSignalKit

import TelegramUIPrivateModule

public func legacyDecodeOpusAudio(path: String, outputPath: String) -> Signal<String, NoError> {
    return Signal { subscriber in
        let decoder = TGBridgeAudioDecoder(url: URL(fileURLWithPath: path), outputUrl: URL(fileURLWithPath: outputPath))
        decoder?.start(completion: {
            subscriber.putNext(outputPath)
            subscriber.putCompletion()
        })
        return EmptyDisposable
    }
}

public func legacyEncodeOpusAudio(path: String) -> Signal<(Data?, Int32), NoError> {
    return Signal { subscriber in
        let encoder = TGBridgeAudioEncoder(url: URL(fileURLWithPath: path))
        encoder?.start(completion: { (dataItem, duration) in
            subscriber.putNext((dataItem?.data(), duration))
            subscriber.putCompletion()
        })
        return EmptyDisposable
    }
}
