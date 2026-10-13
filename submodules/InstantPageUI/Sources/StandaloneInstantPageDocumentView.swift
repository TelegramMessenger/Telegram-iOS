import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import TelegramPresentationData

/// A self-contained, host-embeddable view that renders ONE standalone document (a generic file) as a
/// file row, mirroring `StandaloneInstantPageAudioView`. Built for the RichTextEditor, which shows a
/// freshly-picked (or edit-loaded) file outside any web page / message.
///
/// Always constructed in the node's **authoring** mode: a static file glyph, no fetch, inert tap. An
/// authoring row has nothing to download — a just-picked file is local, and an edit-loaded cloud file
/// is re-sent by reference through `richMessageContentToUpload`'s already-cloud fast path. Downloading,
/// progress, cancel and tap-to-open belong to the message-side `InstantPageV2DocumentView`.
@available(iOS 13.0, *)
public final class StandaloneInstantPageDocumentView: UIView {
    private let documentNode: InstantPageV2DocumentContentNode

    public init(context: AccountContext, file: TelegramMediaFile, colorOverride: InstantPageDocumentColorOverride? = nil) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        // Authoring: always outgoing, no message reference.
        self.documentNode = InstantPageV2DocumentContentNode(
            context: context, message: nil, file: file, incoming: false,
            presentationData: presentationData, colorOverride: colorOverride, isAuthoring: true
        )
        super.init(frame: .zero)
        self.addSubview(self.documentNode.view)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The editor owns this view's frame and calls this on every layout pass; lay out against the given
    /// size only (repo rule: a view never writes its own frame).
    public func update(size: CGSize) {
        self.documentNode.frame = CGRect(origin: .zero, size: size)
        self.documentNode.updateLayout(width: size.width)
    }
}
