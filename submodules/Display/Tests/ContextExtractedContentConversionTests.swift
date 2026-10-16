import XCTest
import UIKit
import AsyncDisplayKit
import Display

/// `ContextExtractedContentContainingNode.convertFromContent`: a rect inside extracted content, in the
/// coordinate space of a view outside it, as if the content had not been extracted.
///
/// The chat's scroll hold re-reads a quote's rect in the message node on every held pass
/// (`ChatMessageBubbleItemNode.getQuoteRect`), including passes made while that message is in a
/// context menu. A direct `UIView.convert` across the extraction boundary returned `CGRect.null`
/// there, the hold placed the message at infinity, and CoreList crashed on the date header's NaN
/// position.
final class ContextExtractedContentConversionTests: XCTestCase {
    private struct Fixture {
        let itemView: UIView
        let containing: ContextExtractedContentContainingNode
        let deepView: UIView
    }

    /// A message node in miniature: the containing node sits at a non-zero offset inside the item,
    /// its content is laid out at its bounds (the precondition the helper documents), and the view a
    /// rect is measured in sits deeper inside the content.
    private func makeFixture() -> Fixture {
        let itemView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 800.0))
        let containing = ContextExtractedContentContainingNode()
        containing.frame = CGRect(x: 0.0, y: 37.0, width: 400.0, height: 300.0)
        containing.contentNode.frame = containing.bounds
        itemView.addSubview(containing.view)
        let deepView = UIView(frame: CGRect(x: 12.0, y: 20.0, width: 300.0, height: 200.0))
        containing.contentNode.view.addSubview(deepView)
        return Fixture(itemView: itemView, containing: containing, deepView: deepView)
    }

    private let rect = CGRect(x: 5.0, y: 7.0, width: 40.0, height: 30.0)

    func testContentInPlaceConvertsExactlyAsADirectConvert() {
        let fixture = makeFixture()
        let direct = fixture.deepView.convert(self.rect, to: fixture.itemView)
        XCTAssertEqual(direct, CGRect(x: 17.0, y: 64.0, width: 40.0, height: 30.0))

        XCTAssertEqual(fixture.containing.convertFromContent(self.rect, in: fixture.deepView, to: fixture.itemView), direct)
    }

    /// The node-API re-parenting `ContextControllerExtractedPresentationNode` uses
    /// (`offsetContainerNode.addSubnode(containingNode.contentNode)`).
    func testContentExtractedAsANodeConvertsAsIfInPlace() {
        let fixture = makeFixture()
        let inPlace = fixture.deepView.convert(self.rect, to: fixture.itemView)

        let contextRoot = ASDisplayNode()
        contextRoot.frame = CGRect(x: 0.0, y: 0.0, width: 400.0, height: 800.0)
        let offsetContainer = ASDisplayNode()
        offsetContainer.frame = CGRect(x: 23.0, y: 311.0, width: 400.0, height: 300.0)
        contextRoot.addSubnode(offsetContainer)
        offsetContainer.addSubnode(fixture.containing.contentNode)

        // The defect: across the boundary a direct convert no longer describes the item's geometry.
        XCTAssertNotEqual(fixture.deepView.convert(self.rect, to: fixture.itemView), inPlace)
        XCTAssertEqual(fixture.containing.convertFromContent(self.rect, in: fixture.deepView, to: fixture.itemView), inPlace)
    }

    /// The view-API re-parenting it also uses (`wrapper.addSubview(containingNode.contentNode.view)`).
    func testContentExtractedAsAViewConvertsAsIfInPlace() {
        let fixture = makeFixture()
        let inPlace = fixture.deepView.convert(self.rect, to: fixture.itemView)

        let contextRoot = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 800.0))
        let wrapper = UIView(frame: CGRect(x: 23.0, y: 311.0, width: 400.0, height: 300.0))
        contextRoot.addSubview(wrapper)
        wrapper.addSubview(fixture.containing.contentNode.view)

        XCTAssertNotEqual(fixture.deepView.convert(self.rect, to: fixture.itemView), inPlace)
        XCTAssertEqual(fixture.containing.convertFromContent(self.rect, in: fixture.deepView, to: fixture.itemView), inPlace)
    }

    /// Back in place, the direct convert is exact again and the helper follows it.
    func testContentReturnedToPlaceConvertsDirectlyAgain() {
        let fixture = makeFixture()
        let inPlace = fixture.deepView.convert(self.rect, to: fixture.itemView)

        let offsetContainer = ASDisplayNode()
        offsetContainer.frame = CGRect(x: 23.0, y: 311.0, width: 400.0, height: 300.0)
        offsetContainer.addSubnode(fixture.containing.contentNode)
        fixture.containing.addSubnode(fixture.containing.contentNode)
        fixture.containing.contentNode.frame = fixture.containing.bounds

        XCTAssertEqual(fixture.deepView.convert(self.rect, to: fixture.itemView), inPlace)
        XCTAssertEqual(fixture.containing.convertFromContent(self.rect, in: fixture.deepView, to: fixture.itemView), inPlace)
    }
}
