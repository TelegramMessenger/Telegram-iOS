import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import InstantPageUI
import InstantPageCache
import UrlHandling

func faqSearchableItems(context: AccountContext, resolvedUrl: Signal<ResolvedUrl?, NoError>, suggestAccountDeletion: Bool) -> Signal<[SettingsSearchableItem], NoError> {
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    return resolvedUrl
    |> map { resolvedUrl -> [SettingsSearchableItem] in
        var results: [SettingsSearchableItem] = []
        var nextIndex: Int32 = 2
        if let resolvedUrl = resolvedUrl, case let .instantView(webPage, _) = resolvedUrl {
            if case let .Loaded(content) = webPage.content, let instantPage = content.instantPage {
                var processingQuestions = false
                var currentSection: String?
                outer: for block in instantPage.blocks {
                    if !processingQuestions {
                        switch block {
                            case .blockQuote:
                                if results.isEmpty {
                                    processingQuestions = true
                                }
                            default:
                                break
                        }
                    } else {
                        switch block {
                            case let .paragraph(text):
                                if case .bold = text {
                                    currentSection = text.plainText
                                } else if case .concat = text {
                                    processingQuestions = false
                                }
                            case let .list(items, false):
                                if let currentSection = currentSection {
                                    for item in items {
                                        if case let .text(itemText, _) = item, case let .url(text, url, _) = itemText {
                                            let (_, anchor) = extractAnchor(string: url)
                                            var index = nextIndex
                                            if suggestAccountDeletion && (anchor?.contains("delete-my-account") ?? false) {
                                                index = 1
                                            } else {
                                                nextIndex += 1
                                            }
                                            let item = SettingsSearchableItem(id: .faq(index), title: text.plainText, alternate: [], icon: .faq, breadcrumbs: [strings.SettingsSearch_FAQ, currentSection], present: { context, _, present in
                                                present(.push, InstantPageController(context: context, webPage: webPage, sourcePeerType: .channel, anchor: anchor))
                                            })
                                            if index == 1 {
                                                results.insert(item, at: 0)
                                            } else {
                                                results.append(item)
                                            }
                                        }
                                    }
                                }
                            default:
                                break
                        }
                    }
                }
            }
        }
        return results
    }
}
