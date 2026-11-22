import Foundation

public func mediaPickerSubjectIsFile(isFilesMode: Bool, pollAsFile: Bool, richTextAsFile: Bool, filePickerOn: Bool) -> Bool {
    return isFilesMode || pollAsFile || (richTextAsFile && filePickerOn)
}

public func mediaPickerAsksHeicConversion(asFile: Bool, hasHeic: Bool, isFilesMode: Bool) -> Bool {
    return asFile && hasHeic && !isFilesMode
}

public func chatMediaFilePickerSelectionLimit(isSlowMode: Bool, isEditingMessage: Bool) -> Int {
    if isEditingMessage {
        return 1
    }
    return isSlowMode ? 10 : 100
}

public func chatMediaFilePickerSendOptions(isScheduledMessages: Bool, isSecretChat: Bool, isEditingMessage: Bool) -> (hasSchedule: Bool, hasSilentPosting: Bool) {
    return (hasSchedule: !isScheduledMessages && !isSecretChat && !isEditingMessage, hasSilentPosting: !isEditingMessage)
}
