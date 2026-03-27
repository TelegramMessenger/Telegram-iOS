import Foundation
import UIKit
import Display
import AppBundle

public struct PresentationResourcesDevices {
    public static let generic = renderSettingsIcon(name: "Item List/Icons/Devices", backgroundColors: [colorGray])
    
    public static let iPhone = renderSettingsIcon(name: "Settings/Devices/iPhone", backgroundColors: [colorBlue])
    public static let iPad = renderSettingsIcon(name: "Settings/Devices/iPad", backgroundColors: [colorBlue])
    public static let macbook = renderSettingsIcon(name: "Settings/Devices/Mac", backgroundColors: [colorBlue])
    public static let iOS = renderAttachAppIcon(iconImage: UIImage(bundleImageName: "Settings/Devices/iOS"))
    
    public static let android = renderSettingsIcon(name: "Settings/Devices/Watch", backgroundColors: [colorGreen])
    
    public static let safari = renderAttachAppIcon(iconImage: UIImage(bundleImageName: "Settings/Devices/Safari"))
    public static let chrome = renderSettingsIcon(name: "Settings/Devices/Chrome", backgroundColors: [colorGreen])
    
    public static let windows = renderSettingsIcon(name: "Settings/Devices/Windows", backgroundColors: [colorBlue])
    public static let linux = renderSettingsIcon(name: "Settings/Devices/Linux", backgroundColors: [colorGray])
    public static let ubuntu = renderSettingsIcon(name: "Settings/Devices/Ubuntu", backgroundColors: [colorOrange])
}
