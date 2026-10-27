import Foundation

public enum ChatMediaV2Entry: CaseIterable {
    case attachMenuCamera
    case inlineCameraCell
    case placeholderCamera
    case storyReplyCamera
    case shortcutCamera
    case pickerGallery
    case messageMediaEditor
    case animatedFileEditor
    case wallpaperEditor
    case wallpaperPhotoPicker
    case qrPhotoPicker
    case filePicker
    case suggestedAvatar
    case videoChatAvatar
    case passport
    case signupAvatar
}

public func chatMediaV2Routing(flagOn: Bool, entry: ChatMediaV2Entry) -> Bool {
    guard flagOn else {
        return false
    }
    switch entry {
    case .attachMenuCamera, .inlineCameraCell, .placeholderCamera, .storyReplyCamera, .shortcutCamera:
        return true
    case .pickerGallery:
        return true
    case .messageMediaEditor:
        return true
    case .animatedFileEditor:
        return true
    case .wallpaperEditor:
        return true
    case .wallpaperPhotoPicker:
        return true
    case .qrPhotoPicker:
        return true
    case .filePicker:
        return true
    case .suggestedAvatar:
        return true
    case .videoChatAvatar:
        return true
    case .passport:
        return true
    case .signupAvatar:
        return false
    }
}

public extension AccountContext {
    func routesToChatMediaEditorV2(_ entry: ChatMediaV2Entry) -> Bool {
        return chatMediaV2Routing(flagOn: self.usesChatMediaEditorV2, entry: entry)
    }
}
