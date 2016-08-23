import Foundation
import SwiftSignalKit
import Postbox
import AVFoundation
import MobileCoreServices
import TelegramCore

final class MediaManager {
    let queue = Queue()
}

//private var globalPlayer: AudioStreamPlayer?

func debugPlayMedia(account: Account, file: TelegramMediaFile) {
    /*globalPlayer = nil
    let player = AudioStreamPlayer(account: account, resource: CloudFileMediaResource(location: file.location, size: file.size))
    globalPlayer = player*/
    
    /*let player = STKAudioPlayer()
    player.play("http://www.stephaniequinn.com/Music/Canon.mp3")
    testPlayer = player*/
}
