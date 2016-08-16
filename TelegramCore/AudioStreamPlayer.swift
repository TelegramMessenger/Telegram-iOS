import Foundation
import Postbox
import SwiftSignalKit

final class AudioStreamPlayer {
    let source: AudioPlayerSource
    let renderer: AudioPlayerRenderer
    
    init(account: Account, resource: MediaResource) {
        var requestSamples: (Int) -> Signal<Data, NoError> = { _ in
            return .complete()
        }
        
        self.renderer = AudioPlayerRenderer(audioStreamDescription: audioPlayerCanonicalStreamDescription(), requestSamples: { count in
            return requestSamples(count)
        })
        
        self.source = AudioPlayerSource(account: account, resource: resource)
        
        requestSamples = { [weak self] count in
            if let strongSelf = self {
                return strongSelf.source.requestSampleBytes(count: count)
            } else {
                return .never()
            }
        }
        
        self.renderer.render()
    }
    
    deinit {
        self.renderer.stop()
    }
}
