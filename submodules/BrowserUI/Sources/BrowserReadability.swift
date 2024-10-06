import Foundation
import WebKit
import AppBundle
import Postbox
import TelegramCore
import InstantPageUI

public class Readability: NSObject, WKNavigationDelegate {
    private let url: URL
    let webView: WKWebView
    private let completionHandler: ((_ webPage: (TelegramMediaWebpage, [Any]?)?, _ error: Error?) -> Void)
    private var hasRenderedReadabilityHTML = false
    
    private var subresources: [Any]?
    
    init(url: URL, archiveData: Data, completionHandler: @escaping (_ webPage: (TelegramMediaWebpage, [Any]?)?, _ error: Error?) -> Void) {
        self.url = url
        self.completionHandler = completionHandler
        
        let preferences = WKPreferences()

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController.addUserScript(ReadabilityUserScript())
        
        self.webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        
        super.init()
        
        self.webView.configuration.suppressesIncrementalRendering = true
        self.webView.navigationDelegate = self
        if #available(iOS 16.4, *) {
            self.webView.isInspectable = true
        }
        
        if let (html, subresources) = extractHtmlString(from: archiveData) {
            self.subresources = subresources
            self.webView.loadHTMLString(html, baseURL: url.baseURL)
        }
    }
    
    private func initializeReadability(completion: @escaping (_ result: TelegramMediaWebpage?, _ error: Error?) -> Void) {
        guard let readabilityInitializationJS = loadFile(name: "ReaderMode", type: "js") else {
            return
        }
        
        self.webView.evaluateJavaScript(readabilityInitializationJS) { (result, error) in
            guard let result = result as? [String: Any] else {
                completion(nil, error)
                return
            }
            guard let page = parseJson(result, url: self.url.absoluteString) else {
                return
            }
            completion(page, nil)
        }
    }
        
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !self.hasRenderedReadabilityHTML {
            self.initializeReadability() { [weak self] (webPage: TelegramMediaWebpage?, error: Error?) in
                guard let self else {
                    return
                }
                self.hasRenderedReadabilityHTML = true
                guard let webPage else {
                    self.completionHandler(nil, error)
                    return
                }
                self.completionHandler((webPage, self.subresources), error)
            }
        }
    }
}

