import Foundation
import AVFoundation

private func loadToneData(name: String, addSilenceDuration: Double = 0.0) -> Data? {
    let outputSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM as NSNumber,
        AVSampleRateKey: 44100.0 as NSNumber,
        AVLinearPCMBitDepthKey: 16 as NSNumber,
        AVLinearPCMIsNonInterleaved: false as NSNumber,
        AVLinearPCMIsFloatKey: false as NSNumber,
        AVLinearPCMIsBigEndianKey: false as NSNumber,
        AVNumberOfChannelsKey: 2 as NSNumber
    ]
    
    let nsName: NSString = name as NSString
    let baseName: String
    let nameExtension: String
    let pathExtension = nsName.pathExtension
    if pathExtension.isEmpty {
        baseName = name
        nameExtension = "caf"
    } else {
        baseName = nsName.substring(with: NSRange(location: 0, length: (name.count - pathExtension.count - 1)))
        nameExtension = pathExtension
    }
    
    guard let url = Bundle.main.url(forResource: baseName, withExtension: nameExtension) else {
        return nil
    }
    
    let asset = AVURLAsset(url: url)
    
    guard let assetReader = try? AVAssetReader(asset: asset) else {
        return nil
    }
    
    let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: asset.tracks, audioSettings: outputSettings)
    
    if !assetReader.canAdd(readerOutput) {
        return nil
    }
    
    assetReader.add(readerOutput)
    
    if !assetReader.startReading() {
        return nil
    }
    
    var data = Data()
    
    while assetReader.status == .reading {
        if let nextBuffer = readerOutput.copyNextSampleBuffer() {
            var abl = AudioBufferList()
            var blockBuffer: CMBlockBuffer? = nil
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, bufferListSizeNeededOut: nil, bufferListOut: &abl, bufferListSize: MemoryLayout<AudioBufferList>.size, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, blockBufferOut: &blockBuffer)
            let size = Int(CMSampleBufferGetTotalSampleSize(nextBuffer))
            if size != 0, let mData = abl.mBuffers.mData {
                data.append(Data(bytes: mData, count: size))
            }
        } else {
            break
        }
    }
    
    if !addSilenceDuration.isZero {
        let sampleRate = 44100
        let numberOfSamples = Int(Double(sampleRate) * addSilenceDuration)
        let numberOfChannels = 2
        let numberOfBytes = numberOfSamples * 2 * numberOfChannels
        
        data.append(Data(count: numberOfBytes))
    }
    
    return data
}

enum PresentationCallTone: Equatable {
    case ringing
    case connecting
    case busy
    case failed
    case ended
    case groupJoined
    case groupLeft
    case groupConnecting
    case custom(name: String, loopCount: Int?)
    
    var loopCount: Int? {
        switch self {
            case .busy:
                return 3
            case .failed:
                return 1
            case .ended:
                return 1
            case .groupJoined, .groupLeft:
                return 1
            case .groupConnecting:
                return nil
            case let .custom(_, loopCount):
                return loopCount
            default:
                return nil
        }
    }
}

func presentationCallToneData(_ tone: PresentationCallTone) -> Data? {
    switch tone {
        case .ringing:
            return loadToneData(name: "voip_ringback.mp3")
        case .connecting:
            return loadToneData(name: "voip_connecting.mp3")
        case .busy:
            return loadToneData(name: "voip_busy.mp3")
        case .failed:
            return loadToneData(name: "voip_fail.mp3")
        case .ended:
            return loadToneData(name: "voip_end.mp3")
        case .groupJoined:
            return loadToneData(name: "voip_group_joined.mp3")
        case .groupLeft:
            return loadToneData(name: "voip_group_left.mp3")
        case .groupConnecting:
            return loadToneData(name: "voip_group_connecting.mp3", addSilenceDuration: 2.0)
        case let .custom(name, _):
            return loadToneData(name: name)
    }
}
