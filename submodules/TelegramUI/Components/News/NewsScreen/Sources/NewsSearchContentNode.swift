import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SearchUI
import CoreList
import CoreListComponentHost
import NewsFeedSupport

/// News search: the posts the feeds hold whose text or channel title has every word of the query, as feed rows,
/// newest first. Local until `feed.getForYou` takes a query; then `corpus` becomes the server's answer.
final class NewsSearchContentNode: SearchDisplayControllerContentNode {
    private var presentationData: PresentationData
    private let corpus: () -> NewsSearchCorpus
    private let itemEnvironment: (NewsFeedListView) -> NewsFeedItemEnvironment?
    private let listView = NewsFeedListView()

    private var queryWords: [String] = []
    /// Built on the first query and kept until the feeds change: building folds every post's text, a keystroke
    /// only matches.
    private var cachedCorpus: NewsSearchCorpus?
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?

    init(presentationData: PresentationData, corpus: @escaping () -> NewsSearchCorpus, itemEnvironment: @escaping (NewsFeedListView) -> NewsFeedItemEnvironment?) {
        self.presentationData = presentationData
        self.corpus = corpus
        self.itemEnvironment = itemEnvironment

        super.init()

        self.listView.reduceMotion = presentationData.reduceMotion
        self.view.addSubview(self.listView)
        self.listView.onWillBeginDragging = { [weak self] in
            self?.dismissInput?()
        }
    }

    override func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.listView.reduceMotion = presentationData.reduceMotion
        self.updateResults(scrollToTop: false)
    }

    override func searchTextUpdated(text: String) {
        let queryWords = newsSearchQueryWords(text)
        guard queryWords != self.queryWords else {
            return
        }
        self.queryWords = queryWords
        self.updateResults(scrollToTop: true)
    }

    /// The feeds changed under the search (a page arrived, a post was edited or deleted).
    func corpusUpdated() {
        self.cachedCorpus = nil
        self.updateResults(scrollToTop: false)
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        self.validLayout = (layout, navigationBarHeight)
        transition.updateFrame(view: self.listView, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.updateResults(scrollToTop: false, transition: CoreListTransition(transition))
    }

    override func scrollToTop() {
        self.listView.scrollToTop()
    }

    private func updateResults(scrollToTop: Bool, transition: CoreListTransition = .immediate) {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        let insets = UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right)

        var items: [CoreListComponentItem] = []
        if !self.queryWords.isEmpty, let environment = self.itemEnvironment(self.listView) {
            let corpus = self.cachedCorpus ?? self.corpus()
            self.cachedCorpus = corpus
            // `newsSearchResults` finds each post once; still never hand CoreList a repeated identity.
            var usedIdentities = Set<AnyHashable>()
            for document in newsSearchResults(queryWords: self.queryWords, documents: corpus.documents) {
                if let item = newsPostItem(entry: document.entry, messages: corpus.messages, environment: environment), usedIdentities.insert(item.identity).inserted {
                    items.append(item)
                }
            }
            if items.isEmpty {
                items.append(newsStatusItem(theme: self.presentationData.theme, text: self.presentationData.strings.ChatList_Search_NoResults, actionTitle: nil, action: nil))
            }
        }
        let scrollTo = scrollToTop && !items.isEmpty ? CoreListScrollTarget(index: 0, pointOffset: 0.0) : nil
        self.listView.update(size: layout.size, insets: insets, items: items, scrollTo: scrollTo, anchorMode: .automatic, transition: transition)
    }
}
