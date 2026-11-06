import Foundation

/// Fictional, neutral copy for recording the feature in the native client.
/// Kept in a separate persistent Postbox session from the regression fixtures.
enum AllMentionDemoShowcase {
    static let names: [(String, String)] = [
        ("Alex", "Johnson"), ("Emma", "Wilson"), ("Daniel", "Brown"),
        ("Sophie", "Miller"), ("James", "Taylor"), ("Olivia", "Martin"),
        ("Liam", "Anderson"), ("Chloe", "Davis")
    ]

    static let conversation: [(Int, String)] = [
        (1, "Weekend plans are finally happening!"),
        (2, "Train tickets booked. We're all set."),
        (3, "I'll bring snacks for the journey."),
        (0, "Perfect. Let's meet by the main entrance."),
        (4, "Just packed. Trying to travel light this time."),
        (1, "Does anyone need a spare charger?"),
        (0, "I've got one, thanks!"),
        (3, "Ready when you are. Let us know when to head out.")
    ]

    static let forumTopics: [(id: Int64, title: String, color: Int32, messages: [(Int, String)])] = [
        (1, "General", 0x6fb9f0, [
            (1, "One chat for everything we need for the trip."),
            (2, "Great! Tickets and meeting times can go in Plans."),
            (3, "Can't wait for the weekend!")
        ]),
        (100, "Plans", 0xffd67e, conversation),
        (200, "Ideas", 0x8eee98, [
            (5, "Found a little bakery we could try."),
            (6, "Sounds like a good first stop."),
            (5, "I'll save it for when we get there."),
            (2, "And let's leave some time to just wander around.")
        ])
    ]
}
