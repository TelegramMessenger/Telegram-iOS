//
//  RangeChartView.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//
import UIKit
import GraphCore
import AppBundle

private enum Constants {
    static let cropIndicatorLineWidth: CGFloat = 1
    static let markerSelectionRange: CGFloat = 25
    static let defaultMinimumRangeDistance: CGFloat = 0.1
    static let titntAreaWidth: CGFloat = 10
    static let horizontalContentMargin: CGFloat = 16
    static let cornerRadius: CGFloat = 5
}

class RangeChartView: UIControl {
    private enum Marker {
        case lower
        case upper
        case center
    }
    public var lowerBound: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }
    public var upperBound: CGFloat = 1 {
        didSet {
            setNeedsLayout()
        }
    }
    public var selectionColor: UIColor = .blue
    public var defaultColor: UIColor = .lightGray
    
    public var minimumRangeDistance: CGFloat = Constants.defaultMinimumRangeDistance
    
    private let lowerBoundTintView = UIView()
    private let upperBoundTintView = UIView()
    private let cropFrameView = UIImageView()
    
    private var selectedMarker: Marker?
    private var selectedMarkerHorizontalOffset: CGFloat = 0
    private var selectedMarkerInitialLocation: CGPoint?
    private var isBoundCropHighlighted: Bool = false
    private var isRangePagingEnabled: Bool = false
    
    private var targetTapLocation: CGPoint?

    public let chartView = ChartView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layoutMargins = UIEdgeInsets(top: Constants.cropIndicatorLineWidth,
                                     left: Constants.horizontalContentMargin,
                                     bottom: Constants.cropIndicatorLineWidth,
                                     right: Constants.horizontalContentMargin)
        
        self.setup()
    }
    
    func setup() {
        isMultipleTouchEnabled = false
        
        chartView.chartInsets = .zero
        chartView.backgroundColor = .clear
        
        addSubview(chartView)
        addSubview(lowerBoundTintView)
        addSubview(upperBoundTintView)
        addSubview(cropFrameView)
        cropFrameView.isUserInteractionEnabled = false
        chartView.isUserInteractionEnabled = false
        lowerBoundTintView.isUserInteractionEnabled = false
        upperBoundTintView.isUserInteractionEnabled = false
        
        chartView.layer.cornerRadius = 5
        upperBoundTintView.layer.cornerRadius = 5
        lowerBoundTintView.layer.cornerRadius = 5
        
        chartView.layer.masksToBounds = true
        upperBoundTintView.layer.masksToBounds = true
        lowerBoundTintView.layer.masksToBounds = true
        
        layoutViews()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.setup()
    }
    
    public var rangeDidChangeClosure: ((ClosedRange<CGFloat>) -> Void)?
    public var touchedOutsideClosure: (() -> Void)?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }    
    
    func setRangePaging(enabled: Bool, minimumSize: CGFloat) {
        isRangePagingEnabled = enabled
        minimumRangeDistance = minimumSize
    }
    
    func setRange(_ range: ClosedRange<CGFloat>, animated: Bool) {
        UIView.perform(animated: animated) {
            self.lowerBound = range.lowerBound
            self.upperBound = range.upperBound
            self.layoutIfNeeded()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layoutViews()
    }
    
    override var isEnabled: Bool {
        get {
            return super.isEnabled
        }
        set {
            if newValue == false {
                selectedMarker = nil
            }
            super.isEnabled = newValue
        }
    }
    
    // MARK: - Touches
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        guard let point = touches.first?.location(in: self) else { return }
        
        if abs(locationInView(for: upperBound) - point.x + Constants.markerSelectionRange / 2) < Constants.markerSelectionRange {
            selectedMarker = .upper
            selectedMarkerHorizontalOffset = point.x - locationInView(for: upperBound)
            selectedMarkerInitialLocation = point
            isBoundCropHighlighted = true
        } else if abs(locationInView(for: lowerBound) - point.x - Constants.markerSelectionRange / 2) < Constants.markerSelectionRange {
            selectedMarker = .lower
            selectedMarkerHorizontalOffset = point.x - locationInView(for: lowerBound)
            selectedMarkerInitialLocation = point
            isBoundCropHighlighted = true
        } else if point.x > locationInView(for: lowerBound) && point.x < locationInView(for: upperBound) {
            selectedMarker = .center
            selectedMarkerHorizontalOffset = point.x - locationInView(for: lowerBound)
            selectedMarkerInitialLocation = point
            isBoundCropHighlighted = true
        } else {
            targetTapLocation = point
            selectedMarkerHorizontalOffset = cropFrameView.frame.width / 2.0
            selectedMarker = nil
            selectedMarkerInitialLocation = nil
            return
        }
        
        sendActions(for: .touchDown)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        guard let selectedMarker = selectedMarker else { return }
        guard let point = touches.first?.location(in: self) else { return }
        
        let horizontalPosition = point.x - selectedMarkerHorizontalOffset
        let fraction = fractionFor(offsetX: horizontalPosition)
        updateMarkerOffset(selectedMarker, fraction: fraction)
        
        if let initialPosition = selectedMarkerInitialLocation, abs(initialPosition.x - point.x) > 3.0 {
            self._isTracking = true
        }
        
        targetTapLocation = nil
        
        sendActions(for: .valueChanged)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        if let point = targetTapLocation {
            let horizontalPosition = point.x - selectedMarkerHorizontalOffset
            let fraction = fractionFor(offsetX: horizontalPosition)
            updateMarkerOffset(.center, fraction: fraction)
            
            sendActions(for: .touchUpInside)
            
            self.targetTapLocation = nil
            return
        }
        guard let selectedMarker = selectedMarker else {
            touchedOutsideClosure?()
            return
        }
        guard let point = touches.first?.location(in: self) else { return }
        
        let horizontalPosition = point.x - selectedMarkerHorizontalOffset
        let fraction = fractionFor(offsetX: horizontalPosition)
        updateMarkerOffset(selectedMarker, fraction: fraction)
        
        self.selectedMarker = nil
        self.selectedMarkerInitialLocation = nil
        self.isBoundCropHighlighted = false
        if bounds.contains(point) {
            sendActions(for: .touchUpInside)
        } else {
            sendActions(for: .touchUpOutside)
        }
        rangeDidChangeClosure?(lowerBound...upperBound)
        
        self._isTracking = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.targetTapLocation = nil
        self.selectedMarker = nil
        self.selectedMarkerInitialLocation = nil
        self.isBoundCropHighlighted = false
        self._isTracking = false
        sendActions(for: .touchCancel)
    }
    
    private var _isTracking: Bool = false
    override var isTracking: Bool {
        return self._isTracking
    }
}

