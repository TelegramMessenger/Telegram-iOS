//
//  ColorMode.swift
//  GraphTest
//
//  Created by Andrew Solovey on 15/03/2019.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import UIKit
import AppBundle

protocol ColorModeContainer {
    func apply(colorMode: ColorMode, animated: Bool)
}

enum ColorMode {
    case day
    case night
}

extension ColorMode {
    var chartTitleColor: UIColor { // Текст с датой на чарте
        switch self {
        case .day: return .black
        case .night: return .white
        }
    }

    var actionButtonColor: UIColor { // Кнопка Zoom Out/ Смена режима день/ночь
        switch self {
        case .day: return UIColor(red: 53/255.0, green: 120/255.0, blue: 246/255.0, alpha: 1.0)
        case .night: return UIColor(red: 84/255.0, green: 164/255.0, blue: 247/255.0, alpha: 1.0)
        }
    }

    var tableBackgroundColor: UIColor {
        switch self {
        case .day: return UIColor(red: 239/255.0, green: 239/255.0, blue: 244/255.0, alpha: 1.0)
        case .night: return UIColor(red: 24/255.0, green: 34/255.0, blue: 45/255.0, alpha: 1.0)
        }
    }
    
    var chartBackgroundColor: UIColor {
        switch self {
        case .day: return UIColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        case .night: return UIColor(red: 34/255.0, green: 47/255.0, blue: 63/255.0, alpha: 1.0)
        }
    }

    var sectionTitleColor: UIColor {
        switch self {
        case .day: return UIColor(red: 109/255.0, green: 109/255.0, blue: 114/255.0, alpha: 1.0)
        case .night: return UIColor(red: 133/255.0, green: 150/255.0, blue: 171/255.0, alpha: 1.0)
        }
    }

    var tableSeparatorColor: UIColor {
        switch self {
        case .day: return UIColor(red: 200/255.0, green: 199/255.0, blue: 204/255.0, alpha: 1.0)
        case .night: return UIColor(red: 18/255.0, green: 26/255.0, blue: 35/255.0, alpha: 1.0)
        }
    }

    var chartLabelsColor: UIColor {
        switch self {
        case .day: return UIColor(red: 37/255.0, green: 37/255.0, blue: 41/255.0, alpha: 0.5)
        case .night: return UIColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.6)
        }
    }

    var chartHelperLinesColor: UIColor {
        switch self {
        case .day: return UIColor(red: 24/255.0, green: 45/255.0, blue: 59/255.0, alpha: 0.1)
        case .night: return UIColor(red: 133/255.0, green: 150/255.0, blue: 171/255.0, alpha: 0.20)
        }
    }

    var chartStrongLinesColor: UIColor {
        switch self {
        case .day: return UIColor(red: 24/255.0, green: 45/255.0, blue: 59/255.0, alpha: 0.35)
        case .night: return UIColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.45)
        }
    }

    var barChartStrongLinesColor: UIColor {
        switch self {
        case .day: return UIColor(red: 37/255.0, green: 37/255.0, blue: 41/255.0, alpha: 0.2)
        case .night: return UIColor(red: 186/255.0, green: 204/255.0, blue: 225/255.0, alpha: 0.45)
        }
    }

    var chartDetailsTextColor: UIColor {
        switch self {
        case .day: return UIColor(red: 109/255.0, green: 109/255.0, blue: 114/255.0, alpha: 1.0)
        case .night: return UIColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        }
    }
    
    var chartDetailsArrowColor: UIColor {
        switch self {
        case .day: return UIColor(red: 197/255.0, green: 199/255.0, blue: 205/255.0, alpha: 1.0)
        case .night: return UIColor(red: 76/255.0, green: 84/255.0, blue: 96/255.0, alpha: 1.0)
        }
    }

    var chartDetailsViewColor: UIColor {
        switch self {
        case .day: return UIColor(red: 245/255.0, green: 245/255.0, blue: 251/255.0, alpha: 1.0)
        case .night: return UIColor(red: 25/255.0, green: 35/255.0, blue: 47/255.0, alpha: 1.0)
        }
    }

    var descriptionChatNameColor: UIColor {
        switch self {
        case .day: return .black
        case .night: return UIColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        }
    }

    var descriptionActionColor: UIColor {
        switch self {
        case .day: return UIColor(red: 1/255.0, green: 125/255.0, blue: 229/255.0, alpha: 1.0)
        case .night: return UIColor(red: 24/255.0, green: 145/255.0, blue: 255/255.0, alpha: 1.0)
        }
    }

    var rangeViewBackgroundColor: UIColor {
        switch self {
        case .day: return UIColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        case .night: return UIColor(red: 34/255.0, green: 47/255.0, blue: 63/255.0, alpha: 1.0)
        }
    }

    var rangeViewFrameColor: UIColor {
        switch self {
        case .day: return UIColor(red: 202/255.0, green: 212/255.0, blue: 222/255.0, alpha: 1.0)
        case .night: return UIColor(red: 53/255.0, green: 70/255.0, blue: 89/255.0, alpha: 1.0)
        }
    }

    var rangeViewTintColor: UIColor {
        switch self {
        case .day: return UIColor(red: 239/255.0, green: 239/255.0, blue: 244/255.0, alpha: 0.5)
        case .night: return UIColor(red: 24/255.0, green: 34/255.0, blue: 45/255.0, alpha: 0.5)
        }
    }

    var rangeViewMarkerColor: UIColor {
        switch self {
        case .day: return UIColor.white
        case .night: return UIColor.white
        }
    }

    var statusBarStyle: UIStatusBarStyle {
        switch self {
        case .day: return .default
        case .night: return .lightContent
        }
    }
    
    var viewTintColor: UIColor {
        switch self {
        case .day: return .black
        case .night: return UIColor(red: 254/255.0, green: 254/255.0, blue: 254/255.0, alpha: 1.0)
        }
    }
    
    var rangeCropImage: UIImage? {
        switch self {
            case .day: return UIImage(bundleImageName: "Chart/selection_frame_light")
            case .night: return UIImage(bundleImageName: "Chart/selection_frame_dark")
        }
    }
}
