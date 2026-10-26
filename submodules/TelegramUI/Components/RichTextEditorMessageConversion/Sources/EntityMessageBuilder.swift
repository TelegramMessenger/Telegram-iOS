import Foundation
import TelegramCore
import TextFormat
import RichTextEditorCore

/// Build a normal message (text + entities) from entity-expressible blocks (body/quote paragraphs).
func buildEntityMessage(from blocks: [Block]) -> (text: String, entities: [MessageTextEntity]) {
    let result = NSMutableAttributedString()
    let marker = true as NSNumber
    var isFirstParagraph = true

    for block in blocks {
        if case let .code(code) = block {
            if !isFirstParagraph {
                result.append(NSAttributedString(string: "\n"))
            }
            isFirstParagraph = false
            let start = result.length
            result.append(NSAttributedString(string: code.text))   // code runs are always plain text
            let len = result.length - start
            if len > 0 {
                let attr = chatInputCodeBlockAttribute(language: code.language)
                result.addAttribute(attr.key, value: attr.value, range: NSRange(location: start, length: len))
            }
            continue
        }
        // A `.buttonRow` (and any other non-paragraph, non-code block) is skipped here. A button always
        // forces the rich path in `documentNeedsRichLayout`, so this is unreachable for one.
        guard case let .paragraph(paragraph) = block else {
            continue
        }
        if !isFirstParagraph {
            result.append(NSAttributedString(string: "\n"))
        }
        isFirstParagraph = false

        for run in paragraph.runs {
            if let emoji = run.attributes.emoji {
                // Mirror ComposerDocumentBridge: re-emit a customEmoji run; generateChatInputTextEntities
                // converts it to a .CustomEmoji(fileId:) entity. Prefer altText; fall back to U+FFFC. A
                // non-numeric id degrades to plain text rather than crashing.
                let displayText = (emoji.altText?.isEmpty == false) ? emoji.altText! : "\u{FFFC}"
                let piece = NSMutableAttributedString(string: displayText)
                let range = NSRange(location: 0, length: piece.length)
                if let fileId = Int64(emoji.id) {
                    piece.addAttribute(
                        ChatTextInputAttributes.customEmoji,
                        value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil),
                        range: range
                    )
                }
                result.append(piece)
                continue
            }
            let text = run.text
            if text.isEmpty {
                continue
            }
            let piece = NSMutableAttributedString(string: text)
            let range = NSRange(location: 0, length: piece.length)
            let attributes = run.attributes
            if attributes.bold {
                piece.addAttribute(ChatTextInputAttributes.bold, value: marker, range: range)
            }
            if attributes.italic {
                piece.addAttribute(ChatTextInputAttributes.italic, value: marker, range: range)
            }
            if attributes.inlineCode {
                piece.addAttribute(ChatTextInputAttributes.monospace, value: marker, range: range)
            }
            if attributes.strikethrough {
                piece.addAttribute(ChatTextInputAttributes.strikethrough, value: marker, range: range)
            }
            if attributes.underline {
                piece.addAttribute(ChatTextInputAttributes.underline, value: marker, range: range)
            }
            if attributes.spoiler {
                piece.addAttribute(ChatTextInputAttributes.spoiler, value: marker, range: range)
            }
            if let link = attributes.link {
                let attribute = chatInputLinkAttribute(forLink: link)
                piece.addAttribute(attribute.key, value: attribute.value, range: range)
            }
            result.append(piece)
        }

    }

    let entities = generateChatInputTextEntities(result)
    return (result.string, entities)
}
