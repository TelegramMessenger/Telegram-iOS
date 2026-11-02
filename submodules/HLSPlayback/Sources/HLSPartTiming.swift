import Foundation

// The time range a buffered part covers, from what the FFmpeg probe reports for each of its tracks.
//
// The audio's start is kept, as the JavaScript player's SourceBuffer did: audio frames run on from part to part, so
// consecutive parts meet without overlapping. The end is the later of the two tracks' ends: a stream's audio can stop
// before its video (measured: 0.33 s of audio in a 5 s segment, and none in the last one), and a part cut at the audio's
// end leaves the rest of the segment as a hole that nothing fills and the player waits at. A track with no media in it
// does not count.
public enum HLSPartTiming {
    public static func range(audio: (start: Double, duration: Double)?, video: (start: Double, duration: Double)?) -> (start: Double, end: Double)? {
        let audio = audio.flatMap { $0.duration > 0.0 ? $0 : nil }
        let video = video.flatMap { $0.duration > 0.0 ? $0 : nil }
        guard let start = audio?.start ?? video?.start else {
            return nil
        }
        let end = max(audio.map { $0.start + $0.duration } ?? -Double.infinity, video.map { $0.start + $0.duration } ?? -Double.infinity)
        return (start, end)
    }
}
