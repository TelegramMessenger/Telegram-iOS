import Foundation
import UIKit
import AsyncDisplayKit
import Display
import MultiScaleTextNode
import NavigationBarNode
import NavigationExpansionTransition

/// The profile's side of the chat → profile expansion: its avatar, title and status, action buttons, cover and list,
/// lent live and held still while lent.
final class PeerInfoExpansionDestination: NavigationExpansionDestinationProviding {
    private weak var screenNode: PeerInfoScreenNode?
    /// The profile's node, held while its views are on loan: the expansion can end after the profile is popped and
    /// released (it ends with the bars' lingering glass), and the views it returns belong to that node's tree.
    private var heldScreenNode: PeerInfoScreenNode?
    private weak var navigationBar: NavigationBarNode?
    let expansionPath: ExpansionPath
    private var homes: [(view: UIView, superview: UIView?, index: Int, frame: CGRect, isNodeBacked: Bool)] = []
    private var wrappers: [UIView] = []
    private var backgroundView: UIView?
    /// The cover's view and its own bounds and centre, while its clip is opened upward.
    private var coverClipHome: (view: UIView, bounds: CGRect, center: CGPoint)?

    init(screenNode: PeerInfoScreenNode, navigationBar: NavigationBarNode?, path: ExpansionPath) {
        self.screenNode = screenNode
        self.navigationBar = navigationBar
        self.expansionPath = path
    }

    private func remember(_ view: UIView) {
        let index = view.superview?.subviews.firstIndex(of: view) ?? 0
        self.homes.append((view, view.superview, index, view.frame, view.asyncdisplaykit_node != nil))
    }

