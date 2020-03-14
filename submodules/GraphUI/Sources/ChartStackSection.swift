//
//  ChartStackSection.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit
import GraphCore

private enum Constants {
    static let chartViewHeightFraction: CGFloat = 0.55
}

private class LeftAlignedIconButton: UIButton {
    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        let titleRect = super.titleRect(forContentRect: contentRect)
        let imageSize = currentImage?.size ?? .zero
        let availableWidth = contentRect.width - imageEdgeInsets.right - imageSize.width - titleRect.width
        return titleRect.offsetBy(dx: round(availableWidth / 2), dy: 0)
    }
}

class ChartStackSection: UIView, ChartThemeContainer {
    var chartView: ChartView
    var rangeView: RangeChartView
    var visibilityView: ChartVisibilityView
    var sectionContainerView: UIView
    var separators: [UIView] = []
    
    var titleLabel: UILabel!
    var backButton: UIButton!
    
    var controller: BaseChartController?
    var theme: ChartTheme?
    
    init() {
        sectionContainerView = UIView()
        chartView = ChartView()
        rangeView = RangeChartView()
        visibilityView = ChartVisibilityView()
        titleLabel = UILabel()
        backButton = LeftAlignedIconButton()
        
        super.init(frame: CGRect())
        
        self.addSubview(sectionContainerView)
        sectionContainerView.addSubview(chartView)
        sectionContainerView.addSubview(rangeView)
        sectionContainerView.addSubview(visibilityView)
        sectionContainerView.addSubview(titleLabel)
        sectionContainerView.addSubview(backButton)
        
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.textAlignment = .center
        visibilityView.clipsToBounds = true
        backButton.isExclusiveTouch = true
        
        backButton.addTarget(self, action: #selector(self.didTapBackButton), for: .touchUpInside)
        backButton.setTitle("Zoom Out", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        backButton.setTitleColor(UIColor(rgb: 0x007ee5), for: .normal)
        backButton.setImage(UIImage(bundleImageName: "Chart/arrow_left"), for: .normal)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 3.0)
        backButton.imageView?.tintColor = UIColor(rgb: 0x007ee5)
        
        backButton.setVisible(false, animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        visibilityView.clipsToBounds = true
        backButton.isExclusiveTouch = true
        
        backButton.setVisible(false, animated: false)
    }
    
    func apply(theme: ChartTheme, animated: Bool) {
        self.theme = theme
        
        UIView.perform(animated: animated && self.isVisibleInWindow) {
            self.backgroundColor = theme.tableBackgroundColor
            
            self.sectionContainerView.backgroundColor = theme.chartBackgroundColor
            self.rangeView.backgroundColor = theme.chartBackgroundColor
            self.visibilityView.backgroundColor = theme.chartBackgroundColor
            
            self.backButton.tintColor = theme.actionButtonColor
            self.backButton.setTitleColor(theme.actionButtonColor, for: .normal)
            
            for separator in self.separators {
                separator.backgroundColor = theme.tableSeparatorColor
            }
        }
        
        if rangeView.isVisibleInWindow || chartView.isVisibleInWindow {
            chartView.loadDetailsViewIfNeeded()
            chartView.apply(theme: theme, animated: animated && chartView.isVisibleInWindow)
            controller?.apply(theme: theme, animated: animated)
            rangeView.apply(theme: theme, animated: animated && rangeView.isVisibleInWindow)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval.random(in: 0...0.1)) {
                self.chartView.loadDetailsViewIfNeeded()
                
                self.controller?.apply(theme: theme, animated: false)
                self.chartView.apply(theme: theme, animated: false)
                self.rangeView.apply(theme: theme, animated: false)
            }
        }
        
        self.titleLabel.setTextColor(theme.chartTitleColor, animated: animated && titleLabel.isVisibleInWindow)
    }
    
    @objc private func didTapBackButton() {
        self.controller?.didTapZoomOut()
    }
    
    func setBackButtonVisible(_ visible: Bool, animated: Bool) {
        backButton.setVisible(visible, animated: animated)
        layoutIfNeeded(animated: animated)
    }
    
    func updateToolViews(animated: Bool) {
        guard let controller = self.controller else {
            return
        }
        
        rangeView.setRange(controller.currentChartHorizontalRangeFraction, animated: animated)
        rangeView.setRangePaging(enabled: controller.isChartRangePagingEnabled,
                                 minimumSize: controller.minimumSelectedChartRange)
        visibilityView.setVisible(controller.drawChartVisibity, animated: animated)
        if controller.drawChartVisibity {
            visibilityView.isExpanded = true
            visibilityView.items = controller.actualChartsCollection.chartValues.map { value in
                return ChartVisibilityItem(title: value.name, color: value.color)
            }
            visibilityView.setItemsSelection(controller.actualChartVisibility)
            visibilityView.setNeedsLayout()
            visibilityView.layoutIfNeeded()
        } else {
            visibilityView.isExpanded = false
        }
        superview?.superview?.layoutIfNeeded(animated: animated)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = self.bounds
        self.titleLabel.frame = CGRect(origin: CGPoint(x: backButton.alpha > 0.0 ? 36.0 : 0.0, y: 5.0), size: CGSize(width: bounds.width, height: 28.0))
        self.sectionContainerView.frame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: 750.0))
        self.chartView.frame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: 250.0))
        self.rangeView.frame = CGRect(origin: CGPoint(x: 0.0, y: 250.0), size: CGSize(width: bounds.width, height: 42.0))
        self.visibilityView.frame = CGRect(origin: CGPoint(x: 0.0, y: 308.0), size: CGSize(width: bounds.width, height: 350.0))
        self.backButton.frame = CGRect(x: 0.0, y: 0.0, width: 96.0, height: 38.0)
    }
    
    func setup(controller: BaseChartController, title: String) {
        self.controller = controller
        if let theme = self.theme {
            controller.apply(theme: theme, animated: false)
        }
        
        self.chartView.renderers = controller.mainChartRenderers
        self.chartView.userDidSelectCoordinateClosure = { [unowned self] point in
            self.controller?.chartInteractionDidBegin(point: point)
        }
        self.chartView.userDidDeselectCoordinateClosure = { [unowned self] in
            self.controller?.chartInteractionDidEnd()
        }
        controller.cartViewBounds = { [unowned self] in
            return self.chartView.bounds
        }
        controller.chartFrame = { [unowned self] in
            return self.chartView.chartFrame
        }
        controller.setDetailsViewModel = { [unowned self] viewModel, animated in
            self.chartView.setDetailsViewModel(viewModel: viewModel, animated: animated)
        }
        controller.setDetailsChartVisibleClosure = { [unowned self] visible, animated in
            self.chartView.setDetailsChartVisible(visible, animated: animated)
        }
        controller.setDetailsViewPositionClosure = { [unowned self] position in
            self.chartView.detailsViewPosition = position
        }
        controller.setChartTitleClosure = { [unowned self] title, animated in
            self.titleLabel.setText(title, animated: animated)
        }
        controller.setBackButtonVisibilityClosure = { [unowned self] visible, animated in
            self.setNeedsLayout()
            self.setBackButtonVisible(visible, animated: animated)
        }
        controller.refreshChartToolsClosure = { [unowned self] animated in
            self.updateToolViews(animated: animated)
        }
        
        self.rangeView.chartView.renderers = controller.navigationRenderers
        self.rangeView.rangeDidChangeClosure = { range in
            controller.updateChartRange(range)
        }
        self.rangeView.touchedOutsideClosure = {
            controller.cancelChartInteraction()
        }
        controller.chartRangeUpdatedClosure = { [unowned self] (range, animated) in
            self.rangeView.setRange(range, animated: animated)
        }
        controller.chartRangePagingClosure = { [unowned self] (isEnabled, pageSize) in
            self.rangeView.setRangePaging(enabled: isEnabled, minimumSize: pageSize)
        }

        self.visibilityView.selectionCallbackClosure = { [unowned self] visibility in
            self.controller?.updateChartsVisibility(visibility: visibility, animated: true)
        }
        
        controller.initializeChart()
        updateToolViews(animated: false)
        
        rangeView.setRange(0.8...1.0, animated: false)
        controller.updateChartRange(0.8...1.0, animated: false)
    }
}
