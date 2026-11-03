//
//  InputChecklistTask.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a task in a checklist to be sent
public struct InputChecklistTask: Codable, Equatable, Hashable, Identifiable {

    /// Unique identifier of the task; must be positive
    public let id: Int

    /// Text of the task; 1-getOption("checklist_task_text_length_max") characters without line feeds. May contain only Bold, Italic, Underline, Strikethrough, Spoiler, CustomEmoji, and DateTime entities
    public let text: FormattedText


    public init(
        id: Int,
        text: FormattedText
    ) {
        self.id = id
        self.text = text
    }
}

