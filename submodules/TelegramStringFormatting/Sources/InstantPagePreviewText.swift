import Foundation
import UIKit
import CoreText
import Postbox
import TelegramCore
import TelegramPresentationData
import AppBundle
import TextFormat
import TelegramUIPreferences

private enum InstantPagePreviewIcon: Int32 {
    case formula
    case table
}

private let iconAttribute = instantPagePreviewIcon

public func renderInstantPagePreviewIcons(_ text: NSAttributedString, font: UIFont, textColor: UIColor) -> NSAttributedString {
    return renderInstantPagePreviewIcons(text, font: font, textColor: textColor, image: { UIImage(bundleImageName: $0) })
}

func renderInstantPagePreviewIcons(_ text: NSAttributedString, font: UIFont, textColor: UIColor, image: (String) -> UIImage?) -> NSAttributedString {
    let result = NSMutableAttributedString(attributedString: text)
    var missing: [(NSRange, NSAttributedString)] = []
    var replacements: [(range: NSRange, image: UIImage, font: UIFont, textColor: UIColor)] = []
    result.enumerateAttribute(iconAttribute, in: NSRange(location: 0, length: result.length)) { value, range, _ in
        guard let rawValue = (value as? NSNumber)?.int32Value, let icon = InstantPagePreviewIcon(rawValue: rawValue) else {
            return
        }

        let imageName: String
        switch icon {
        case .formula:
            imageName = "Chat List/FormulaIcon"
        case .table:
            imageName = "Chat List/TableIcon"
        }
        if let image = image(imageName)?.withRenderingMode(.alwaysTemplate) {
            for offset in range.location ..< NSMaxRange(range) {
                let rangeFont = result.attribute(.font, at: offset, effectiveRange: nil) as? UIFont ?? font
                let rangeTextColor = result.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? UIColor ?? textColor
                replacements.append((NSRange(location: offset, length: 1), image, rangeFont, rangeTextColor))
            }
        } else {
            for offset in range.location ..< NSMaxRange(range) {
                var attributes = result.attributes(at: offset, effectiveRange: nil)
                let fallback = attributes[instantPagePreviewIconFallback] as? String ?? "�"
                attributes.removeValue(forKey: iconAttribute)
                attributes.removeValue(forKey: instantPagePreviewIconFallback)
                missing.append((NSRange(location: offset, length: 1), NSAttributedString(string: fallback, attributes: attributes)))
            }
        }
    }

    final class RunDelegateData {
        let ascent: CGFloat
        let descent: CGFloat
        let width: CGFloat

        init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
            self.ascent = ascent
            self.descent = descent
            self.width = width
        }
    }

    for replacement in replacements.reversed() {
        let runDelegateData = RunDelegateData(
            ascent: replacement.font.ascender,
            descent: abs(replacement.font.descender),
            width: replacement.image.size.width
        )
        var callbacks = CTRunDelegateCallbacks(
            version: kCTRunDelegateCurrentVersion,
            dealloc: { dataRef in
                Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
            },
            getAscent: { dataRef in
                return Unmanaged<RunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().ascent
            },
            getDescent: { dataRef in
                return Unmanaged<RunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().descent
            },
            getWidth: { dataRef in
                return Unmanaged<RunDelegateData>.fromOpaque(dataRef).takeUnretainedValue().width
            }
        )

        var attributes = result.attributes(at: replacement.range.location, effectiveRange: nil)
        attributes.removeValue(forKey: iconAttribute)
        attributes[.font] = replacement.font
        attributes[.foregroundColor] = replacement.textColor
        attributes[.attachment] = replacement.image
        if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
            attributes[NSAttributedString.Key(kCTRunDelegateAttributeName as String)] = runDelegate
        }
        result.replaceCharacters(in: replacement.range, with: NSAttributedString(string: "\u{fffc}", attributes: attributes))
    }

    // Successful substitutions are length preserving; expand missing icons last.
    for (range, replacement) in missing.reversed() {
        result.replaceCharacters(in: range, with: replacement)
    }
    return missing.isEmpty ? result : clipInstantPagePreview(result)
}

private func previewEnvironment(strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat? = nil, media: [MediaId: Media]) -> InstantPagePreviewEnvironment {
    let formatDate: ((Int32, MessageTextEntityType.DateTimeFormat) -> String)? = dateTimeFormat.map { dateTimeFormat in
        return { timestamp, format in
            stringForEntityFormattedDate(timestamp: timestamp, format: format, strings: strings, dateTimeFormat: dateTimeFormat)
        }
    }
    return InstantPagePreviewEnvironment(label: { label in
        switch label {
        case .photo: return strings.Message_Photo
        case .video: return strings.Message_Video
        case .voice: return strings.Message_Audio
        case .music: return strings.RichTextPreview_Music
        case .file: return strings.Message_File
        case .location: return strings.Message_Location
        case .formula: return strings.RichTextPreview_Formula
        case .table: return strings.RichTextPreview_Table
        case .unsupported: return strings.Conversation_UnsupportedMedia_Title
        case .embeddedContent: return strings.RichTextPreview_EmbeddedContent
        case .channel: return strings.RichTextPreview_Channel
        case let .photos(count): return strings.ChatList_MessagePhotos(count)
        case let .videos(count): return strings.ChatList_MessageVideos(count)
        }
    }, formatDate: formatDate, media: media)
}

extension RichText {
    public func previewAttributedText(strings: PresentationStrings) -> NSAttributedString {
        return buildInstantPagePreview(blocks: [.paragraph(self)], environment: previewEnvironment(strings: strings, media: [:]))
    }

    public func previewText(strings: PresentationStrings) -> String {
        return instantPagePreviewPlainText(self.previewAttributedText(strings: strings))
    }
}

extension InstantPageListItem {
    public func previewAttributedText(strings: PresentationStrings, media: [MediaId: Media]) -> NSAttributedString {
        return buildInstantPagePreview(blocks: [.list(items: [self], ordered: false)], environment: previewEnvironment(strings: strings, media: media))
    }

    public func previewText(strings: PresentationStrings, media: [MediaId: Media]) -> String {
        return instantPagePreviewPlainText(self.previewAttributedText(strings: strings, media: media))
    }
}

extension InstantPageBlock {
    public func previewAttributedText(strings: PresentationStrings, media: [MediaId: Media]) -> NSAttributedString {
        return buildInstantPagePreview(blocks: [self], environment: previewEnvironment(strings: strings, media: media))
    }

    public func previewText(strings: PresentationStrings, media: [MediaId: Media]) -> String {
        return instantPagePreviewPlainText(self.previewAttributedText(strings: strings, media: media))
    }
}

extension InstantPage {
    public func previewAttributedText(strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat? = nil, associatedMedia: [MediaId: Media] = [:]) -> NSAttributedString {
        let media = associatedMedia.merging(self.media, uniquingKeysWith: { _, pageMedia in pageMedia })
        return buildInstantPagePreview(blocks: self.blocks, environment: previewEnvironment(strings: strings, dateTimeFormat: dateTimeFormat, media: media))
    }

    public func previewText(strings: PresentationStrings) -> String {
        return instantPagePreviewPlainText(self.previewAttributedText(strings: strings))
    }
}
