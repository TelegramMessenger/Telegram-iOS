import UIKit

func extractSoundCloudTrackIdAndTimestamp(url: String) -> (String, Int)? {
    guard let url = URL(string: url), let host = url.host?.lowercased() else {
        return nil
    }
    
    let domain = "w.soundcloud.com"
    let match = host == domain || host.contains(".\(domain)")
        
    guard match else {
        return nil
    }
    
    var videoId: String?
    var timestamp: Int?
    
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        if let queryItems = components.queryItems {
            for queryItem in queryItems {
                if let value = queryItem.value {
                    if queryItem.name == "v" {
                        videoId = value
                    } else if queryItem.name == "t" || queryItem.name == "time_continue" {
                        if value.contains("s") {
                            
                        } else {
                            timestamp = Int(value)
                        }
                    }
                }
            }
        }
        
        if videoId == nil {
            let pathComponents = components.path.components(separatedBy: "/")
            var nextComponentIsVideoId = host.contains("youtu.be")
            
            for component in pathComponents {
                if nextComponentIsVideoId {
                    videoId = component
                    break
                } else if component == "embed" {
                    nextComponentIsVideoId = true
                }
            }
        }
    }
    
    if let videoId = videoId {
        return (videoId, timestamp ?? 0)
    }
    
    return nil
}

final class SoundCloudEmbedImplementation: WebEmbedImplementation {

}
