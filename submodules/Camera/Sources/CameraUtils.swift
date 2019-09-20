import AVFoundation

extension AVFrameRateRange {
    func clamp(rate: Float64) -> Float64 {
        return max(self.minFrameRate, min(self.maxFrameRate, rate))
    }
    
    func contains(rate: Float64) -> Bool {
        return (self.minFrameRate...self.maxFrameRate) ~= rate
    }
}

extension AVCaptureDevice {
    func actualFPS(_ fps: Double) -> (fps: Double, duration: CMTime)? {
        var durations: [CMTime] = []
        var frameRates: [Double] = []
        
        for range in self.activeFormat.videoSupportedFrameRateRanges {
            if range.minFrameRate == range.maxFrameRate {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            
            if range.contains(rate: fps) {
                return (fps, CMTimeMake(value: 100, timescale: Int32(100 * fps)))
            }
            
            let actualFPS: Double = range.clamp(rate: fps)
            return (actualFPS, CMTimeMake(value: 100, timescale: Int32(100 * actualFPS)))
        }
        
        let diff = frameRates.map { abs($0 - fps) }
        
        if let minElement: Float64 = diff.min() {
            for i in 0..<diff.count where diff[i] == minElement {
                return (frameRates[i], durations[i])
            }
        }
        
        return nil
    }
}
