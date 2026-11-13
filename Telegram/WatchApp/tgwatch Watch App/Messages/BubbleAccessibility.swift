import Foundation
import SwiftUI

/// What VoiceOver says for one chat bubble. `MessageBubbleView` makes the whole
/// bubble a single element with these strings, so a message is announced as
/// one item ("Voice message, from: Alice, Duration: 3 seconds") instead of a
/// list of glyph names and bare numbers.
///
/// Wording follows the iOS app's chat VoiceOver strings (`VoiceOver.Chat.*`):
/// the message kind first, with the sender in groups or "Your …" for outgoing
/// messages, then the content.
struct BubbleAccessibility: Equatable {
    var label: String
    /// Changing state: playback, sending, read and listened state.
    var value: String
    var hint: String
    /// Double tap does something (opens, plays, votes).
    var isButton: Bool
}

/// Playback state of a voice or music bubble, read from its controller.
enum BubblePlaybackState: Equatable {
    case idle
    case playing
    case loading
    case failed
}

extension BubblePlaybackState {
    init(_ glyph: VoiceGlyph) {
        switch glyph {
        case .play: self = .idle
        case .pause: self = .playing
        case .spinner: self = .loading
        case .error: self = .failed
        }
    }

    init(_ glyph: AudioGlyph) {
        switch glyph {
        case .play: self = .idle
        case .pause: self = .playing
        case .spinner: self = .loading
        case .error: self = .failed
        }
    }
}

/// - Parameters:
///   - isGroupChat: picks "recipients" over "recipient" for an outgoing voice message's played state.
///   - playback: state of this bubble's voice / music playback; ignored for other kinds.
func bubbleAccessibility(
    _ bubble: MessageBubble,
    isGroupChat: Bool,
    playback: BubblePlaybackState = .idle
) -> BubbleAccessibility {
    var parts: [String] = []
    var values: [String] = []
    var hint = ""
    var isButton = false

    /// "Photo, from: Alice" / "Photo" / "Your photo".
    func kind(_ base: String, from: String, your: String) -> String {
        if bubble.isOutgoing { return L(your) }
        if let name = bubble.senderName, !name.isEmpty { return L(from, name) }
        return L(base)
    }
    func caption(_ text: String) {
        if !text.isEmpty { parts.append(L("VoiceOver.Chat.Caption", text)) }
    }
    func duration(_ seconds: Int) {
        parts.append(L("VoiceOver.Chat.Duration", spokenDuration(seconds)))
    }
    func playable(_ state: BubblePlaybackState) {
        isButton = true
        switch state {
        case .idle:
            hint = L("VoiceOver.Chat.PlayHint")
        case .playing:
            values.append(L("Watch.VoiceOver.Playing"))
            hint = L("Watch.VoiceOver.PauseHint")
        case .loading:
            values.append(L("Watch.Common.Loading"))
        case .failed:
            values.append(L("Watch.VoiceOver.PlaybackFailed"))
            hint = L("VoiceOver.Chat.PlayHint")
        }
    }

    if let sticker = bubble.sticker {
        parts.append(sticker.format == .tgs
            ? kind("VoiceOver.Chat.AnimatedSticker", from: "VoiceOver.Chat.AnimatedStickerFrom", your: "VoiceOver.Chat.YourAnimatedSticker")
            : kind("VoiceOver.Chat.Sticker", from: "VoiceOver.Chat.StickerFrom", your: "VoiceOver.Chat.YourSticker"))
        if !sticker.emoji.isEmpty { parts.append(sticker.emoji) }
    } else if let photo = bubble.photo {
        parts.append(kind("VoiceOver.Chat.Photo", from: "VoiceOver.Chat.PhotoFrom", your: "VoiceOver.Chat.YourPhoto"))
        caption(bubble.body)
        if photo.localPath != nil {
            isButton = true
            hint = L("VoiceOver.Chat.OpenHint")
        } else {
            values.append(L("Watch.Common.Loading"))
        }
    } else if let video = bubble.video {
        parts.append(kind("VoiceOver.Chat.Video", from: "VoiceOver.Chat.VideoFrom", your: "VoiceOver.Chat.YourVideo"))
        duration(video.duration)
        caption(bubble.body)
        isButton = true
        hint = L("VoiceOver.Chat.PlayHint")
    } else if let note = bubble.videoNote {
        parts.append(kind("VoiceOver.Chat.VideoMessage", from: "VoiceOver.Chat.VideoMessageFrom", your: "VoiceOver.Chat.YourVideoMessage"))
        duration(note.duration)
        isButton = true
        hint = L("VoiceOver.Chat.PlayHint")
    } else if let voice = bubble.voiceNote {
        parts.append(kind("VoiceOver.Chat.VoiceMessage", from: "VoiceOver.Chat.VoiceMessageFrom", your: "VoiceOver.Chat.YourVoiceMessage"))
        duration(voice.duration)
        caption(bubble.body)
        playable(playback)
        // The dot under the duration: not played yet by this account (incoming) or by the
        // recipient (outgoing). Outgoing ones that were played say so, as on iOS.
        if bubble.isOutgoing {
            if voice.isListened {
                values.append(L(isGroupChat ? "VoiceOver.Chat.PlayedByRecipients" : "VoiceOver.Chat.PlayedByRecipient"))
            } else {
                values.append(L(isGroupChat ? "VoiceOver.Chat.NotPlayedByRecipients" : "VoiceOver.Chat.NotPlayedByRecipient"))
            }
        } else if !voice.isListened {
            values.append(L("Watch.VoiceOver.NotPlayed"))
        }
    } else if let audio = bubble.audio {
        parts.append(kind("VoiceOver.Chat.Music", from: "VoiceOver.Chat.MusicFrom", your: "VoiceOver.Chat.YourMusic"))
        parts.append(audio.performer.isEmpty ? audio.title : L("VoiceOver.Chat.MusicTitle", audio.title, audio.performer))
        duration(audio.duration)
        caption(bubble.body)
        playable(playback)
    } else if let document = bubble.document {
        parts.append(kind("VoiceOver.Chat.File", from: "VoiceOver.Chat.FileFrom", your: "VoiceOver.Chat.YourFile"))
        parts.append(document.fileName)
        parts.append(L("VoiceOver.Chat.Size", formatFileSize(document.sizeBytes)))
        caption(document.caption)
    } else if let location = bubble.location {
        parts.append(kind("Watch.VoiceOver.Location", from: "Watch.VoiceOver.LocationFrom", your: "Watch.VoiceOver.YourLocation"))
        if location.isLive { parts.append(L("Message.LiveLocation")) }
        if let title = location.title, !title.isEmpty { parts.append(title) }
        if let address = location.address, !address.isEmpty { parts.append(address) }
        isButton = true
        hint = L("VoiceOver.Chat.OpenHint")
    } else if let poll = bubble.poll {
        parts.append(pollKind(poll, kind: kind))
        parts.append(poll.question)
        let options = poll.options.map { option in
            var text = option.text
            if poll.resultsVisible { text += ", \(option.votePercentage)%" }
            if option.isChosen { text += ", " + L("VoiceOver.Chat.OptionSelected") }
            if option.isCorrect == true { text += ", " + L("Watch.VoiceOver.CorrectAnswer") }
            return text
        }
        // "2 options: Pizza, 67%, Sushi, 33%" — the count ends with a colon.
        parts.append(LPlural("VoiceOver.Chat.PollOptionCount", poll.options.count) + " " + options.joined(separator: ", "))
        if let explanation = poll.explanation { parts.append(explanation) }
        parts.append(poll.totalVoterCount == 0
            ? L("VoiceOver.Chat.PollNoVotes")
            : LPlural("VoiceOver.Chat.PollVotes", poll.totalVoterCount))
        if poll.isClosed { values.append(L("VoiceOver.Chat.PollFinalResults")) }
        if poll.canVote {
            isButton = true
            hint = L("Watch.VoiceOver.VoteHint")
        }
    } else if bubble.isUnsupported {
        parts.append(kind("VoiceOver.Chat.Message", from: "Watch.VoiceOver.MessageFrom", your: "VoiceOver.Chat.YourMessage"))
        parts.append(L("Watch.Message.Unsupported"))
    } else {
        parts.append(kind("VoiceOver.Chat.Message", from: "Watch.VoiceOver.MessageFrom", your: "VoiceOver.Chat.YourMessage"))
        parts.append(bubble.body)
    }

    if let reply = bubble.replyHeader {
        if let name = reply.senderName, !name.isEmpty {
            parts.append(L("VoiceOver.Chat.ReplyFrom", name))
        } else {
            parts.append(L("VoiceOver.Chat.Reply"))
        }
    }

    switch bubble.outgoingStatus {
    case .none: break
    case .pending: values.insert(L("VoiceOver.Chat.Sending"), at: 0)
    case .failed: values.insert(L("VoiceOver.Chat.Failed"), at: 0)
    case .unread: values.append(L("Watch.VoiceOver.NotRead"))
    }

    return BubbleAccessibility(
        label: parts.filter { !$0.isEmpty }.joined(separator: ", "),
        value: values.joined(separator: ", "),
        hint: hint,
        isButton: isButton
    )
}

