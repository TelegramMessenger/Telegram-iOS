//
//  InputChecklist.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a checklist to be sent
public struct InputChecklist: Codable, Equatable, Hashable {

    /// True, if other users can add tasks to the list
    public let othersCanAddTasks: Bool

    /// True, if other users can mark tasks as done or not done
    public let othersCanMarkTasksAsDone: Bool

    /// List of tasks in the checklist; 1-getOption("checklist_task_count_max") tasks
    public let tasks: [InputChecklistTask]

    /// Title of the checklist; 1-getOption("checklist_title_length_max") characters. May contain only Bold, Italic, Underline, Strikethrough, Spoiler, CustomEmoji, and DateTime entities
    public let title: FormattedText


    public init(
        othersCanAddTasks: Bool,
        othersCanMarkTasksAsDone: Bool,
        tasks: [InputChecklistTask],
        title: FormattedText
    ) {
        self.othersCanAddTasks = othersCanAddTasks
        self.othersCanMarkTasksAsDone = othersCanMarkTasksAsDone
        self.tasks = tasks
        self.title = title
    }
}

