//
//  MediaData.swift
//  LyraProfile
//
//  Created by Alvin Marana on 4/29/23.
//

import UIKit

public struct MediaData {
    
    public var data: Data = Data()
    public var fileName: String = ""
    public var mimeType: MediaDataMimeType = .image
    public var uploadStorage: String = ""
    public var key: String = ""

    public init() { }

}

public enum MediaDataMimeType: String {
    case image = "image/jpg"
    case videoMP4 = "video/mp4"
    case videoMov = "video/quicktime"
}
