import Foundation
import AVFoundation

private func loadAudioRecordingToneData() -> Data? {
    let outputSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM as NSNumber,
        AVSampleRateKey: 44100.0 as NSNumber,
        AVLinearPCMBitDepthKey: 16 as NSNumber,
        AVLinearPCMIsNonInterleaved: false as NSNumber,
        AVLinearPCMIsFloatKey: false as NSNumber,
        AVLinearPCMIsBigEndianKey: false as NSNumber
    ]
    
    guard let url = Bundle.main.url(forResource: "begin_record", withExtension: "mp3") else {
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
    
    return data
}

let audioRecordingToneData: Data? = loadAudioRecordingToneData()
