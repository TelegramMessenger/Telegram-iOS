import Foundation
import AVFoundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import OverlayStatusController
import LegacyMediaPickerUI
import SaveToCameraRoll
import PresentationDataUtils

func saveMediaToFiles(context: AccountContext, fileReference: FileMediaReference, present: @escaping (ViewController, Any?) -> Void) -> Disposable {
    var title: String?
    var performer: String?
    for attribute in fileReference.media.attributes {
        if case let .Audio(_, _, titleValue, performerValue, _) = attribute {
            if let titleValue, !titleValue.isEmpty {
                title = titleValue
            }
            if let performerValue, !performerValue.isEmpty {
                performer = performerValue
            }
        }
    }
    
    var signal = fetchMediaData(context: context, postbox: context.account.postbox, userLocation: .other, mediaReference: fileReference.abstract)
    
    var cancelImpl: (() -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let progressSignal = Signal<Never, NoError> { subscriber in
        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
            cancelImpl?()
        }))
        present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        return ActionDisposable { [weak controller] in
            Queue.mainQueue().async() {
                controller?.dismiss()
            }
        }
    }
    |> runOn(Queue.mainQueue())
    |> delay(0.15, queue: Queue.mainQueue())
    
    let progressDisposable = progressSignal.startStrict()
    
    let disposable = MetaDisposable()
    signal = signal
    |> afterDisposed {
        Queue.mainQueue().async {
            progressDisposable.dispose()
        }
    }
    cancelImpl = { [weak disposable] in
        disposable?.set(nil)
    }
    disposable.set((signal
    |> deliverOnMainQueue).startStrict(next: { state, _ in
        switch state {
        case .progress:
            break
        case let .data(data):
            if data.complete {
                var symlinkPath = data.path + ".mp3"
                if fileSize(symlinkPath) != nil {
                    try? FileManager.default.removeItem(atPath: symlinkPath)
                }
                let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                
                let audioUrl = URL(fileURLWithPath: symlinkPath)
                let audioAsset = AVURLAsset(url: audioUrl)
                
                var fileExtension = "mp3"
                if let filename = fileReference.media.fileName {
                    if let dotIndex = filename.lastIndex(of: ".") {
                        fileExtension = String(filename[filename.index(after: dotIndex)...])
                    }
                }
                
                var nameComponents: [String] = []
                if let title {
                    if let performer {
                        nameComponents.append(performer)
                    }
                    nameComponents.append(title)
                } else {
                    var artist: String?
                    var title: String?
                    for data in audioAsset.commonMetadata {
                        if data.commonKey == .commonKeyArtist {
                            artist = data.stringValue
                        }
                        if data.commonKey == .commonKeyTitle {
                            title = data.stringValue
                        }
                    }
                    if let artist, !artist.isEmpty {
                        nameComponents.append(artist)
                    }
                    if let title, !title.isEmpty {
                        nameComponents.append(title)
                    }
                    if nameComponents.isEmpty, var filename = fileReference.media.fileName {
                        if let dotIndex = filename.lastIndex(of: ".") {
                            filename = String(filename[..<dotIndex])
                        }
                        nameComponents.append(filename)
                    }
                }
                if !nameComponents.isEmpty {
                    try? FileManager.default.removeItem(atPath: symlinkPath)
                    
                    let fileName = "\(nameComponents.joined(separator: " – ")).\(fileExtension)"
                    symlinkPath = symlinkPath.replacingOccurrences(of: audioUrl.lastPathComponent, with: fileName)
                    let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                }
                
                let url = URL(fileURLWithPath: symlinkPath)
                let controller = legacyICloudFilePicker(theme: presentationData.theme, mode: .export, url: url, documentTypes: [], forceDarkTheme: false, dismissed: {}, completion: { _ in
                    
                })
                present(controller, nil)
            }
        }
    }))
    
    return disposable
}
