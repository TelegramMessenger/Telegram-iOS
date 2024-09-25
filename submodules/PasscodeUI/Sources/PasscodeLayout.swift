import Foundation
import UIKit
import Display

struct PasscodeKeyboardLayout {
    var buttonSize: CGFloat
    var horizontalSecond: CGFloat
    var horizontalThird: CGFloat
    var verticalSecond: CGFloat
    var verticalThird: CGFloat
    var verticalFourth: CGFloat
    var size: CGSize
    var topOffset: CGFloat
    var biometricsOffset: CGFloat
    var deleteOffset: CGFloat
    
    fileprivate init(layout: ContainerViewLayout, modalPresentation: Bool) {
        var modalOffset: CGFloat = 0.0
        var modalBiometricsOffset: CGFloat = 0.0
        if modalPresentation {
            modalOffset -= 20.0
            modalBiometricsOffset -= 8.0
        }
        
        switch layout.deviceMetrics {
            case .iPhone4:
                self.buttonSize = 75.0
                self.horizontalSecond = 95.0
                self.horizontalThird = 190.0
                self.verticalSecond = 88.0
                self.verticalThird = 176.0
                self.verticalFourth = 264.0
                self.size = CGSize(width: 265.0, height: 339.0)
                self.topOffset = 122.0
                self.biometricsOffset = 0.0
                self.deleteOffset = 45.0
            case .iPhone5:
                self.buttonSize = 75.0
                self.horizontalSecond = 95.0
                self.horizontalThird = 190.0
                self.verticalSecond = 88.0
                self.verticalThird = 176.0
                self.verticalFourth = 264.0
                self.size = CGSize(width: 265.0, height: 339.0)
                self.topOffset = 155.0
                self.biometricsOffset = 23.0
                self.deleteOffset = 20.0
            case .iPhone6:
                self.buttonSize = 75.0
                self.horizontalSecond = 103.0
                self.horizontalThird = 206.0
                self.verticalSecond = 90.0
                self.verticalThird = 180.0
                self.verticalFourth = 270.0
                self.size = CGSize(width: 281.0, height: 348.0)
                self.topOffset = 221.0
                self.biometricsOffset = 30.0
                self.deleteOffset = 20.0
            case .iPhone6Plus:
                self.buttonSize = 85.0
                self.horizontalSecond = 115.0
                self.horizontalThird = 230.0
                self.verticalSecond = 100.0
                self.verticalThird = 200.0
                self.verticalFourth = 300.0
                self.size = CGSize(width: 315.0, height: 385.0)
                self.topOffset = 226.0
                self.biometricsOffset = 30.0
                self.deleteOffset = 20.0
            case .iPhoneX, .iPhone12Mini, .iPhone12, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone14Pro, .iPhone14ProZoomed, .iPhone14ProMaxZoomed:
                self.buttonSize = 75.0
                self.horizontalSecond = 103.0
                self.horizontalThird = 206.0
                self.verticalSecond = 91.0
                self.verticalThird = 182.0
                self.verticalFourth = 273.0
                self.size = CGSize(width: 281.0, height: 348.0)
                self.topOffset = 294.0
                self.biometricsOffset = 30.0
                self.deleteOffset = 20.0
            case .iPhoneXSMax, .iPhoneXr, .iPhone12ProMax, .iPhone13ProMax, .iPhone14ProMax:
                self.buttonSize = 85.0
                self.horizontalSecond = 115.0
                self.horizontalThird = 230.0
                self.verticalSecond = 100.0
                self.verticalThird = 200.0
                self.verticalFourth = 300.0
                self.size = CGSize(width: 315.0, height: 385.0)
                self.topOffset = 329.0
                self.biometricsOffset = 30.0
                self.deleteOffset = 20.0
            case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen, .iPadMini, .iPadMini6thGen:
                self.buttonSize = 81.0
                self.horizontalSecond = 106.0
                self.horizontalThird = 212.0
                self.verticalSecond = 101.0
                self.verticalThird = 202.0
                self.verticalFourth = 303.0
                self.size = CGSize(width: 293.0, height: 384.0)
                self.topOffset = 120.0 + (layout.size.height - self.size.height - 120.0) / 2.0
                self.biometricsOffset = 30.0
                self.deleteOffset = 80.0
            case .unknown:
                self.buttonSize = 75.0
                self.horizontalSecond = 95.0
                self.horizontalThird = 190.0
                self.verticalSecond = 88.0
                self.verticalThird = 176.0
                self.verticalFourth = 264.0
                self.size = CGSize(width: 265.0, height: 339.0)
                self.topOffset = 120.0 + (layout.size.height - self.size.height - 120.0) / 2.0
                self.biometricsOffset = 30.0
                self.deleteOffset = 20.0
        }
        
        self.topOffset += modalOffset * 2.0
        self.biometricsOffset += modalBiometricsOffset
    }
}

public struct PasscodeLayout {
    var layout: ContainerViewLayout
    var keyboard: PasscodeKeyboardLayout
    var titleOffset: CGFloat
    var subtitleOffset: CGFloat
    var inputFieldOffset: CGFloat
    
    init(layout: ContainerViewLayout, modalPresentation: Bool) {
        self.layout = layout
        
        var modalOffset: CGFloat = 0.0
        if modalPresentation {
            modalOffset -= 20.0
        }
        
        self.keyboard = PasscodeKeyboardLayout(layout: layout, modalPresentation: modalPresentation)
        switch layout.deviceMetrics {
            case .iPhone4:
                self.titleOffset = 30.0
                self.subtitleOffset = -13.0
                self.inputFieldOffset = 70.0
            case .iPhone5:
                self.titleOffset = 50.0
                self.subtitleOffset = -7.0
                self.inputFieldOffset = 90.0
            case .iPhone6:
                self.titleOffset = 100.0
                self.subtitleOffset = -3.0
                self.inputFieldOffset = 144.0
            case .iPhone6Plus:
                self.titleOffset = 112.0
                self.subtitleOffset = -6.0
                self.inputFieldOffset = 156.0
            case .iPhoneX, .iPhone12Mini, .iPhone12, .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone14Pro, .iPhone14ProZoomed, .iPhone14ProMaxZoomed:
                self.titleOffset = 162.0
                self.subtitleOffset = 0.0
                self.inputFieldOffset = 206.0
            case .iPhoneXSMax, .iPhoneXr, .iPhone12ProMax, .iPhone13ProMax, .iPhone14ProMax:
                self.titleOffset = 180.0
                self.subtitleOffset = 0.0
                self.inputFieldOffset = 226.0
            case .iPad, .iPad102Inch, .iPadPro10Inch, .iPadPro11Inch, .iPadPro, .iPadPro3rdGen, .iPadMini, .iPadMini6thGen:
                self.titleOffset = self.keyboard.topOffset - 120.0
                self.subtitleOffset = -2.0
                self.inputFieldOffset = self.keyboard.topOffset - 76.0
            case .unknown:
                self.titleOffset = 100.0
                self.subtitleOffset = 0.0
                self.inputFieldOffset = 140.0
        }
        
        self.titleOffset += modalOffset
        self.subtitleOffset += modalOffset
        self.inputFieldOffset += modalOffset
    }
    
    public init(layout: ContainerViewLayout, titleOffset: CGFloat, subtitleOffset: CGFloat, inputFieldOffset: CGFloat, modalPresentation: Bool) {
        self.layout = layout
        self.keyboard = PasscodeKeyboardLayout(layout: layout, modalPresentation: modalPresentation)
        self.titleOffset = titleOffset
        self.subtitleOffset = subtitleOffset
        self.inputFieldOffset = inputFieldOffset
    }
}
