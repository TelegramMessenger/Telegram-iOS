//
//  ChartVisibilityView.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/13/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit
import GraphCore
import Display

private enum Constants {
    static let itemHeight: CGFloat = 30
    static let itemSpacing: CGFloat = 8
    static let labelTextApproxInsets: CGFloat = 40
    static let insets = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
}

public func calculateVisiblityHeight(width: CGFloat, items: [ChartVisibilityItem]) -> CGFloat {
    let frames = generateItemsFrames(frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)), items: items)
    guard let lastFrame = frames.last else { return .zero }
    return lastFrame.maxY + Constants.insets.bottom
}

private func generateItemsFrames(frame: CGRect, items: [ChartVisibilityItem]) -> [CGRect] {
    var previousPoint = CGPoint(x: Constants.insets.left, y: Constants.insets.top)
    var frames: [CGRect] = []
    
    for item in items {
        let labelSize = (item.title as NSString).size(withAttributes: [.font: ChartVisibilityItemView.textFont])
        let width = (labelSize.width + Constants.labelTextApproxInsets).rounded(.up)
        if previousPoint.x + width < (frame.width - Constants.insets.left - Constants.insets.right) {
            frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: Constants.itemHeight)))
        } else if previousPoint.x <= Constants.insets.left {
            frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: Constants.itemHeight)))
        } else {
            previousPoint.y += Constants.itemHeight + Constants.itemSpacing
            previousPoint.x = Constants.insets.left
            frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: Constants.itemHeight)))
        }
        previousPoint.x += width + Constants.itemSpacing
    }
    
    return frames
}

class ChartVisibilityView: UIView {
    var items: [ChartVisibilityItem] = [] {
        didSet {
            selectedItems = items.map { _ in true }
            while selectionViews.count > selectedItems.count {
                selectionViews.last?.removeFromSuperview()
                selectionViews.removeLast()
            }
            while selectionViews.count < selectedItems.count {
                let view = ChartVisibilityItemView(frame: bounds)
                addSubview(view)
                selectionViews.append(view)
            }
            
            for (index, item) in items.enumerated() {
                let view = selectionViews[index]
                view.item = item
                view.tapClosure = { [weak self, weak view] in
                    guard let self = self else { return }
                    
                    let selected = !self.selectedItems[index]
                    
                    let selectedItemsCount = self.selectedItems.filter { $0 }.count
                    if selectedItemsCount == 1 && !selected {
                        view?.layer.addShakeAnimation()
                    } else {
                        self.setItemSelected(selected, at: index, animated: true)
                        self.notifyItemSelection()
                    }
                }
                
                view.longTapClosure = { [weak self] in
                    guard let self = self else { return }
                    let hasSelectedItem = self.selectedItems.enumerated().contains(where: { $0.element && $0.offset != index })
                    if hasSelectedItem {
                        for (itemIndex, _) in self.items.enumerated() {
                            self.setItemSelected(itemIndex == index, at: itemIndex, animated: true)
                        }
                    } else {
                        for (itemIndex, _) in self.items.enumerated() {
                            self.setItemSelected(true, at: itemIndex, animated: true)
                        }
                    }
                    self.notifyItemSelection()
                }
            }
        }
    }
    
    private (set) var selectedItems: [Bool] = []
    var isExpanded: Bool = true {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsUpdateConstraints()
        }
    }

    private var selectionViews: [ChartVisibilityItemView] = []
        
    var selectionCallbackClosure: (([Bool]) -> Void)?

    func setItemSelected(_ selected: Bool, at index: Int, animated: Bool) {
        self.selectedItems[index] = selected
        self.selectionViews[index].setChecked(isChecked: selected, animated: animated)
    }
    
    func setItemsSelection(_ selection: [Bool]) {
        assert(selection.count == items.count)
        self.selectedItems = selection
        for (index, selected) in self.selectedItems.enumerated() {
            selectionViews[index].setChecked(isChecked: selected, animated: false)
        }
    }
    
    private func notifyItemSelection() {
        selectionCallbackClosure?(selectedItems)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        updateFrames()
    }
    
    private func updateFrames() {
        for (index, frame) in generateItemsFrames(frame: bounds, items: self.items).enumerated() {
            selectionViews[index].frame = frame
        }
    }
    
    override var intrinsicContentSize: CGSize {
        guard isExpanded else {
            var size = self.bounds.size
            size.height = 0
            return size
        }
        let frames = generateItemsFrames(frame: UIScreen.main.bounds, items: self.items)
        guard let lastFrame = frames.last else { return .zero }
        let size = CGSize(width: frame.width, height: lastFrame.maxY + Constants.insets.bottom)
        return size
    }
}

extension ChartVisibilityView: ChartThemeContainer {
    func apply(theme: ChartTheme, strings: ChartStrings, animated: Bool) {
        UIView.perform(animated: animated) {
            self.backgroundColor = theme.chartBackgroundColor
        }
    }
}
