import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import InstantPageUI
import InstantPageCache
import UrlHandling

private func extractAnchor(string: String) -> (String, String?) {
    var anchorValue: String?
    if let anchorRange = string.range(of: "#") {
        let anchor = string[anchorRange.upperBound...]
        if !anchor.isEmpty {
            anchorValue = String(anchor)
        }
    }
    var trimmedUrl = string
    if let anchor = anchorValue, let anchorRange = string.range(of: "#\(anchor)") {
        let url = string[..<anchorRange.lowerBound]
        if !url.isEmpty {
            trimmedUrl = String(url)
        }
    }
    return (trimmedUrl, anchorValue)
}

private let refreshTimeout: Int32 = 60 * 60 * 12

public func cachedFaqInstantPage(context: AccountContext) -> Signal<ResolvedUrl, NoError> {
    var faqUrl = context.sharedContext.currentPresentationData.with { $0 }.strings.Settings_FAQ_URL
    if faqUrl == "Settings.FAQ_URL" || faqUrl.isEmpty {
        faqUrl = "https://telegram.org/faq#general-questions"
    }
    
    let (cachedUrl, anchor) = extractAnchor(string: faqUrl)

    return cachedInstantPage(postbox: context.account.postbox, url: cachedUrl)
    |> mapToSignal { cachedInstantPage -> Signal<ResolvedUrl, NoError> in
        let updated = resolveInstantViewUrl(account: context.account, url: faqUrl)
        |> afterNext { result in
            if case let .instantView(webPage, _) = result, case let .Loaded(content) = webPage.content, let instantPage = content.instantPage {
                if instantPage.isComplete {
                    let _ = updateCachedInstantPage(postbox: context.account.postbox, url: cachedUrl, webPage: webPage).start()
                } else {
                    let _ = (actualizedWebpage(postbox: context.account.postbox, network: context.account.network, webpage: webPage)
                    |> mapToSignal { webPage -> Signal<Void, NoError> in
                        if case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, instantPage.isComplete {
                            return updateCachedInstantPage(postbox: context.account.postbox, url: cachedUrl, webPage: webPage)
                        } else {
                            return .complete()
                        }
                    }).start()
                }
            }
        }
        
        let now = Int32(CFAbsoluteTimeGetCurrent())
        if let cachedInstantPage = cachedInstantPage, case let .Loaded(content) = cachedInstantPage.webPage.content, let instantPage = content.instantPage, instantPage.isComplete {
            let current: Signal<ResolvedUrl, NoError> = .single(.instantView(cachedInstantPage.webPage, anchor))
            if now > cachedInstantPage.timestamp + refreshTimeout {
                return current
                |> then(updated)
            } else {
                return current
            }
        } else {
            return updated
        }
    }
}

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
