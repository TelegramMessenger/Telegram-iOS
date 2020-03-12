//
//  colorMode.swift
//  GraphTest
//
//  Created by Andrew Solovey on 15/03/2019.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

#if os(iOS)
public typealias GColor = UIColor
#else
public typealias GColor = NSColor
#endif

#if os(iOS)
typealias NSEdgeInsets = UIEdgeInsets
#endif

public protocol GColorModeContainer {
    func apply(colorMode: GColorMode, animated: Bool)
}

public enum GColorMode {
    case day
    case night
}

extension GColorMode {
    public var chartTitleColor: GColor { // Текст с датой на чарте
        switch self {
        case .day: return .black
        case .night: return .white
        }
    }

    public var actionButtonColor: GColor { // Кнопка Zoom Out/ Смена режима день/ночь
        switch self {
        case .day: return GColor(red: 53/255.0, green: 120/255.0, blue: 246/255.0, alpha: 1.0)
        case .night: return GColor(red: 84/255.0, green: 164/255.0, blue: 247/255.0, alpha: 1.0)
        }
    }

    public var tableBackgroundColor: GColor {
        switch self {
        case .day: return GColor(red: 239/255.0, green: 239/255.0, blue: 244/255.0, alpha: 1.0)
        case .night: return GColor(red: 24/255.0, green: 34/255.0, blue: 45/255.0, alpha: 1.0)
        }
    }
    
    public var chartBackgroundColor: GColor {
        switch self {
        case .day: return GColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        case .night: return GColor(red: 34/255.0, green: 47/255.0, blue: 63/255.0, alpha: 1.0)
        }
    }

    public var sectionTitleColor: GColor {
        switch self {
        case .day: return GColor(red: 109/255.0, green: 109/255.0, blue: 114/255.0, alpha: 1.0)
        case .night: return GColor(red: 133/255.0, green: 150/255.0, blue: 171/255.0, alpha: 1.0)
        }
    }

    public var tableSeparatorColor: GColor {
        switch self {
        case .day: return GColor(red: 200/255.0, green: 199/255.0, blue: 204/255.0, alpha: 1.0)
        case .night: return GColor(red: 18/255.0, green: 26/255.0, blue: 35/255.0, alpha: 1.0)
        }
    }

    public var chartLabelsColor: GColor {
        switch self {
        case .day: return GColor(red: 37/255.0, green: 37/255.0, blue: 41/255.0, alpha: 0.5)
        case .night: return GColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.6)
        }
    }

    public var chartHelperLinesColor: GColor {
        switch self {
        case .day: return GColor(red: 24/255.0, green: 45/255.0, blue: 59/255.0, alpha: 0.1)
        case .night: return GColor(red: 133/255.0, green: 150/255.0, blue: 171/255.0, alpha: 0.20)
        }
    }

    public var chartStrongLinesColor: GColor {
        switch self {
        case .day: return GColor(red: 24/255.0, green: 45/255.0, blue: 59/255.0, alpha: 0.35)
        case .night: return GColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.45)
        }
    }

    public var barChartStrongLinesColor: GColor {
        switch self {
        case .day: return GColor(red: 37/255.0, green: 37/255.0, blue: 41/255.0, alpha: 0.2)
        case .night: return GColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.45)
        }
    }

    public var chartDetailsTextColor: GColor {
        switch self {
        case .day: return GColor(red: 109/255.0, green: 109/255.0, blue: 114/255.0, alpha: 1.0)
        case .night: return GColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        }
    }
    
    public var chartDetailsArrowColor: GColor {
        switch self {
        case .day: return GColor(red: 197/255.0, green: 199/255.0, blue: 205/255.0, alpha: 1.0)
        case .night: return GColor(red: 76/255.0, green: 84/255.0, blue: 96/255.0, alpha: 1.0)
        }
    }

    public var chartDetailsViewColor: GColor {
        switch self {
        case .day: return GColor(red: 245/255.0, green: 245/255.0, blue: 251/255.0, alpha: 1.0)
        case .night: return GColor(red: 25/255.0, green: 35/255.0, blue: 47/255.0, alpha: 1.0)
        }
    }

    public var descriptionChatNameColor: GColor {
        switch self {
        case .day: return .black
        case .night: return GColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        }
    }

    public var descriptionActionColor: GColor {
        switch self {
        case .day: return GColor(red: 1/255.0, green: 125/255.0, blue: 229/255.0, alpha: 1.0)
        case .night: return GColor(red: 24/255.0, green: 145/255.0, blue: 255/255.0, alpha: 1.0)
        }
    }

    public var rangeViewBackgroundColor: GColor {
        switch self {
        case .day: return GColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        case .night: return GColor(red: 34/255.0, green: 47/255.0, blue: 63/255.0, alpha: 1.0)
        }
    }

    public var rangeViewFrameColor: GColor {
        switch self {
        case .day: return GColor(red: 202/255.0, green: 212/255.0, blue: 222/255.0, alpha: 1.0)
        case .night: return GColor(red: 53/255.0, green: 70/255.0, blue: 89/255.0, alpha: 1.0)
        }
    }

    public var rangeViewTintColor: GColor {
        switch self {
        case .day: return GColor(red: 239/255.0, green: 239/255.0, blue: 244/255.0, alpha: 0.5)
        case .night: return GColor(red: 24/255.0, green: 34/255.0, blue: 45/255.0, alpha: 0.5)
        }
    }

    public var rangeViewMarkerColor: GColor {
        switch self {
        case .day: return GColor.white
        case .night: return GColor.white
        }
    }

    
    public var viewTintColor: GColor {
        switch self {
        case .day: return .black
        case .night: return GColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        }
    }
    
    public var rangeCropImage: GImage? {
        switch self {
        case .day:
            let image = GImage(named: "selection_frame_light")
            #if os(macOS)
            image?.resizingMode = .stretch
            image?.capInsets = NSEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
            #endif
            return image
        case .night:
            let image = GImage(named: "selection_frame_dark")
            #if os(macOS)
            image?.resizingMode = .stretch
            image?.capInsets = NSEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
            #endif
            return image
        }
    }
}
