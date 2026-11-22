import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import FFMpegBinding
import LocalMediaResources

public func fetchLocalFileAudioMediaResource(resource: LocalFileAudioMediaResource) -> Signal<EngineMediaResourceDataFetchResult, EngineMediaResourceDataFetchError> {
    let tempFile = EngineTempBox.shared.tempFile(fileName: "audio.ogg")
    FFMpegOpusTrimmer.trim(resource.path, to: tempFile.path, start: resource.trimRange?.lowerBound ?? 0.0, end: resource.trimRange?.upperBound ?? 1.0)

    return .single(.moveTempFile(file: tempFile))
}
