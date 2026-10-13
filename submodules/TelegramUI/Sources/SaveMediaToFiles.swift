import Foundation
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import OverlayStatusController
import LegacyMediaPickerUI
import SaveToCameraRoll
import PresentationDataUtils

private func sanitizedFileNameComponent(_ value: String) -> String? {
    let result = (value as NSString).lastPathComponent.replacingOccurrences(of: "/", with: "_")
    if result.isEmpty || result == "." || result == ".." {
        return nil
    }
    return result
}

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
    
    var signal = fetchMediaData(context: context, userLocation: .other, mediaReference: fileReference.abstract)
    
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
            if data.isComplete {
                var symlinkPath = data.path + ".mp3"
                try? FileManager.default.removeItem(atPath: symlinkPath)
                let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                
                let audioUrl = URL(fileURLWithPath: symlinkPath)
                let audioAsset = AVURLAsset(url: audioUrl)
                
                var fileExtension = "mp3"
                if let filename = fileReference.media.fileName {
                    if let value = sanitizedFileNameComponent((filename as NSString).pathExtension) {
                        fileExtension = value
                    }
                }
                
                var nameComponents: [String] = []
                if let title {
                    if let performer, let value = sanitizedFileNameComponent(performer) {
                        nameComponents.append(value)
                    }
                    if let value = sanitizedFileNameComponent(title) {
                        nameComponents.append(value)
                    }
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
                    if let artist, !artist.isEmpty, let value = sanitizedFileNameComponent(artist) {
                        nameComponents.append(value)
                    }
                    if let title, !title.isEmpty, let value = sanitizedFileNameComponent(title) {
                        nameComponents.append(value)
                    }
                    if nameComponents.isEmpty, let filename = fileReference.media.fileName, let value = sanitizedFileNameComponent((filename as NSString).deletingPathExtension) {
                        nameComponents.append(value)
                    }
                }
                if !nameComponents.isEmpty {
                    let fileName = "\(nameComponents.joined(separator: " – ")).\(fileExtension)"
                    let directoryUrl = audioUrl.deletingLastPathComponent().standardizedFileURL
                    let targetUrl = directoryUrl.appendingPathComponent(fileName, isDirectory: false).standardizedFileURL
                    let directoryPath = directoryUrl.path.hasSuffix("/") ? directoryUrl.path : directoryUrl.path + "/"
                    if targetUrl.path.hasPrefix(directoryPath) {
                        do {
                            try FileManager.default.linkItem(atPath: data.path, toPath: targetUrl.path)
                            try? FileManager.default.removeItem(atPath: symlinkPath)
                            symlinkPath = targetUrl.path
                        } catch {
                        }
                    }
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
