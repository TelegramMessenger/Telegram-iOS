//
//  ChartVisibilityItem.swift
//  GraphCore
//
//  Created by Mikhail Filimonov on 26.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

public struct ChartVisibilityItem {
    public var title: String
    public var color: GColor
    public init(title: String, color: GColor) {
        self.title = title
        self.color = color
    }
    public static func generateItemsFrames(for chartWidth: CGFloat, items: [ChartVisibilityItem]) -> [CGRect] {
        
        if items.count == 1 {
            return []
        }
        
        var previousPoint = CGPoint(x: ChatVisibilityItemConstants.insets.left, y: ChatVisibilityItemConstants.insets.top)
        var frames: [CGRect] = []
        for item in items {
            let labelSize = textSize(with: item.title, font: ChatVisibilityItemConstants.textFont)
            let width = (labelSize.width + ChatVisibilityItemConstants.labelTextApproxInsets).rounded(.up)
            if previousPoint.x + width < (chartWidth - ChatVisibilityItemConstants.insets.left - ChatVisibilityItemConstants.insets.right) {
                frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: ChatVisibilityItemConstants.itemHeight)))
            } else if previousPoint.x <= ChatVisibilityItemConstants.insets.left {
                frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: ChatVisibilityItemConstants.itemHeight)))
            } else {
                previousPoint.y += ChatVisibilityItemConstants.itemHeight + ChatVisibilityItemConstants.itemSpacing
                previousPoint.x = ChatVisibilityItemConstants.insets.left
                frames.append(CGRect(origin: previousPoint, size: CGSize(width: width, height: ChatVisibilityItemConstants.itemHeight)))
            }
            previousPoint.x += width + ChatVisibilityItemConstants.itemSpacing
        }

        return frames
    }
    
}
enum ChatVisibilityItemConstants {
    static let itemHeight: CGFloat = 30
    static let itemSpacing: CGFloat = 8
    static let labelTextApproxInsets: CGFloat = 40
    static let insets = NSEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
    static let textFont = NSFont.systemFont(ofSize: 14, weight: .medium)
}

public struct ChartDetailsViewModel {
    public struct Value {
        public let prefix: String?
        public let title: String
        public let value: String
        public let color: GColor
        public let visible: Bool
        public init(prefix: String?,
        title: String,
        value: String,
        color: GColor,
        visible: Bool) {
            self.prefix = prefix
            self.title = title
            self.value = value
            self.color = color
            self.visible = visible
        }
    }
    
    public internal(set) var title: String
    public internal(set) var showArrow: Bool
    public internal(set) var showPrefixes: Bool
    public internal(set) var isLoading: Bool
    public internal(set) var values: [Value]
    public internal(set) var totalValue: Value?
    public internal(set) var tapAction: (() -> Void)?
    public internal(set) var hideAction: (() -> Void)?
    
    static let blank = ChartDetailsViewModel(title: "", showArrow: false, showPrefixes: false, isLoading: false, values: [], totalValue: nil, tapAction: nil, hideAction: nil)
    public init(title: String,
    showArrow: Bool,
    showPrefixes: Bool,
    isLoading: Bool,
    values: [Value],
    totalValue: Value?,
    tapAction: (() -> Void)?,
    hideAction: (() -> Void)?) {
        self.title = title
        self.showArrow = showArrow
        self.showPrefixes = showPrefixes
        self.isLoading = isLoading
        self.values = values
        self.totalValue = totalValue
        self.tapAction = tapAction
        self.hideAction = hideAction
    }
    
}

