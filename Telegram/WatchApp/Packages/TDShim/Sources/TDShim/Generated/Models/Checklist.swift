//
//  Checklist.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a checklist
public struct Checklist: Codable, Equatable, Hashable {

    /// True, if the current user can add tasks to the list if they have Telegram Premium subscription
    public let canAddTasks: Bool

    /// True, if the current user can mark tasks as done or not done if they have Telegram Premium subscription
    public let canMarkTasksAsDone: Bool

    /// True, if users other than creator of the list can add tasks to the list
    public let othersCanAddTasks: Bool

    /// True, if users other than creator of the list can mark tasks as done or not done. If true, then the checklist is called "group checklist"
    public let othersCanMarkTasksAsDone: Bool

    /// List of tasks in the checklist
    public let tasks: [ChecklistTask]

    /// Title of the checklist; may contain only Bold, Italic, Underline, Strikethrough, Spoiler, CustomEmoji, and DateTime entities
    public let title: FormattedText


    public init(
        canAddTasks: Bool,
        canMarkTasksAsDone: Bool,
        othersCanAddTasks: Bool,
        othersCanMarkTasksAsDone: Bool,
        tasks: [ChecklistTask],
        title: FormattedText
    ) {
        self.canAddTasks = canAddTasks
        self.canMarkTasksAsDone = canMarkTasksAsDone
        self.othersCanAddTasks = othersCanAddTasks
        self.othersCanMarkTasksAsDone = othersCanMarkTasksAsDone
        self.tasks = tasks
        self.title = title
    }
}