private func pollKind(_ poll: PollVisual, kind: (String, String, String) -> String) -> String {
    if poll.isQuiz {
        return kind("Watch.VoiceOver.Quiz", "Watch.VoiceOver.QuizFrom", "Watch.VoiceOver.YourQuiz")
    }
    if poll.isAnonymous {
        return kind("VoiceOver.Chat.AnonymousPoll", "VoiceOver.Chat.AnonymousPollFrom", "VoiceOver.Chat.YourAnonymousPoll")
    }
    return kind("Watch.VoiceOver.Poll", "Watch.VoiceOver.PollFrom", "Watch.VoiceOver.YourPoll")
}

extension PollVisual {
    /// The bubble offers a Vote button: still open, and not yet answered (or answers can change).
    var canVote: Bool {
        guard !isClosed else { return false }
        if isQuiz { return !hasVoted }
        return !hasVoted || allowsRevoting
    }
}

/// A duration as VoiceOver should say it ("3 seconds", "1 minute, 5 seconds"),
/// in the language pack's language; `formatDuration`'s "0:03" reads as a time.
func spokenDuration(_ seconds: Int) -> String {
    let formatter = DateComponentsFormatter()
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = AppStrings.shared.locale
    formatter.calendar = calendar
    formatter.unitsStyle = .full
    formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : seconds >= 60 ? [.minute, .second] : [.second]
    formatter.zeroFormattingBehavior = seconds > 0 ? .dropAll : .default
    return formatter.string(from: TimeInterval(max(0, seconds))) ?? formatDuration(seconds)
}
