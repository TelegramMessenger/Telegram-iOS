import Foundation
import SwiftSignalKit
import WatchBridgeAudioImpl

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

public func legacyEncodeOpusAudio(path: String) -> Signal<(String?, Int32), NoError> {
    return Signal { subscriber in
        let encoder = TGBridgeAudioEncoder(url: URL(fileURLWithPath: path))
        encoder?.start(completion: { (path, duration) in
            subscriber.putNext((path, duration))
            subscriber.putCompletion()
        })
        return EmptyDisposable
    }
}
