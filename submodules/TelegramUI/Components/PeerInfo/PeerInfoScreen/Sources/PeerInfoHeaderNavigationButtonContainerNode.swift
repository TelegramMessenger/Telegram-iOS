import Foundation
import UIKit
import AsyncDisplayKit
import ContextUI
import TelegramPresentationData
import Display
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import SideColumnLayout

enum PeerInfoHeaderNavigationButtonKey {
    case back
    case edit
    case done
    case cancel
    case select
    case selectionDone
    case search
    case searchWithTags
    case standaloneSearch
    case editPhoto
    case editVideo
    case more
    case sort
    case qrCode
    case moreSearchSort
    case postStory
}

struct PeerInfoHeaderNavigationButtonSpec: Hashable {
    let key: PeerInfoHeaderNavigationButtonKey
    let isForExpandedView: Bool
}

/// iPhone Duo: whether a navigation button goes into the side column. Icon buttons do; text buttons stay
/// in the row (Apple: text-only items stay horizontal).
func peerInfoNavigationButtonIsIcon(_ key: PeerInfoHeaderNavigationButtonKey) -> Bool {
    switch key {
    case .back, .qrCode, .search, .searchWithTags, .standaloneSearch, .more, .sort, .moreSearchSort, .postStory:
        return true
    case .edit, .done, .cancel, .select, .selectionDone, .editPhoto, .editVideo:
        return false
    }
}

/// iPhone Duo: each button set's side column (spec 2026-10-06, profile side column).
struct PeerInfoNavigationColumnPlan {
    /// The normal set's column; nil when the set has neither back nor an icon button.
    var normal: SideColumnItemsLayout?
    /// The set shown while the shared-media tabs fill the screen.
    var expanded: SideColumnItemsLayout?
    /// Each icon button's cell in its set's capsule, in the capsule's coordinates.
    var cells: [PeerInfoHeaderNavigationButtonSpec: CGRect]
}

/// The column for the row's buttons in a region `regionLength` long: back in the circle, the left group's
/// icon buttons, then the right group's, in the capsule. Profile buttons never overflow: nil when a set
/// does not fit, and every button then stays in the row.
func peerInfoNavigationColumnPlan(leftButtons: [PeerInfoHeaderNavigationButtonSpec], rightButtons: [PeerInfoHeaderNavigationButtonSpec], regionLength: CGFloat) -> PeerInfoNavigationColumnPlan? {
    var plan = PeerInfoNavigationColumnPlan(normal: nil, expanded: nil, cells: [:])
    for isForExpandedView in [false, true] {
        let hasBack = leftButtons.contains(where: { $0.key == .back && $0.isForExpandedView == isForExpandedView })
        let items = (leftButtons + rightButtons).filter { spec in
            return spec.isForExpandedView == isForExpandedView && spec.key != .back && peerInfoNavigationButtonIsIcon(spec.key)
        }
        if items.isEmpty && !hasBack {
            continue
        }
        guard let layout = sideColumnItemsLayout(regionLength: regionLength, hasBack: hasBack, priorities: [Int?](repeating: nil, count: items.count)) else {
            return nil
        }
        for (index, item) in items.enumerated() {
            plan.cells[item] = layout.cellFrames[index]
        }
        if isForExpandedView {
            plan.expanded = layout
        } else {
            plan.normal = layout
        }
    }
    return plan
}

final class PeerInfoHeaderNavigationButtonContainerNode: SparseNode {
    private var presentationData: PresentationData?
    private var hidesLeftRowCapsule = false
    private var hidesRightRowCapsule = false
    
    private let backgroundContainer: GlassBackgroundContainerView
    let leftButtonsBackground: GlassContextExtractableContainer
    let rightButtonsBackground: GlassContextExtractableContainer
    private let leftButtonsContainer: UIView
    private let rightButtonsContainer: UIView
    
    private(set) var leftButtonNodes: [PeerInfoHeaderNavigationButtonSpec: PeerInfoHeaderNavigationButton] = [:]
    private(set) var rightButtonNodes: [PeerInfoHeaderNavigationButtonSpec: PeerInfoHeaderNavigationButton] = [:]
    
    private var currentLeftButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    private var currentRightButtons: [PeerInfoHeaderNavigationButtonSpec] = []
    
    private var backgroundContentColor: UIColor = .clear
    private var isOverColoredContents: Bool = false
    private var contentsColor: UIColor = .white
    
