import Foundation
import UIKit
import Display
import TelegramCore

/// A bubble content node showing quotable message text: it can select a quote, build it, and
/// highlight one. The text bubble implements it for plain messages, the rich-data bubble for rich
/// ones, so reply options, the context-menu Quote action and quote highlighting need not know which.
public protocol ChatMessageQuoteSourceContentNode: AnyObject {
    func getQuoteRect(quote: String, offset: Int?) -> CGRect?
    func updateQuoteTextHighlightState(text: String?, offset: Int?, color: UIColor, animated: Bool)
    func animateQuoteTextHighlightIn(sourceFrame: CGRect, transition: ContainedViewLayoutTransition) -> CGRect?
    func beginTextSelection(range: NSRange?, displayMenu: Bool)
    func cancelTextSelection()
    /// Whether a non-empty text selection exists, quotable or not.
    var hasTextSelection: Bool { get }
    /// The reply quote for the current text selection, or nil when nothing quotable is selected.
    func currentReplyQuote(maxLength: Int) -> EngineMessageReplyQuote?
}
