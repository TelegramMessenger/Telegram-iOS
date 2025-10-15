import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import FFMpegBinding
import LocalMediaResources

public func fetchLocalFileAudioMediaResource(postbox: Postbox, resource: LocalFileAudioMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    let tempFile = EngineTempBox.shared.tempFile(fileName: "audio.ogg")
    FFMpegOpusTrimmer.trim(resource.path, to: tempFile.path, start: resource.trimRange?.lowerBound ?? 0.0, end: resource.trimRange?.upperBound ?? 1.0)
    
    return .single(.moveTempFile(file: tempFile))
}