private extension RangeChartView {
    var contentFrame: CGRect {
        return CGRect(x: layoutMargins.right,
                      y: layoutMargins.top,
                      width: (bounds.width - layoutMargins.right - layoutMargins.left),
                      height: bounds.height - layoutMargins.top - layoutMargins.bottom)
    }
    
    func locationInView(for fraction: CGFloat) -> CGFloat {
        return contentFrame.minX + contentFrame.width * fraction
    }
    
    func locationInView(for fraction: Double) -> CGFloat {
        return locationInView(for: CGFloat(fraction))
    }
    
    func fractionFor(offsetX: CGFloat) -> CGFloat {
        guard contentFrame.width > 0 else {
            return 0
        }
        
        return crop(0, CGFloat((offsetX - contentFrame.minX ) / contentFrame.width), 1)
    }
    
    private func updateMarkerOffset(_ marker: Marker, fraction: CGFloat, notifyDelegate: Bool = true) {
        let fractionToCount: CGFloat
        if isRangePagingEnabled {
            guard let minValue = stride(from: CGFloat(0.0), through: CGFloat(1.0), by: minimumRangeDistance).min(by: { abs($0 - fraction) < abs($1 - fraction) }) else { return }
            fractionToCount = minValue
        } else {
            fractionToCount = fraction
        }

        switch marker {
        case .lower:
            lowerBound = min(fractionToCount, upperBound - minimumRangeDistance)
        case .upper:
            upperBound = max(fractionToCount, lowerBound + minimumRangeDistance)
        case .center:
            let distance = upperBound - lowerBound
            lowerBound = max(0, min(fractionToCount, 1 - distance))
            upperBound = lowerBound + distance
        }
        if notifyDelegate {
            rangeDidChangeClosure?(lowerBound...upperBound)
        }
        UIView.animate(withDuration: isRangePagingEnabled ? 0.1 : 0) {
            self.layoutIfNeeded()
        }
    }
    
    // MARK: - Layout
    
    func layoutViews() {
        cropFrameView.frame = CGRect(x: locationInView(for: lowerBound),
                                     y: contentFrame.minY - Constants.cropIndicatorLineWidth,
                                     width: locationInView(for: upperBound) - locationInView(for: lowerBound),
                                     height: contentFrame.height + Constants.cropIndicatorLineWidth * 2)
        
        if chartView.frame != contentFrame {
            chartView.frame = contentFrame
        }
        
        lowerBoundTintView.frame = CGRect(x: contentFrame.minX,
                                          y: contentFrame.minY,
                                          width: max(0, locationInView(for: lowerBound) - contentFrame.minX + Constants.titntAreaWidth),
                                          height: contentFrame.height)
        
        upperBoundTintView.frame = CGRect(x: locationInView(for: upperBound) - Constants.titntAreaWidth,
                                          y: contentFrame.minY,
                                          width: max(0, contentFrame.maxX - locationInView(for: upperBound) + Constants.titntAreaWidth),
                                          height: contentFrame.height)
    }
}

extension RangeChartView: ChartThemeContainer {
    func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool) {
        let closure = {
            self.lowerBoundTintView.backgroundColor = theme.rangeViewTintColor
            self.upperBoundTintView.backgroundColor = theme.rangeViewTintColor
        }
        
        self.cropFrameView.setImage(theme.rangeCropImage, animated: animated)
        
        if animated {
            UIView.animate(withDuration: .defaultDuration, animations: closure)
        } else {
            closure()
        }
    }
}