    /// iPhone Duo: the side column's button containers (in the row's style: clipped, round), and its glass,
    /// created the first time a layout has a strip.
    private let columnBackContainer: UIView
    private let columnButtonsContainer: UIView
    private var column: SideColumnViews?
    private var appliedSideColumn: SideColumnRegion?

    private final class SideColumnViews {
        let container: GlassBackgroundContainerView
        let backBackground: GlassContextExtractableContainer
        let buttonsBackground: GlassContextExtractableContainer

        init(backContainer: UIView, buttonsContainer: UIView) {
            self.container = GlassBackgroundContainerView()
            self.backBackground = GlassContextExtractableContainer()
            self.buttonsBackground = GlassContextExtractableContainer()
            self.container.contentView.addSubview(self.backBackground)
            self.container.contentView.addSubview(self.buttonsBackground)
            self.backBackground.contentView.addSubview(backContainer)
            self.buttonsBackground.contentView.addSubview(buttonsContainer)
        }
    }

    /// The right buttons laid out in the row: on iPhone Duo the side column takes the icon buttons.
    var rowRightButtonCount: Int {
        return self.rightButtonNodes.values.filter { $0.view.superview === self.rightButtonsContainer }.count
    }
    
    var performAction: ((PeerInfoHeaderNavigationButtonKey, ContextReferenceContentNode?, ContextGesture?) -> Void)?
    
    override init() {
        self.backgroundContainer = GlassBackgroundContainerView()
        self.leftButtonsBackground = GlassContextExtractableContainer()
        self.rightButtonsBackground = GlassContextExtractableContainer()
        
        self.leftButtonsContainer = UIView()
        self.leftButtonsContainer.clipsToBounds = true
        self.rightButtonsContainer = UIView()
        self.rightButtonsContainer.clipsToBounds = true
        self.columnBackContainer = UIView()
        self.columnBackContainer.clipsToBounds = true
        self.columnButtonsContainer = UIView()
        self.columnButtonsContainer.clipsToBounds = true
        
        super.init()
        
        self.view.addSubview(self.backgroundContainer)
        self.backgroundContainer.contentView.addSubview(self.leftButtonsBackground)
        self.backgroundContainer.contentView.addSubview(self.rightButtonsBackground)
        
        self.leftButtonsBackground.contentView.addSubview(self.leftButtonsContainer)
        self.rightButtonsBackground.contentView.addSubview(self.rightButtonsContainer)
    }
    
    func updateContentsColor(backgroundContentColor: UIColor, contentsColor: UIColor, isOverColoredContents: Bool, transition: ContainedViewLayoutTransition) {
        self.backgroundContentColor = backgroundContentColor
        self.isOverColoredContents = isOverColoredContents
        self.contentsColor = contentsColor
        
        guard let presentationData = self.presentationData else {
            return
        }
        
        let normalButtonContentsColor: UIColor = self.isOverColoredContents ? .white :  presentationData.theme.chat.inputPanel.panelControlColor
        let expandedButtonContentsColor: UIColor = presentationData.theme.chat.inputPanel.panelControlColor
        
        for (spec, button) in self.leftButtonNodes {
            button.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: transition)
        }
        
