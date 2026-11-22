import Foundation

public enum ChatMediaGalleryRoute: Equatable {
    case legacy
    case chat
    case filePreview
}

public func chatMediaGalleryRoute(galleryOn: Bool, filePickerOn: Bool, asFile: Bool, hasPreparedCompletion: Bool, hasCustomSelection: Bool, explicitMultipleSelection: Bool) -> ChatMediaGalleryRoute {
    if asFile {
        return filePickerOn ? .filePreview : .legacy
    }
    if galleryOn && hasPreparedCompletion && !hasCustomSelection && !explicitMultipleSelection {
        return .chat
    }
    return .legacy
}

public func chatMediaGalleryUsesSelection(selectionLimit: Int) -> Bool {
    return selectionLimit != 1
}

public func chatMediaGalleryZeroBasedSelectionIndex(legacyIndex: Int) -> Int? {
    guard legacyIndex != NSNotFound, legacyIndex >= 1 else {
        return nil
    }
    return legacyIndex - 1
}
