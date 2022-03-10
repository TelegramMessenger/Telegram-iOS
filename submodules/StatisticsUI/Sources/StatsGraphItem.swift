import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import GraphCore
import GraphUI
import ActivityIndicator

class StatsGraphItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let graph: StatsGraph
    let type: ChartType
    let getDetailsData: ((Date, @escaping (String?) -> Void) -> Void)?
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    
    init(presentationData: ItemListPresentationData, graph: StatsGraph, type: ChartType, getDetailsData: ((Date, @escaping (String?) -> Void) -> Void)? = nil, sectionId: ItemListSectionId, style: ItemListStyle) {
        self.presentationData = presentationData
        self.graph = graph
        self.type = type
        self.getDetailsData = getDetailsData
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = StatsGraphItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? StatsGraphItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = false
}

class StatsGraphItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    private let chartContainerNode: ASDisplayNode
    
    let chartNode: ChartNode
    private let activityIndicator: ActivityIndicator
    
    private var item: StatsGraphItem?
    private var visibilityHeight: CGFloat?
        
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.chartContainerNode = ASDisplayNode()
        self.chartContainerNode.clipsToBounds = true
        self.chartContainerNode.isUserInteractionEnabled = true
        
        self.chartNode = ChartNode()
        self.activityIndicator = ActivityIndicator(type: ActivityIndicatorType.custom(.black, 16.0, 2.0, false))
        self.activityIndicator.isHidden = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.chartContainerNode.addSubnode(self.chartNode)
        self.chartContainerNode.addSubnode(self.activityIndicator)
    }
    
    override func didLoad() {
        super.didLoad()
    
        self.view.interactiveTransitionGestureRecognizerTest = { point -> Bool in
            return point.x > 30.0 || (point.y > 310.0 && point.y < 355.0)
        }
    }
    
    func resetInteraction() {
        self.chartNode.resetInteraction()
    }
    
    func asyncLayout() -> (_ item: StatsGraphItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let currentVisibilityHeight = self.visibilityHeight
        
        return { item, params, neighbors in
            let leftInset = params.leftInset
            let rightInset: CGFloat = params.rightInset
            var updatedTheme: PresentationTheme?
            var updatedGraph: StatsGraph?
            var updatedController: BaseChartController?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            if currentItem?.graph != item.graph {
                updatedGraph = item.graph
                if case let .Loaded(_, data) = updatedGraph {
                    updatedController = createChartController(data, type: item.type, getDetailsData: { [weak self] date, completion in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.getDetailsData?(date, completion)
                        }
                    })
                }
            }
            
            var contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    contentSize = CGSize(width: params.width, height: 361.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    contentSize = CGSize(width: params.width, height: 361.0)
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
                
            var visibilityHeight = currentVisibilityHeight
            if let updatedController = updatedController {
                var height: CGFloat = 0.0
                var items: [ChartVisibilityItem] = []
                for item in updatedController.actualChartsCollection.chartValues {
                    items.append(ChartVisibilityItem(title: item.name, color: .black))
                }
                if items.count > 1 {
                    height = calculateVisiblityHeight(width: params.width - params.leftInset - params.rightInset, items: items)
                }
                if item.type == .hourlyStep {
                    height -= 82.0
                }
                visibilityHeight = height
            }
            if let visibilityHeight = visibilityHeight {
                contentSize.height += visibilityHeight
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.visibilityHeight = visibilityHeight
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                    }
                                                            
                    switch item.style {
                    case .plain:
                        if strongSelf.backgroundNode.supernode != nil {
                            strongSelf.backgroundNode.removeFromSupernode()
                        }
                        if strongSelf.topStripeNode.supernode != nil {
                            strongSelf.topStripeNode.removeFromSupernode()
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                        }
                        if strongSelf.maskNode.supernode != nil {
                            strongSelf.maskNode.removeFromSupernode()
                        }
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    case .blocks:
                        if strongSelf.backgroundNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                        }
                        if strongSelf.chartContainerNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.chartContainerNode, at: 1)
                        }
                        if strongSelf.topStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.topStripeNode, at: 2)
                        }
                        if strongSelf.bottomStripeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 3)
                        }
                        if strongSelf.maskNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.maskNode, at: 4)
                        }
                        let hasCorners = itemListHasRoundedBlockLayout(params)
                        var hasTopCorners = false
                        var hasBottomCorners = false
                        switch neighbors.top {
                            case .sameSection(false):
                                strongSelf.topStripeNode.isHidden = true
                            default:
                                hasTopCorners = true
                                strongSelf.topStripeNode.isHidden = hasCorners
                        }
                        let bottomStripeInset: CGFloat
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.chartContainerNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: layout.size.width - leftInset - rightInset, height: contentSize.height))
                        strongSelf.chartNode.frame = CGRect(origin: CGPoint(x: 0.0, y: item.type == .hourlyStep ? -40.0 : 0.0), size: CGSize(width: layout.size.width - leftInset - rightInset, height: 750.0))
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                        strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                        
                        strongSelf.activityIndicator.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - 16.0) / 2.0), y: floor((layout.size.height - 16.0) / 2.0)), size: CGSize(width: 16.0, height: 16.0))
                    }
                    
                    strongSelf.activityIndicator.type = .custom(item.presentationData.theme.list.itemSecondaryTextColor, 16.0, 2.0, false)
                    
                    if let updatedTheme = updatedTheme {
                        strongSelf.chartNode.setup(theme: ChartTheme(presentationTheme: updatedTheme), strings: ChartStrings(zoomOut: item.presentationData.strings.Stats_ZoomOut, total: item.presentationData.strings.Stats_Total))
                    }
                    
                    if let updatedGraph = updatedGraph {
                        if case .Loaded = updatedGraph, let updatedController = updatedController {
                            strongSelf.chartNode.setup(controller: updatedController)
                            strongSelf.activityIndicator.isHidden = true
                            strongSelf.chartNode.isHidden = false
                        } else if case .OnDemand = updatedGraph {
                            strongSelf.activityIndicator.isHidden = false
                            strongSelf.chartNode.isHidden = true
                        }
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