        for spec in self.currentRightButtons {
            guard let button = self.rightButtonNodes[spec] else {
                continue
            }
            button.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: transition)
        }
        for (spec, button) in self.rightButtonNodes {
            if !self.currentRightButtons.contains(where: { $0 == spec }) {
                button.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: transition)
            }
        }
        
        self.updateBackgroundColors(transition: ComponentTransition(transition))
    }
    
    /// The column container and frame for a button of `size`, or nil when it is laid out in the row.
    private func columnPlacement(spec: PeerInfoHeaderNavigationButtonSpec, size: CGSize, plan: PeerInfoNavigationColumnPlan?) -> (container: UIView, frame: CGRect)? {
        guard let plan else {
            return nil
        }
        let cell: CGRect
        let container: UIView
        if spec.key == .back {
            guard let backFrame = (spec.isForExpandedView ? plan.expanded : plan.normal)?.backFrame else {
                return nil
            }
            cell = CGRect(origin: CGPoint(), size: backFrame.size)
            container = self.columnBackContainer
        } else {
            guard let capsuleCell = plan.cells[spec] else {
                return nil
            }
            cell = capsuleCell
            container = self.columnButtonsContainer
        }
        return (container, CGRect(origin: CGPoint(x: cell.minX + floor((cell.width - size.width) / 2.0), y: cell.minY + floor((cell.height - size.height) / 2.0)), size: size))
    }

    private func isInColumn(_ spec: PeerInfoHeaderNavigationButtonSpec, plan: PeerInfoNavigationColumnPlan?) -> Bool {
        return self.columnPlacement(spec: spec, size: CGSize(), plan: plan) != nil
    }

    /// Puts `buttonNode` into its column or row container and returns its frame, and whether it moved
    /// between containers (then it is placed without animation, so it never flies across the screen).
    /// Row buttons advance that set's row width exactly as before.
    private func place(buttonNode: PeerInfoHeaderNavigationButton, spec: PeerInfoHeaderNavigationButtonSpec, size: CGSize, rowContainer: UIView, plan: PeerInfoNavigationColumnPlan?, normalRowWidth: inout CGFloat, expandedRowWidth: inout CGFloat) -> (frame: CGRect, moved: Bool) {
        let container: UIView
        let frame: CGRect
        if let placement = self.columnPlacement(spec: spec, size: size, plan: plan) {
            container = placement.container
            frame = placement.frame
        } else {
            container = rowContainer
            frame = CGRect(origin: CGPoint(x: spec.isForExpandedView ? expandedRowWidth : normalRowWidth, y: 0.0), size: size)
            if spec.isForExpandedView {
                expandedRowWidth += size.width
            } else {
                normalRowWidth += size.width
            }
        }
        var moved = false
        if buttonNode.view.superview !== container {
            moved = buttonNode.view.superview != nil
            container.addSubview(buttonNode.view)
        }
        return (frame, moved)
    }
    
    func update(size: CGSize, presentationData: PresentationData, leftButtons: [PeerInfoHeaderNavigationButtonSpec], rightButtons: [PeerInfoHeaderNavigationButtonSpec], expandFraction: CGFloat, shouldAnimateIn: Bool, sideColumn: SideColumnRegion? = nil, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
        
        let buttonHeight: CGFloat = 44.0
        
        let sideInset: CGFloat = 16.0
        
        // iPhone Duo: back and the icon buttons go into the side column, text buttons stay in the row.
        let columnPlan: PeerInfoNavigationColumnPlan? = sideColumn.flatMap { sideColumn in
            return peerInfoNavigationColumnPlan(leftButtons: leftButtons, rightButtons: rightButtons, regionLength: sideColumn.frame.height)
        }
        
        var normalLeftButtonsWidth: CGFloat = 0.0
        var expandedLeftButtonsWidth: CGFloat = 0.0
        
        let maxBlur: CGFloat = 5.0
        
        let normalButtonContentsColor: UIColor = self.isOverColoredContents ? .white :  presentationData.theme.chat.inputPanel.panelControlColor
        let expandedButtonContentsColor: UIColor = presentationData.theme.chat.inputPanel.panelControlColor
        
        if self.currentLeftButtons != leftButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentLeftButtons = leftButtons
            
            for spec in leftButtons.reversed() {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                if let current = self.leftButtonNodes[spec] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.leftButtonNodes[spec] = buttonNode
                    buttonNode.action = { [weak self] _, gesture in
                        guard let strongSelf = self, let buttonNode = strongSelf.leftButtonNodes[spec] else {
                            return
                        }
                        strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                    }
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: buttonHeight)
                let (buttonFrame, moved) = self.place(buttonNode: buttonNode, spec: spec, size: buttonSize, rowContainer: self.leftButtonsContainer, plan: columnPlan, normalRowWidth: &normalLeftButtonsWidth, expandedRowWidth: &expandedLeftButtonsWidth)
                let alphaFactor: CGFloat
                if case .back = spec.key {
                    alphaFactor = 1.0
                } else {
                    alphaFactor = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                }
                
                if wasAdded {
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    ComponentTransition.immediate.setBlur(layer: buttonNode.layer, radius: maxBlur)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: 0.0)
                    buttonNode.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: .immediate)
                } else {
                    if moved {
                        buttonNode.frame = buttonFrame
                    } else {
                        transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    }
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonSpec] = []
            for (spec, _) in self.leftButtonNodes {
                if !leftButtons.contains(where: { $0 == spec }) {
                    removeKeys.append(spec)
                }
            }
            for spec in removeKeys {
                if let buttonNode = self.leftButtonNodes.removeValue(forKey: spec) {
                    buttonNode.view.removeFromSuperview()
                }
            }
        } else {
            for spec in leftButtons.reversed() {
                if let buttonNode = self.leftButtonNodes[spec] {
                    let buttonSize = buttonNode.bounds.size
                    let (buttonFrame, moved) = self.place(buttonNode: buttonNode, spec: spec, size: buttonSize, rowContainer: self.leftButtonsContainer, plan: columnPlan, normalRowWidth: &normalLeftButtonsWidth, expandedRowWidth: &expandedLeftButtonsWidth)
                    if moved {
                        buttonNode.frame = buttonFrame
                    } else {
                        transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    }
                    let alphaFactor: CGFloat
                    if case .back = spec.key {
                        alphaFactor = 1.0
                    } else {
                        alphaFactor = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    }
                    
                    var buttonTransition = transition
                    if case let .animated(duration, curve) = buttonTransition, alphaFactor == 0.0 {
                        buttonTransition = .animated(duration: duration * 0.25, curve: curve)
                    }
                    buttonTransition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(buttonTransition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
        }
        
        var normalRightButtonsWidth: CGFloat = 0.0
        var expandedRightButtonsWidth: CGFloat = 0.0
        
        if self.currentRightButtons != rightButtons || presentationData.strings !== self.presentationData?.strings {
            self.currentRightButtons = rightButtons
            
            for spec in rightButtons {
                let buttonNode: PeerInfoHeaderNavigationButton
                var wasAdded = false
                
                var key = spec.key
                if key == .more || key == .search || key == .sort {
                    key = .moreSearchSort
                }
                
                if let current = self.rightButtonNodes[spec] {
                    buttonNode = current
                } else {
                    wasAdded = true
                    buttonNode = PeerInfoHeaderNavigationButton()
                    self.rightButtonNodes[spec] = buttonNode
                }
                buttonNode.action = { [weak self] _, gesture in
                    guard let strongSelf = self, let buttonNode = strongSelf.rightButtonNodes[spec] else {
                        return
                    }
                    strongSelf.performAction?(spec.key, buttonNode.contextSourceNode, gesture)
                }
                let buttonSize = buttonNode.update(key: spec.key, presentationData: presentationData, height: buttonHeight)
                let (buttonFrame, moved) = self.place(buttonNode: buttonNode, spec: spec, size: buttonSize, rowContainer: self.rightButtonsContainer, plan: columnPlan, normalRowWidth: &normalRightButtonsWidth, expandedRowWidth: &expandedRightButtonsWidth)
                let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                if wasAdded {
                    buttonNode.updateContentsColor(contentsColor: spec.isForExpandedView ? expandedButtonContentsColor : normalButtonContentsColor, transition: .immediate)
                    
                    if shouldAnimateIn {
                        if key == .moreSearchSort || key == .searchWithTags || key == .standaloneSearch {
                            buttonNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                        }
                    }
                    
                    buttonNode.frame = buttonFrame
                    buttonNode.alpha = 0.0
                    ComponentTransition.immediate.setBlur(layer: buttonNode.layer, radius: maxBlur)
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                } else {
                    if moved {
                        buttonNode.frame = buttonFrame
                    } else {
                        transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    }
                    transition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
            var removeKeys: [PeerInfoHeaderNavigationButtonSpec] = []
            for (spec, _) in self.rightButtonNodes {
                if spec.key == .moreSearchSort {
                    if !rightButtons.contains(where: { $0.key == .more || $0.key == .search || $0.key == .sort }) {
                        removeKeys.append(spec)
                    }
                } else if !rightButtons.contains(where: { $0 == spec }) {
                    removeKeys.append(spec)
                }
            }
            for spec in removeKeys {
                if let buttonNode = self.rightButtonNodes.removeValue(forKey: spec) {
                    if spec.key == .moreSearchSort || spec.key == .searchWithTags || spec.key == .standaloneSearch {
                        buttonNode.layer.animateAlpha(from: buttonNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonNode] _ in
                            buttonNode?.view.removeFromSuperview()
                        })
                        buttonNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false)
                    } else {
                        buttonNode.view.removeFromSuperview()
                    }
                }
            }
        } else {
            for spec in rightButtons {
                if let buttonNode = self.rightButtonNodes[spec] {
                    let buttonSize = buttonNode.bounds.size
                    let (buttonFrame, moved) = self.place(buttonNode: buttonNode, spec: spec, size: buttonSize, rowContainer: self.rightButtonsContainer, plan: columnPlan, normalRowWidth: &normalRightButtonsWidth, expandedRowWidth: &expandedRightButtonsWidth)
                    if moved {
                        buttonNode.frame = buttonFrame
                    } else {
                        transition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
                    }
                    let alphaFactor: CGFloat = spec.isForExpandedView ? expandFraction : (1.0 - expandFraction)
                    
                    var buttonTransition = transition
                    if case let .animated(duration, curve) = buttonTransition, alphaFactor == 0.0 {
                        buttonTransition = .animated(duration: duration * 0.25, curve: curve)
                    }
                    buttonTransition.updateAlpha(node: buttonNode, alpha: alphaFactor * alphaFactor)
                    ComponentTransition(transition).setBlur(layer: buttonNode.layer, radius: (1.0 - alphaFactor * alphaFactor) * maxBlur)
                }
            }
        }
        self.presentationData = presentationData
        
        let buttonsY: CGFloat = floor((size.height - buttonHeight) * 0.5) + 2.0
        
        let leftButtonsWidth = (1.0 - expandFraction) * normalLeftButtonsWidth + expandFraction * expandedLeftButtonsWidth
        let rightButtonsWidth = (1.0 - expandFraction) * normalRightButtonsWidth + expandFraction * expandedRightButtonsWidth
        self.hidesLeftRowCapsule = columnPlan != nil && leftButtonsWidth == 0.0
        self.hidesRightRowCapsule = columnPlan != nil && rightButtonsWidth == 0.0
        self.leftButtonsBackground.isUserInteractionEnabled = !self.hidesLeftRowCapsule
        self.rightButtonsBackground.isUserInteractionEnabled = !self.hidesRightRowCapsule
        
        var leftButtonsFrame = CGRect(origin: CGPoint(x: sideInset, y: buttonsY), size: CGSize(width: max(44.0, leftButtonsWidth), height: buttonHeight))
        if leftButtonsWidth < 44.0 {
            let leftFraction = leftButtonsWidth / 44.0
            leftButtonsFrame.origin.x = floorToScreenPixels(leftFraction * sideInset + (1.0 - leftFraction) * (-44.0))
        }
        var rightButtonsFrame = CGRect(origin: CGPoint(x: size.width - sideInset - rightButtonsWidth, y: buttonsY), size: CGSize(width: max(44.0, rightButtonsWidth), height: buttonHeight))
        if rightButtonsWidth < 44.0 {
            let rightFraction = rightButtonsWidth / 44.0
            rightButtonsFrame.origin.x = floorToScreenPixels(rightFraction * (size.width - sideInset - 44.0) + (1.0 - rightFraction) * size.width)
        }
        
        transition.updateFrame(view: self.leftButtonsBackground, frame: leftButtonsFrame)
        transition.updateFrame(view: self.leftButtonsContainer, frame: CGRect(origin: CGPoint(), size: leftButtonsFrame.size))
        self.leftButtonsContainer.layer.cornerRadius = leftButtonsFrame.height * 0.5
        
        transition.updateFrame(view: self.rightButtonsBackground, frame: rightButtonsFrame)
        transition.updateFrame(view: self.rightButtonsContainer, frame: CGRect(origin: CGPoint(), size: rightButtonsFrame.size))
        self.rightButtonsContainer.layer.cornerRadius = rightButtonsFrame.height * 0.5
        
        // Normal and expanded buttons crossfade with expandFraction; the back button
        // exists in both sets but is drawn as one. Buttons in the side column do not count.
        func visibleButtonCount(_ buttons: [PeerInfoHeaderNavigationButtonSpec]) -> Int {
            return Set(buttons.filter({ !self.isInColumn($0, plan: columnPlan) && ($0.key == .back || ($0.isForExpandedView ? expandFraction > 0.0 : expandFraction < 1.0)) }).map(\.key)).count
        }
        self.leftButtonsBackground.morphsIntoContextMenu = visibleButtonCount(leftButtons) == 1
        self.rightButtonsBackground.morphsIntoContextMenu = visibleButtonCount(rightButtons) == 1
        
        // A plan with neither back nor an icon in either set (editing: Cancel and Done are text and stay in the
        // row) hides the column as a whole. Its shapes cannot be hidden one by one: the glass ignores their
        // layers' alpha, so an emptied capsule stayed on screen.
        let columnHasShapes = columnPlan.map { $0.normal != nil || $0.expanded != nil } ?? false
        self.updateSideColumn(sideColumn: columnHasShapes ? sideColumn : nil, plan: columnHasShapes ? columnPlan : nil, buttons: leftButtons + rightButtons, expandFraction: expandFraction, transition: transition)
        
        self.updateBackgroundColors(transition: ComponentTransition(transition))
    }

    
    /// iPhone Duo: lays out the side column's glass at the region (in this node's coordinates) from the two
    /// sets' column layouts, crossfaded by `expandFraction` as the row's buttons are. It lives inside this
    /// node, so it hides with it (search, custom navigation content) and takes touches through it.
    private func updateSideColumn(sideColumn: SideColumnRegion?, plan: PeerInfoNavigationColumnPlan?, buttons: [PeerInfoHeaderNavigationButtonSpec], expandFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        let change = sideColumnPlacementChange(from: self.appliedSideColumn, to: sideColumn)
        self.appliedSideColumn = sideColumn
        guard let sideColumn, let plan else {
            if let column = self.column {
                transition.updateAlpha(layer: column.container.layer, alpha: 0.0)
                column.container.isUserInteractionEnabled = false
            }
            return
        }
        let column: SideColumnViews
        if let current = self.column {
            column = current
        } else {
            column = SideColumnViews(backContainer: self.columnBackContainer, buttonsContainer: self.columnButtonsContainer)
            column.container.alpha = 0.0
            self.column = column
            self.view.addSubview(column.container)
        }
        
        var frameTransition = transition
        switch change {
        case .appear:
            frameTransition = .immediate
        case .move:
            // A rotation or the strip switching sides: fade instead of flying across the header.
            frameTransition = .immediate
            if case let .animated(duration, _) = transition, column.container.alpha > 0.0, let snapshotView = column.container.snapshotView(afterScreenUpdates: false) {
                snapshotView.isUserInteractionEnabled = false
                snapshotView.frame = column.container.frame
                self.view.insertSubview(snapshotView, aboveSubview: column.container)
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                column.container.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5, delay: duration * 0.5)
            }
        case .none, .disappear, .animate:
            break
        }
        frameTransition.updateFrame(view: column.container, frame: sideColumn.frame)
        
        // The glass is laid out without animating its size when it first gets one or the column appears or moves.
        let backTransition: ContainedViewLayoutTransition
        if case .immediate = frameTransition {
            backTransition = .immediate
        } else if column.backBackground.bounds.isEmpty {
            backTransition = .immediate
        } else {
            backTransition = frameTransition
        }
        let buttonsTransition: ContainedViewLayoutTransition
        if case .immediate = frameTransition {
            buttonsTransition = .immediate
        } else if column.buttonsBackground.bounds.isEmpty {
            buttonsTransition = .immediate
        } else {
            buttonsTransition = frameTransition
        }
        let tint = self.glassTint()
        if let (_, isDark) = tint {
            column.container.update(size: sideColumn.frame.size, isDark: isDark, transition: ComponentTransition(frameTransition))
        }
        
        let normalWeight: CGFloat = 1.0 - expandFraction
        let expandedWeight: CGFloat = expandFraction
        
        if let backFrame = plan.normal?.backFrame ?? plan.expanded?.backFrame {
            backTransition.updateFrame(view: column.backBackground, frame: backFrame)
            backTransition.updateFrame(view: self.columnBackContainer, frame: CGRect(origin: CGPoint(), size: backFrame.size))
            if let (tintColor, isDark) = tint {
                column.backBackground.update(size: backFrame.size, cornerRadius: backFrame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, transition: ComponentTransition(backTransition))
            }
            self.columnBackContainer.layer.cornerRadius = backFrame.height * 0.5
        }
        let backAlpha: CGFloat = (plan.normal?.backFrame != nil ? normalWeight : 0.0) + (plan.expanded?.backFrame != nil ? expandedWeight : 0.0)
        transition.updateAlpha(layer: column.backBackground.layer, alpha: backAlpha)
        
        var capsuleFrame: CGRect?
        var capsuleAlpha: CGFloat = 0.0
        switch (plan.normal?.capsuleFrame, plan.expanded?.capsuleFrame) {
        case let (normal?, expanded?):
            capsuleFrame = CGRect(x: normal.minX, y: normal.minY * normalWeight + expanded.minY * expandedWeight, width: normal.width, height: normal.height * normalWeight + expanded.height * expandedWeight)
            capsuleAlpha = 1.0
        case let (normal?, nil):
            capsuleFrame = normal
            capsuleAlpha = normalWeight
        case let (nil, expanded?):
            capsuleFrame = expanded
            capsuleAlpha = expandedWeight
        case (nil, nil):
            break
        }
        if let capsuleFrame {
            buttonsTransition.updateFrame(view: column.buttonsBackground, frame: capsuleFrame)
            buttonsTransition.updateFrame(view: self.columnButtonsContainer, frame: CGRect(origin: CGPoint(), size: capsuleFrame.size))
            if let (tintColor, isDark) = tint {
                column.buttonsBackground.update(size: capsuleFrame.size, cornerRadius: capsuleFrame.width * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, transition: ComponentTransition(buttonsTransition))
            }
            self.columnButtonsContainer.layer.cornerRadius = capsuleFrame.width * 0.5
        }
        transition.updateAlpha(layer: column.buttonsBackground.layer, alpha: capsuleAlpha)
        
        let visibleColumnKeys = Set(buttons.filter { spec in
            guard plan.cells[spec] != nil else {
                return false
            }
            return spec.isForExpandedView ? expandFraction > 0.0 : expandFraction < 1.0
        }.map(\.key))
        column.buttonsBackground.morphsIntoContextMenu = visibleColumnKeys.count == 1
        
        transition.updateAlpha(layer: column.container.layer, alpha: 1.0)
        column.container.isUserInteractionEnabled = true
    }
    
    private func glassTint() -> (tintColor: GlassBackgroundView.TintColor, isDark: Bool)? {
        guard let presentationData = self.presentationData else {
            return nil
        }
        if self.isOverColoredContents {
            return (.init(kind: .custom(style: .default, color: self.backgroundContentColor)), presentationData.theme.overallDarkAppearance)
        } else {
            return (.init(kind: .panel), presentationData.theme.overallDarkAppearance)
        }
    }
    
    /// The glass a context menu opened from `view` should morph out of: the row's right or left capsule,
    /// or the side column's capsule or back circle; nil when `view` is in none of them.
    func contextMenuSourceView(containing view: UIView) -> UIView? {
        if view.isDescendant(of: self.rightButtonsBackground) {
            return self.rightButtonsBackground
        }
        if view.isDescendant(of: self.leftButtonsBackground) {
            return self.leftButtonsBackground
        }
        if let column = self.column {
            if view.isDescendant(of: column.buttonsBackground) {
                return column.buttonsBackground
            }
            if view.isDescendant(of: column.backBackground) {
                return column.backBackground
            }
        }
        return nil
    }
    
    private func updateBackgroundColors(transition: ComponentTransition) {
        let leftButtonsSize = self.leftButtonsBackground.bounds.size
        let rightButtonsSize = self.rightButtonsBackground.bounds.size
        
        guard let (tintColor, tintIsDark) = self.glassTint() else {
            return
        }
        
        self.backgroundContainer.update(size: self.backgroundContainer.bounds.size, isDark: tintIsDark, transition: transition)
        
        self.rightButtonsBackground.update(size: rightButtonsSize, cornerRadius: rightButtonsSize.height * 0.5, isDark: tintIsDark, tintColor: tintColor, isInteractive: true, isVisible: !self.hidesRightRowCapsule, transition: transition)
        self.leftButtonsBackground.update(size: leftButtonsSize, cornerRadius: leftButtonsSize.height * 0.5, isDark: tintIsDark, tintColor: tintColor, isInteractive: true, isVisible: !self.hidesLeftRowCapsule, transition: transition)
        if let column = self.column {
            column.container.update(size: column.container.bounds.size, isDark: tintIsDark, transition: transition)
            let backSize = column.backBackground.bounds.size
            column.backBackground.update(size: backSize, cornerRadius: backSize.height * 0.5, isDark: tintIsDark, tintColor: tintColor, isInteractive: true, transition: transition)
            let buttonsSize = column.buttonsBackground.bounds.size
            column.buttonsBackground.update(size: buttonsSize, cornerRadius: buttonsSize.width * 0.5, isDark: tintIsDark, tintColor: tintColor, isInteractive: true, transition: transition)
        }
    }
}
