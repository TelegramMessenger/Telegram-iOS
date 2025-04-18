import Foundation
import AVFoundation
import SwiftSignalKit

final class TonePlayerData {
    fileprivate let file: AVAudioFile
    
    fileprivate init(file: AVAudioFile) {
        self.file = file
    }
}

func loadTonePlayerData(path: String) -> TonePlayerData? {
    guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else {
        return nil
    }
    return TonePlayerData(file: file)
}

private final class TonePlayerContext {
    private let queue: Queue
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    
    private var scheduledData: (TonePlayerData, () -> Void)?
    
    private let initialVolume: Float
    
    init(queue: Queue) {
        self.initialVolume = AVAudioSession.sharedInstance().outputVolume
        self.queue = queue
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        self.audioEngine.attach(self.playerNode)
        self.audioEngine.connect(self.playerNode, to: self.audioEngine.mainMixerNode, format: nil)
        let gainFactor = self.initialVolume
        print("gain \(gainFactor)")
        self.audioEngine.mainMixerNode.outputVolume = gainFactor
        self.audioEngine.prepare()
    }
    
    func play(data: TonePlayerData, completed: @escaping () -> Void) {
        self.scheduledData = (data, completed)
    }
    
    func start() {
        do {
            //let gainFactor = max(0.1, min(1.5, self.initialVolume / currentVolume))
            
            try self.audioEngine.start()
            
            if let (data, completion) = self.scheduledData {
                self.playerNode.scheduleFile(data.file, at: nil, completionHandler: {})
                self.playerNode.play()
                completion()
            }
        } catch let e {
            print("Couldn't start tone engine: \(e)")
        }
    }
    
    func stop() {
        self.audioEngine.stop()
    }
}

final class TonePlayer {
    private let queue: Queue
    private let impl: QueueLocalObject<TonePlayerContext>
    
    init() {
        let queue = Queue()
        self.queue = queue
        self.impl = .init(queue: queue, generate: {
            return TonePlayerContext(queue: queue)
        })
    }
    
    func play(data: TonePlayerData, completed: @escaping () -> Void) {
        self.impl.with { impl in
            impl.play(data: data, completed: completed)
        }
    }
    
    func start() {
        self.impl.with({ impl in
            impl.start()
        })
    }
    
    func stop() {
        self.impl.with({ impl in
            impl.stop()
        })
    }
}
