//
//  GColor+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 3/11/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

func makeCIColor(color: GColor) -> CIColor {
    #if os(macOS)
    return CIColor(color: color)!
    #else
    return CIColor(color: color)
    #endif
}

extension GColor {
    var redValue: CGFloat{ return makeCIColor(color: self).red }
    var greenValue: CGFloat{ return makeCIColor(color: self).green }
    var blueValue: CGFloat{ return makeCIColor(color: self).blue }
    var alphaValue: CGFloat{ return makeCIColor(color: self).alpha }
    
    convenience init?(hexString: String) {
        let r, g, b, a: CGFloat
        let components = hexString.components(separatedBy: "#")
        if let name = components.first, !name.isEmpty {
            switch name.lowercased() {
                case "red":
                    self.init(hexString: "#ff3b30")
                    return
                case "green":
                    self.init(hexString: "#34c759")
                    return
                case "blue":
                    self.init(hexString: "#007aff")
                    return
                case "golden":
                    self.init(hexString: "#ffcc00")
                    return
                case "yellow":
                    self.init(hexString: "#ffcc00")
                    return
                case "lightgreen":
                    self.init(hexString: "#7ED321")
                    return
                case "lightblue":
                    self.init(hexString: "#5ac8fa")
                    return
                case "seablue":
                    self.init(hexString: "#35afdc")
                    return
                case "orange":
                    self.init(hexString: "#ff9500")
                    return
                case "violet":
                    self.init(hexString: "#af52de")
                    return
                case "emerald":
                    self.init(hexString: "#50e3c2")
                    return
                case "pink":
                    self.init(hexString: "#ff2d55")
                    return
                case "indigo":
                    self.init(hexString: "#5e5ce6")
                    return
                default:
                    break
            }
        }
    
        if let hexColor = components.last {
            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255
                    
                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            } else if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat((hexNumber & 0x0000ff) >> 0) / 255
                    
                    self.init(red: r, green: g, blue: b, alpha: 1.0)
                    return
                }
            }
        }
        return nil
    }

    
}
