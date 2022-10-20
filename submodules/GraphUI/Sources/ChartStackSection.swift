//
//  ChartStackSection.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit
import GraphCore
import Display

private enum Constants {
    static let chartViewHeightFraction: CGFloat = 0.55
}

private class LeftAlignedIconButton: UIButton {
    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        var titleRect = super.titleRect(forContentRect: contentRect)
        let imageSize = currentImage?.size ?? .zero
        titleRect.origin.x = imageSize.width
        return titleRect
    }
    
    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        var imageRect = super.imageRect(forContentRect: contentRect)
        imageRect.origin.x = 0.0
        return imageRect
    }
}

class ChartStackSection: UIView, ChartThemeContainer {
    var chartView: ChartView
    var rangeView: RangeChartView
    var visibilityView: ChartVisibilityView
    var sectionContainerView: UIView
    
    var titleLabel: UILabel!
    var backButton: UIButton!
    
    var controller: BaseChartController?
    var theme: ChartTheme?
    var strings: ChartStrings?
    
    var displayRange: Bool = true
    
    let hapticFeedback = HapticFeedback()
    
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
        backButton.setTitleColor(UIColor(rgb: 0x007aff), for: .normal)
        backButton.setImage(UIImage(bundleImageName: "Chart/arrow_left"), for: .normal)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 3.0)
        backButton.imageView?.tintColor = UIColor(rgb: 0x007aff)
        backButton.adjustsImageWhenHighlighted = false
        
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
    
    public func resetDetailsView() {
        controller?.cancelChartInteraction()
    }
    
    func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool) {
        self.theme = theme
        self.strings = strings
        
        self.backButton.setTitle(strings.zoomOut, for: .normal)
        
        UIView.perform(animated: animated && self.isVisibleInWindow) {            
            self.sectionContainerView.backgroundColor = theme.chartBackgroundColor
            self.rangeView.backgroundColor = theme.chartBackgroundColor
            self.visibilityView.backgroundColor = theme.chartBackgroundColor
            
            self.backButton.tintColor = theme.actionButtonColor
            self.backButton.setTitleColor(theme.actionButtonColor, for: .normal)
            self.backButton.imageView?.tintColor = theme.actionButtonColor
        }
        
        if rangeView.isVisibleInWindow || chartView.isVisibleInWindow {
            chartView.loadDetailsViewIfNeeded()
            chartView.apply(theme: theme, strings: strings, animated: animated && chartView.isVisibleInWindow)
            controller?.apply(theme: theme, strings: strings, animated: animated)
            rangeView.apply(theme: theme, strings: strings, animated: animated && rangeView.isVisibleInWindow)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval.random(in: 0...0.1)) {
                self.chartView.loadDetailsViewIfNeeded()
                
                self.controller?.apply(theme: theme, strings: strings, animated: false)
                self.chartView.apply(theme: theme, strings: strings, animated: false)
                self.rangeView.apply(theme: theme, strings: strings, animated: false)
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
        self.chartView.frame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: 310.0))
        
        self.rangeView.isHidden = !self.displayRange
        
        self.rangeView.frame = CGRect(origin: CGPoint(x: 0.0, y: 310.0), size: CGSize(width: bounds.width, height: 42.0))
        self.visibilityView.frame = CGRect(origin: CGPoint(x: 0.0, y: self.displayRange ? 368.0 : 326.0), size: CGSize(width: bounds.width, height: 350.0))
        self.backButton.frame = CGRect(x: 8.0, y: 0.0, width: 96.0, height: 38.0)
        
        self.chartView.setNeedsDisplay()
    }
    
    func setup(controller: BaseChartController, displayRange: Bool = true) {
        self.controller = controller
        self.displayRange = displayRange
        
        if let theme = self.theme, let strings = self.strings {
            controller.apply(theme: theme, strings: strings, animated: false)
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
        controller.setDetailsViewModel = { [unowned self] viewModel, animated, feedback in
            self.chartView.setDetailsViewModel(viewModel: viewModel, animated: animated)
            if feedback {
                self.hapticFeedback.tap()
            }
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
        
        let range: ClosedRange<CGFloat> = displayRange ? 0.8 ... 1.0 : 0.0 ... 1.0
        rangeView.setRange(range, animated: false)
        controller.updateChartRange(range, animated: false)
        
        self.setNeedsLayout()
    }
}
