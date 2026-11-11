import Foundation

public enum ChatMediaEditorToolsSurface: Equatable {
    case item(isVideo: Bool)
    case wallpaper
}

public func chatMediaEditorHasCurvesHistogram(_ surface: ChatMediaEditorToolsSurface) -> Bool {
    switch surface {
    case let .item(isVideo):
        return !isVideo
    case .wallpaper:
        return true
    }
}