class ReadabilityUserScript: WKUserScript {
    convenience override init() {
        guard let js = loadFile(name: "Readability", type: "js") else {
            fatalError()
        }
        self.init(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}

func loadFile(name: String, type: String) -> String? {
    let bundle = getAppBundle()
    guard let userScriptPath = bundle.path(forResource: name, ofType: type) else {
        return nil
    }
    guard let userScriptData = try? Data(contentsOf: URL(fileURLWithPath: userScriptPath)) else {
        return nil
    }
    guard let userScript = String(data: userScriptData, encoding: .utf8) else {
        return nil
    }
    return userScript
}

private func extractHtmlString(from webArchiveData: Data) -> (String, [Any]?)? {
    if let webArchiveDict = try? PropertyListSerialization.propertyList(from: webArchiveData, format: nil) as? [String: Any],
        let mainResource = webArchiveDict["WebMainResource"] as? [String: Any],
        let htmlData = mainResource["WebResourceData"] as? Data {
        
        guard let htmlString = String(data: htmlData, encoding: .utf8) else {
            return nil
        }
        return (htmlString, webArchiveDict["WebSubresources"] as? [Any])
    }
    return nil
}

private func parseJson(_ input: [String: Any], url: String) -> TelegramMediaWebpage? {
    let siteName = input["siteName"] as? String
    let title = input["title"] as? String
    let byline = input["byline"] as? String
    let excerpt = input["excerpt"] as? String
    
    var media: [MediaId: Media] = [:]
    let blocks = parseContent(input, url, &media)
        
    guard !blocks.isEmpty else {
        return nil
    }
    return TelegramMediaWebpage(
        webpageId: MediaId(namespace: 0, id: 0),
        content: .Loaded(
            TelegramMediaWebpageLoadedContent(
                url: url,
                displayUrl: url,
                hash: 0,
                type: "article",
                websiteName: siteName,
                title: title,
                text: excerpt,
                embedUrl: nil,
                embedType: nil,
                embedSize: nil,
                duration: nil,
                author: byline,
                isMediaLargeByDefault: nil,
                image: nil,
                file: nil,
                story: nil,
                attributes: [],
                instantPage: InstantPage(
                    blocks: blocks,
                    media: media,
                    isComplete: true,
                    rtl: false,
                    url: url,
                    views: nil
                )
            )
        )
    )
}

private func parseContent(_ input: [String: Any], _ url: String, _ media: inout [MediaId: Media]) -> [InstantPageBlock] {
    let title = input["title"] as? String
    let byline = input["byline"] as? String
    let date = input["publishedTime"] as? String
    
    let _ = date
    
    guard let content = input["content"] as? [Any] else {
        return []
    }
    var blocks = parsePageBlocks(content, url, &media)
    if case .header = blocks.first {
    } else {
        if var byline {
            byline = byline.replacingOccurrences(of: "[\n\t]+", with: " ", options: .regularExpression, range: nil)
            blocks.insert(.authorDate(author: trim(parseRichText(byline)), date: 0), at: 0)
        }
        if let title {
            blocks.insert(.title(trim(parseRichText(title))), at: 0)
        }
    }
    
    return blocks
}

private func parseRichText(_ input: String) -> RichText {
    return .plain(input)
}

private func parseRichText(_ input: [String: Any], _ media: inout [MediaId: Media]) -> RichText {
    var text: RichText
    if let string = input["content"] as? String {
        text = parseRichText(string)
    } else if let array = input["content"] as? [Any] {
        text = parseRichText(array, &media)
    } else {
        text = .empty
    }
    text = applyAnchor(text, item: input)
    if let _ = input["bold"] {
        text = .bold(text)
    }
    if let _ = input["italic"] {
        text = .italic(text)
    }
    return text
}

private func parseRichText(_ input: [Any], _ media: inout [MediaId: Media]) -> RichText {
    var result: [RichText] = []
    
    for item in input {
        if let string = item as? String {
            result.append(parseRichText(string))
        } else if let item = item as? [String: Any], let tag = item["tag"] as? String {
            var text: RichText?
            var addLineBreak = false
            switch tag {
            case "b", "strong":
                text = .bold(parseRichText(item, &media))
            case "i":
                text = .italic(parseRichText(item, &media))
            case "s":
                text = .strikethrough(parseRichText(item, &media))
            case "p":
                text =  parseRichText(item, &media)
            case "a":
                if let href = item["href"] as? String {
                    let telString = "tel:"
                    let mailtoString  = "mailto:"
                    if href.hasPrefix("tel:") {
                        text = .phone(text: parseRichText(item, &media), phone: String(href[href.index(href.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...]))
                    } else if href.hasPrefix(mailtoString) {
                        text = .email(text: parseRichText(item, &media), email: String(href[href.index(href.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...]))
                    } else {
                        text = .url(text: parseRichText(item, &media), url: href, webpageId: nil)
                    }
                } else {
                    text = parseRichText(item, &media)
                }
            case "pre", "code":
                text = .fixed(parseRichText(item, &media))
            case "mark":
                text = .marked(parseRichText(item, &media))
            case "sub":
                text = .subscript(parseRichText(item, &media))
            case "sup":
                text = .superscript(parseRichText(item, &media))
            case "img":
                if let src = item["src"] as? String, !src.isEmpty {
                    let width: Int32
                    if let value = item["width"] as? String, let intValue = Int32(value) {
                        width = intValue
                    } else {
                        width = 0
                    }
                    let height: Int32
                    if let value = item["height"] as? String, let intValue = Int32(value) {
                        height = intValue
                    } else {
                        height = 0
                    }
                    let id = MediaId(namespace: Namespaces.Media.CloudFile, id: Int64(media.count))
                    media[id] = TelegramMediaImage(
                        imageId: id,
                        representations: [
                            TelegramMediaImageRepresentation(
                                dimensions: PixelDimensions(width: width, height: height),
                                resource: InstantPageExternalMediaResource(url: src),
                                progressiveSizes: [],
                                immediateThumbnailData: nil
                            )
                        ],
                        immediateThumbnailData: nil,
                        reference: nil,
                        partialReference: nil,
                        flags: []
                    )
                    text = .image(id: id, dimensions: PixelDimensions(width: width, height: height))
                    if width > 100 {
                        addLineBreak = true
                    }
                }
            case "br":
                if let last = result.last {
                    result[result.count - 1] = addNewLine(last)
                }
            default:
                text = parseRichText(item, &media)
            }
            if var text {
                text = applyAnchor(text, item: item)
                result.append(text)
                if addLineBreak {
                    result.append(.plain("\n"))
                }
            }
        }
    }
    
    if !result.isEmpty {
        return .concat(result)
    } else if result.count == 1, let text = result.first {
        return text
    } else {
        return .empty
    }
}

private func trimStart(_ input: RichText) -> RichText {
    var text = input
    switch input {
    case .empty:
        text = .empty
    case let .plain(string):
        text = .plain(string.replacingOccurrences(of: "^[ \t\r\n]+", with: "", options: .regularExpression, range: nil))
    case let .bold(richText):
        text = .bold(trimStart(richText))
    case let .italic(richText):
        text = .italic(trimStart(richText))
    case let .underline(richText):
        text = .underline(trimStart(richText))
    case let .strikethrough(richText):
        text = .strikethrough(trimStart(richText))
    case let .fixed(richText):
        text = .fixed(trimStart(richText))
    case let .url(richText, url, webpageId):
        text = .url(text: trimStart(richText), url: url, webpageId: webpageId)
    case let .email(richText, email):
        text = .email(text: trimStart(richText), email: email)
    case let .subscript(richText):
        text = .subscript(trimStart(richText))
    case let .superscript(richText):
        text = .superscript(trimStart(richText))
    case let .marked(richText):
        text = .marked(trimStart(richText))
    case let .phone(richText, phone):
        text = .phone(text: trimStart(richText), phone: phone)
    case let .anchor(richText, name):
        text = .anchor(text: trimStart(richText), name: name)
    case var .concat(array):
        if !array.isEmpty {
            array[0] = trimStart(array[0])
            text = .concat(array)
        }
    case .image:
        break
    }
    return text
}

private func trimEnd(_ input: RichText) -> RichText {
    var text = input
    switch input {
    case .empty:
        text = .empty
    case let .plain(string):
        text = .plain(string.replacingOccurrences(of: "[ \t\r\n]+$", with: "", options: .regularExpression, range: nil))
    case let .bold(richText):
        text = .bold(trimStart(richText))
    case let .italic(richText):
        text = .italic(trimStart(richText))
    case let .underline(richText):
        text = .underline(trimStart(richText))
    case let .strikethrough(richText):
        text = .strikethrough(trimStart(richText))
    case let .fixed(richText):
        text = .fixed(trimStart(richText))
    case let .url(richText, url, webpageId):
        text = .url(text: trimStart(richText), url: url, webpageId: webpageId)
    case let .email(richText, email):
        text = .email(text: trimStart(richText), email: email)
    case let .subscript(richText):
        text = .subscript(trimStart(richText))
    case let .superscript(richText):
        text = .superscript(trimStart(richText))
    case let .marked(richText):
        text = .marked(trimStart(richText))
    case let .phone(richText, phone):
        text = .phone(text: trimStart(richText), phone: phone)
    case let .anchor(richText, name):
        text = .anchor(text: trimStart(richText), name: name)
    case var .concat(array):
        if !array.isEmpty {
            array[array.count - 1] = trimStart(array[array.count - 1])
            text = .concat(array)
        }
    case .image:
        break
    }
    return text
}

private func trim(_ input: RichText) -> RichText {
    var text = input
    switch input {
    case .empty:
        text = .empty
    case let .plain(string):
        text = .plain(string.trimmingCharacters(in: .whitespacesAndNewlines))
    case let .bold(richText):
        text = .bold(trimStart(richText))
    case let .italic(richText):
        text = .italic(trimStart(richText))
    case let .underline(richText):
        text = .underline(trimStart(richText))
    case let .strikethrough(richText):
        text = .strikethrough(trimStart(richText))
    case let .fixed(richText):
        text = .fixed(trimStart(richText))
    case let .url(richText, url, webpageId):
        text = .url(text: trimStart(richText), url: url, webpageId: webpageId)
    case let .email(richText, email):
        text = .email(text: trimStart(richText), email: email)
    case let .subscript(richText):
        text = .subscript(trimStart(richText))
    case let .superscript(richText):
        text = .superscript(trimStart(richText))
    case let .marked(richText):
        text = .marked(trimStart(richText))
    case let .phone(richText, phone):
        text = .phone(text: trimStart(richText), phone: phone)
    case let .anchor(richText, name):
        text = .anchor(text: trimStart(richText), name: name)
    case var .concat(array):
        if !array.isEmpty {
            array[0] = trimStart(array[0])
            array[array.count - 1] = trimEnd(array[array.count - 1])
            text = .concat(array)
        }
    case .image:
        break
    }
    return text
}

private func addNewLine(_ input: RichText) -> RichText {
    var text = input
    switch input {
    case .empty:
        text = .empty
    case let .plain(string):
        text = .plain(string + "\n")
    case let .bold(richText):
        text = .bold(addNewLine(richText))
    case let .italic(richText):
        text = .italic(addNewLine(richText))
    case let .underline(richText):
        text = .underline(addNewLine(richText))
    case let .strikethrough(richText):
        text = .strikethrough(addNewLine(richText))
    case let .fixed(richText):
        text = .fixed(addNewLine(richText))
    case let .url(richText, url, webpageId):
        text = .url(text: addNewLine(richText), url: url, webpageId: webpageId)
    case let .email(richText, email):
        text = .email(text: addNewLine(richText), email: email)
    case let .subscript(richText):
        text = .subscript(addNewLine(richText))
    case let .superscript(richText):
        text = .superscript(addNewLine(richText))
    case let .marked(richText):
        text = .marked(addNewLine(richText))
    case let .phone(richText, phone):
        text = .phone(text: addNewLine(richText), phone: phone)
    case let .anchor(richText, name):
        text = .anchor(text: addNewLine(richText), name: name)
    case var .concat(array):
        if !array.isEmpty {
            array[array.count - 1] = addNewLine(array[array.count - 1])
            text = .concat(array)
        }
    case .image:
        break
    }
    return text
}

private func applyAnchor(_ input: RichText, item: [String: Any]) -> RichText {
    guard let id = item["id"] as? String, !id.isEmpty else {
        return input
    }
    return .anchor(text: input, name: id)
}

private func parseTable(_ input: [String: Any], _ media: inout [MediaId: Media]) -> InstantPageBlock {
    let title = (input["title"] as? String) ?? ""
    return .table(
        title: trim(applyAnchor(parseRichText(title), item: input)),
        rows: parseTableRows((input["content"] as? [Any]) ?? [], &media),
        bordered: true,
        striped: true
    )
}

private func parseTableRows(_ input: [Any], _ media: inout [MediaId: Media]) -> [InstantPageTableRow] {
    var result: [InstantPageTableRow] = []
    for item in input {
        if let item = item as? [String: Any] {
            let tag = item["tag"] as? String
            if tag == "tr" {
                result.append(parseTableRow(item, &media))
            } else if let content = item["content"] as? [Any] {
                result.append(contentsOf: parseTableRows(content, &media))
            }
        }
    }
    return result
}

private func parseTableRow(_ input: [String: Any], _ media: inout [MediaId: Media]) -> InstantPageTableRow {
    var cells: [InstantPageTableCell] = []
    
    if let content = input["content"] as? [Any] {
        for item in content {
            guard let item = item as? [String: Any] else {
                continue
            }
            let tag = item["tag"] as? String
            guard ["td", "th"].contains(tag) else {
                continue
            }
            var text: RichText?
            if let content = item["content"] as? [Any] {
                text = trim(parseRichText(content, &media))
                if let currentText = text {
                    if let _ = item["bold"] {
                        text = .bold(currentText)
                    }
                    if let _ = item["italic"] {
                        text = .italic(currentText)
                    }
                }
            }
            cells.append(InstantPageTableCell(
                text: text,
                header: tag == "th",
                alignment: item["xcenter"] != nil ? .center : .left,
                verticalAlignment: .middle,
                colspan: ((item["colspan"] as? String).flatMap { Int32($0) }) ?? 0,
                rowspan: ((item["rowspan"] as? String).flatMap { Int32($0) }) ?? 0
            ))
        }
    }
    
    return InstantPageTableRow(cells: cells)
}

private func parseDetails(_ item: [String: Any], _ url: String, _ media: inout [MediaId: Media]) -> InstantPageBlock? {
    guard var content = item["contant"] as? [Any] else {
        return nil
    }
    var title: RichText = .empty
    var titleIndex: Int?
    for i in 0 ..< content.count {
        if let subitem = content[i] as? [String: Any], let tag = subitem["tag"] as? String, tag == "summary" {
            title = trim(parseRichText(subitem, &media))
            titleIndex = i
            break
        }
    }
    if let titleIndex {
        content.remove(at: titleIndex)
    }
    return .details(
        title: title,
        blocks: parsePageBlocks(content, url, &media),
        expanded: item["open"] != nil
    )
}

private let nonListCharacters = CharacterSet(charactersIn: "0123456789").inverted
private func parseList(_ input: [String: Any], _ url: String, _ media: inout [MediaId: Media]) -> InstantPageBlock? {
    guard let content = input["content"] as? [Any], let tag = input["tag"] as? String else {
        return nil
    }
    var items: [InstantPageListItem] = []
    for item in content {
        guard let item = item as? [String: Any], let tag = item["tag"] as? String, tag == "li" else {
            continue
        }
        var parseAsBlocks = false
        if let subcontent = item["content"] as? [Any] {
            for item in subcontent {
                if let item = item as? [String: Any], let tag = item["tag"] as? String, ["ul", "ol"].contains(tag) {
                    parseAsBlocks = true
                }
            }
            if parseAsBlocks {
                let blocks = parsePageBlocks(subcontent, url, &media)
                if !blocks.isEmpty {
                    items.append(.blocks(blocks, nil))
                }
            } else {
                items.append(.text(trim(parseRichText(item, &media)), nil))
            }
        }
    }
    let ordered = tag == "ol"
    var allEmpty = true
    for item in items {
        if case let .text(text, _) = item {
            if case .empty = text {
            } else {
                let plainText = text.plainText
                if !plainText.isEmpty && plainText.rangeOfCharacter(from: nonListCharacters) != nil {
                    allEmpty = false
                }
                break
            }
        } else {
            allEmpty = false
            break
        }
    }
    guard !allEmpty else {
        return nil
    }
    return .list(items: items, ordered: ordered)
}

private func parseImage(_ input: [String: Any], _ media: inout [MediaId: Media]) -> InstantPageBlock? {
    guard let src = input["src"] as? String else {
        return nil
    }
    
    let caption: InstantPageCaption
    if let alt = input["alt"] as? String {
        caption = InstantPageCaption(
            text: trim(parseRichText(alt)),
            credit: .empty
        )
    } else {
        caption = InstantPageCaption(text: .empty, credit: .empty)
    }
            
    let width: Int32
    if let value = input["width"] as? String, let intValue = Int32(value) {
        width = intValue
    } else {
        width = 0
    }
    
    let height: Int32
    if let value = input["height"] as? String, let intValue = Int32(value) {
        height = intValue
    } else {
        height = 0
    }
    
    let id = MediaId(namespace: Namespaces.Media.CloudImage, id: Int64(media.count))
    media[id] = TelegramMediaImage(
        imageId: id,
        representations: [
            TelegramMediaImageRepresentation(
                dimensions: PixelDimensions(width: width, height: height),
                resource: InstantPageExternalMediaResource(url: src),
                progressiveSizes: [],
                immediateThumbnailData: nil
            )
        ],
        immediateThumbnailData: nil,
        reference: nil,
        partialReference: nil,
        flags: []
    )

    return .image(
        id: id,
        caption: caption,
        url: nil,
        webpageId: nil
    )
}

private func parseVideo(_ input: [String: Any], _ media: inout [MediaId: Media]) -> InstantPageBlock? {
    guard let src = input["src"] as? String else {
        return nil
    }
    
    let width: Int32
    if let value = input["width"] as? String, let intValue = Int32(value) {
        width = intValue
    } else {
        width = 0
    }
    
    let height: Int32
    if let value = input["height"] as? String, let intValue = Int32(value) {
        height = intValue
    } else {
        height = 0
    }
    
    return .webEmbed(
        url: src,
        html: nil,
        dimensions: PixelDimensions(width: width, height: height),
        caption: InstantPageCaption(text: .empty, credit: .empty),
        stretchToWidth: true,
        allowScrolling: false,
        coverId: nil
    )
}

private func parseFigure(_ input: [String: Any], _ media: inout [MediaId: Media]) -> InstantPageBlock? {
    guard let content = input["content"] as? [Any] else {
        return nil
    }
    var block: InstantPageBlock?
    var caption: RichText?
    for item in content {
        if let item = item as? [String: Any], let tag = item["tag"] as? String {
            if tag == "p", let content = item["content"] as? [Any] {
                for item in content {
                    if let item = item as? [String: Any], let tag = item["tag"] as? String {
                        if tag == "iframe" {
                            block = parseVideo(item, &media)
                        }
                    }
                }
            } else if tag == "iframe" {
                block = parseVideo(item, &media)
            } else if tag == "img" {
                block = parseImage(item, &media)
            } else if tag == "figcaption" {
                caption = trim(parseRichText(item, &media))
            }
        }
    }
    guard var block else {
        return nil
    }
    if let caption, case let .image(id, _, url, webpageId) = block {
        block = .image(id: id, caption: InstantPageCaption(text: caption, credit: .empty), url: url, webpageId: webpageId)
    }
    return block
}

private func parsePageBlocks(_ input: [Any], _ url: String, _ media: inout [MediaId: Media]) -> [InstantPageBlock] {
    var result: [InstantPageBlock] = []
    for item in input {
        if let string = item as? String {
            result.append(.paragraph(trim(parseRichText(string))))
        } else if let item = item as? [String: Any], let tag = item["tag"] as? String {
            let content = item["content"] as? [Any]
            switch tag {
            case "p":
                result.append(.paragraph(trim(parseRichText(item, &media))))
            case "h1", "h2":
                result.append(.header(trim(parseRichText(item, &media))))
            case "h3", "h4", "h5", "h6":
                result.append(.subheader(trim(parseRichText(item, &media))))
            case "pre":
                result.append(.preformatted(.fixed(trim(parseRichText(item, &media)))))
            case "blockquote":
                result.append(.blockQuote(text: .italic(trim(parseRichText(item, &media))), caption: .empty))
            case "img":
                if let image = parseImage(item, &media) {
                    result.append(image)
                }
            case "iframe":
                if let video = parseVideo(item, &media) {
                    result.append(video)
                }
            case "figure":
                if let figure = parseFigure(item, &media) {
                    result.append(figure)
                }
            case "table":
                result.append(parseTable(item, &media))
            case "ul", "ol":
                if let list = parseList(item, url, &media) {
                    result.append(list)
                }
            case "hr":
                result.append(.divider)
            case "details":
                if let details = parseDetails(item, url, &media) {
                    result.append(details)
                }
            default:
                if let content {
                    result.append(contentsOf: parsePageBlocks(content, url, &media))
                }
            }
        }
    }
    return result
}
