import Foundation
import SwiftSignalKit
import AudioToolbox

private func loadSystemSoundFromBundle(name: String) -> SystemSoundID? {
    let path = "\(frameworkBundle.resourcePath!)/\(name)"
    let url = URL(fileURLWithPath: path)
    var sound: SystemSoundID = 0
    if AudioServicesCreateSystemSoundID(url as CFURL, &sound) == noErr {
        return sound
    }
    return nil
}

final class ServiceSoundManager {
    private let queue = Queue()
    private var messageDeliverySound: SystemSoundID?
    
    init() {
        self.queue.async {
            self.messageDeliverySound = loadSystemSoundFromBundle(name: "MessageSent.caf")
        }
    }
    
    func playMessageDeliveredSound() {
        self.queue.async {
            if let messageDeliverySound = self.messageDeliverySound {
                AudioServicesPlaySystemSound(messageDeliverySound)
            }
        }
    }
}

let serviceSoundManager = ServiceSoundManager()