    /// A header label: a `MultiScaleTextNode` has no size (its text is laid out around its origin) and a container above
    /// it scales it, so it is lent in a wrapper carrying the scale it has on screen, its text's centre where the scaled
    /// state's is. `followers` stay where they are and move with it.
    private func label(_ textNode: MultiScaleTextNode, key: AnyHashable, in screenView: UIView, followers: [UIView] = []) -> (label: NavigationExpansionLabel, color: UIColor)? {
        guard let state = textNode.stateNode(forKey: key), !state.bounds.isEmpty else {
            return nil
        }
        let screenRect = state.view.convert(state.bounds, to: screenView)
        let scale = screenRect.width / state.bounds.width
        let color = state.layer.layerTintColor.flatMap { UIColor(cgColor: $0) } ?? .white
        self.remember(textNode.view)
        let wrapper = UIView(frame: CGRect())
        wrapper.isUserInteractionEnabled = false
        wrapper.layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0)
        textNode.view.removeFromSuperview()
        textNode.view.frame = CGRect()
        wrapper.addSubview(textNode.view)
        self.wrappers.append(wrapper)
        let textCenter = CGPoint(x: state.frame.midX * scale, y: state.frame.midY * scale)
        let label = NavigationExpansionLabel(view: wrapper, textCenter: textCenter, textSize: screenRect.size, screenCenter: CGPoint(x: screenRect.midX, y: screenRect.midY), coloring: .multiply([state.layer], color), followers: followers)
        return (label, color)
    }

    func lendExpansionDestination(in screenView: UIView) -> NavigationExpansionDestinationLoan? {
        guard let node = self.screenNode, let layout = node.validLayout?.0 else {
            return nil
        }
        let header = node.headerNode

        // Measured before anything is lent. The circle flies to the round avatar on both paths; on the photo path it then
        // grows into the expanded photo, so it needs where the round avatar would be.
        let restFrame: CGRect
        let avatarFrame: CGRect?
        if self.expansionPath == .photo {
            let listContainer = header.avatarListNode.listContainerNode
            restFrame = listContainer.view.convert(listContainer.bounds, to: screenView)
            avatarFrame = header.expansionRoundAvatarFrame.flatMap { header.avatarClippingNode.view.convert($0, to: screenView) }
        } else {
            let avatarNode = header.avatarListNode.avatarContainerNode.avatarNode
            restFrame = avatarNode.view.convert(avatarNode.bounds, to: screenView)
            avatarFrame = restFrame
        }
        let banner = header.backgroundBannerView
        let carriedEdge = banner.convert(banner.bounds, to: screenView).maxY
        let backButtonFrame = self.navigationBar?.backButtonFrame(in: screenView)

        node.isLentToExpansion = true
        self.heldScreenNode = node

        // The page's colour as a view of its own, so it can fade in under the card while the node's own is clear.
        let background = UIView(frame: node.view.bounds)
        background.backgroundColor = node.backgroundColor
        background.isUserInteractionEnabled = false
        node.backgroundColor = .clear
        node.view.insertSubview(background, at: 0)
        node.expansionBackgroundView = background
        self.backgroundView = background

        // The cover lands with the page past its place (`pageEdgeViews`, below), but its view clips at its own top, 3 pt
        // above the screen, so moving it down showed a strip of what lies above it. Its gradient's colour reaches far
        // above that top; while lent the clip is opened upward over it, the content staying where it is.
        if let coverView = header.backgroundCover.view {
            let opening: CGFloat = 100.0
            self.coverClipHome = (coverView, coverView.bounds, coverView.center)
            coverView.bounds = CGRect(x: coverView.bounds.minX, y: coverView.bounds.minY - opening, width: coverView.bounds.width, height: coverView.bounds.height + opening)
            coverView.center = CGPoint(x: coverView.center.x, y: coverView.center.y - opening * 0.5)
        }

        let avatarView = header.avatarListNode.view
        self.remember(avatarView)

        // Each button's platter is a shape in the buttons' blur mask, so it appears with its button.
        let buttons = header.orderedButtonNodes
        let key: AnyHashable = self.expansionPath == .photo ? TitleNodeStateExpanded : TitleNodeStateRegular
        // The decorations around the status (level, badge, username, balance) move with it, fading with the list.
        let lent = [self.label(header.titleNode, key: key, in: screenView), self.label(header.subtitleNode, key: key, in: screenView, followers: header.expansionStatusFollowerViews)].compactMap { $0 }

        // On the photo path the header's content (buttons, badges, balance) lies on the expanded photo, which is drawn
        // above the card: it is lifted above the photo for the transition.
        var overlays: [UIView] = []
        // The expanded photo's top shadow and page strip lie on the header's content, not on the photo, so they would stay
        // at the top of the screen, over the chat's pill, as the photo flies back: they fade with the list, as the
        // profile's own collapse fades them.
        var photoControls: [UIView] = []
        if self.expansionPath == .photo {
            self.remember(header.regularContentNode.view)
            overlays.append(header.regularContentNode.view)
            photoControls.append(header.avatarListNode.listContainerNode.controlsContainerNode.view)
        }

        return NavigationExpansionDestinationLoan(
            avatar: avatarFrame,
            photo: self.expansionPath == .photo ? restFrame : nil,
            avatarView: avatarView,
            avatarRestFrame: restFrame,
            labels: lent.map { $0.label },
            labelColors: lent.map { $0.color },
            carriedEdge: carriedEdge,
            appearingViews: buttons.map { $0.view },
            appearingCompanions: buttons.map { [$0.backgroundContainerView] },
            overlayViews: overlays,
            backgroundViews: [background, banner],
            listViews: [node.scrollNode.view] + header.expansionDecorationViews + photoControls,
            // The page rides the status, as the prototype's actions and info card do: the list, the buttons and the music
            // strip.
            pageViews: [node.scrollNode.view] + header.expansionPageViews,
            // The cover clips at the header's bottom, the music strip's band: the edge rides the page with the band, its
            // gradient and pattern held still while the page comes in, as the prototype's gradient (which has no edge) is,
            // and landing with it past its place, so the background bounces with the avatar, the title and the page.
            pageEdgeViews: [banner],
            // The gifts around the avatar land with the cover.
            landingViews: header.giftsCover.view.flatMap { [$0] } ?? [],
            patternViews: header.giftsCover.view.flatMap { [$0] } ?? [],
            glassTint: header.expansionGlassTint,
            screenCornerRadii: layout.screenCornerRadii,
            backButtonFrame: backButtonFrame,
            avatarCornerFraction: header.avatarListNode.avatarContainerNode.cornerFraction
        )
    }

    func returnExpansionDestination() {
        defer {
            self.heldScreenNode = nil
        }
        for home in self.homes.reversed() {
            home.view.removeFromSuperview()
            // A node-backed view whose node is gone cannot go back (AsyncDisplayKit asserts on a nil subnode).
            if home.isNodeBacked && home.view.asyncdisplaykit_node == nil {
                continue
            }
            if let superview = home.superview {
                superview.insertSubview(home.view, at: min(home.index, superview.subviews.count))
            }
            home.view.frame = home.frame
        }
        self.homes = []
        for wrapper in self.wrappers {
            wrapper.removeFromSuperview()
        }
        self.wrappers = []
        // Before the held layout: setting a frame keeps the bounds' origin.
        if let home = self.coverClipHome {
            home.view.bounds = home.bounds
            home.view.center = home.center
            self.coverClipHome = nil
        }
        if let node = self.screenNode {
            node.expansionBackgroundView = nil
            node.backgroundColor = self.backgroundView?.backgroundColor
            self.backgroundView?.removeFromSuperview()
            self.backgroundView = nil
            node.isLentToExpansion = false
            node.applyLayoutHeldDuringExpansion()
        }
    }
}
