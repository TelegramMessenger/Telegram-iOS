//
//  ChecklistTask.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a task in a checklist
public struct ChecklistTask: Codable, Equatable, Hashable, Identifiable {

    /// Identifier of the user or chat that completed the task; may be null if the task isn't completed yet
    public let completedBy: MessageSender?

    /// Point in time (Unix timestamp) when the task was completed; 0 if the task isn't completed
    public let completionDate: Int

    /// Unique identifier of the task
    public let id: Int

    /// Text of the task; may contain only Bold, Italic, Underline, Strikethrough, Spoiler, CustomEmoji, DateTime and automatically found entities
    public let text: FormattedText


    public init(
        completedBy: MessageSender?,
        completionDate: Int,
        id: Int,
        text: FormattedText
    ) {
        self.completedBy = completedBy
        self.completionDate = completionDate
        self.id = id
        self.text = text
    }
}

