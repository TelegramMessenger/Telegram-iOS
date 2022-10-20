//
//  CustomColors.swift
//  AppleReminders
//
//  Created by Josh R on 2/7/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import UIKit

struct CustomColors {
    static let defaultListColor = "systemBlue"
    
    static let systemColors = [
        "systemRed",
        "systemOrange",
        "systemYellow",
        "systemGreen",
        "lightBlue",
        "systemBlue",
        "systemIndigo",
        "systemPink",
        "systemPurple",
        "systemBrownColor",
        "systemGray",
        "peach"
    ]
    
    static func generateRandomSystemColor() -> String {
        let colorCount = CustomColors.systemColors.count - 1
        let randomIndex = Int.random(in: 0..<colorCount)
        
        return CustomColors.systemColors[randomIndex]
    }
    
    static let systemColorsDict = [
        "systemRed": UIColor.systemRed,
        "systemOrange": UIColor.systemOrange,
        "systemYellow": UIColor.systemYellow,
        "systemGreen": UIColor.systemGreen,
        "lightBlue": #colorLiteral(red: 0.4653951526, green: 0.7633241415, blue: 0.9971610904, alpha: 1),
        "systemBlue": UIColor.systemBlue,
        "systemIndigo": UIColor.systemIndigo,
        "systemPink": UIColor.systemPink,
        "systemPurple": UIColor.systemPurple,
        "systemBrownColor": #colorLiteral(red: 0.7471296191, green: 0.6293600202, blue: 0.4745137691, alpha: 1),
        "systemGray": UIColor.systemGray,
        "peach": #colorLiteral(red: 0.7316172123, green: 0.5660820007, blue: 0.5433551669, alpha: 1)
    ]
}

struct Icons {
    enum IconType {
        case system
        case custom
    }
    
    let iconName: String
    let iconType: IconType
}

struct IconsData {
    static let icons = [
        Icons(iconName: "list.bullet", iconType: .system),
        Icons(iconName: "bookmark.fill", iconType: .system),
        Icons(iconName: "mappin", iconType: .system),
        Icons(iconName: "gift.fill", iconType: .system),
        Icons(iconName: "birthday cake celebration", iconType: .custom),
        Icons(iconName: "graduate college high school senior degree", iconType: .custom),
        Icons(iconName: "backpack", iconType: .custom),
        Icons(iconName: "pencil supplies office writing letter", iconType: .custom),
        Icons(iconName: "wallet money pay bank billfold", iconType: .custom),
        Icons(iconName: "creditcard.fill", iconType: .system),
        Icons(iconName: "money dollar sign cash", iconType: .custom),
        Icons(iconName: "exercise weight lifting", iconType: .custom),
        Icons(iconName: "running exercise", iconType: .custom),
        Icons(iconName: "dinner supper lunch silverware eat snack food", iconType: .custom),
        Icons(iconName: "espresso-cup", iconType: .custom),
        Icons(iconName: "pills medicine", iconType: .custom),
        Icons(iconName: "stethoscope doctor medical", iconType: .custom),
        Icons(iconName: "couch home relax furniture", iconType: .custom),
        Icons(iconName: "house.fill", iconType: .system),
        Icons(iconName: "desktopcomputer", iconType: .system),
        Icons(iconName: "music.note", iconType: .system),
        Icons(iconName: "computer desktop pc", iconType: .custom),
        Icons(iconName: "gamecontroller.fill", iconType: .system),
        Icons(iconName: "leaf.arrow.circlepath", iconType: .system),
        Icons(iconName: "food wrap", iconType: .custom),
        Icons(iconName: "mother mom pregnant baby", iconType: .custom),
        Icons(iconName: "partners", iconType: .custom),
        Icons(iconName: "familywithkids", iconType: .custom),
        Icons(iconName: "pet dog paw print animal", iconType: .custom),
        Icons(iconName: "sheep lamb farm animal", iconType: .custom),
        Icons(iconName: "pet fish", iconType: .custom),
        Icons(iconName: "cart.fill", iconType: .system),
        Icons(iconName: "bag.fill", iconType: .system),
        Icons(iconName: "basketball", iconType: .custom),
        Icons(iconName: "hat baseball cap clothing", iconType: .custom),
        Icons(iconName: "sports bowling alley pin", iconType: .custom),
        Icons(iconName: "sports football pigskin", iconType: .custom),
        Icons(iconName: "tennisball", iconType: .custom),
        Icons(iconName: "tram.fill", iconType: .system),
        Icons(iconName: "airplane", iconType: .system),
        Icons(iconName: "boat water sail", iconType: .custom),
        Icons(iconName: "car.fill", iconType: .system),
        Icons(iconName: "umbrella.fill", iconType: .system),
        Icons(iconName: "moon.fill", iconType: .system),
        Icons(iconName: "sun.min.fill", iconType: .system),
        Icons(iconName: "umbrella rain weather", iconType: .custom),
        Icons(iconName: "snow", iconType: .system),
        Icons(iconName: "flame.fill", iconType: .system),
        Icons(iconName: "toolbox", iconType: .custom),
        Icons(iconName: "wrench.fill", iconType: .system),
        Icons(iconName: "scissors", iconType: .system),
        Icons(iconName: "protractor", iconType: .custom),
        Icons(iconName: "chevron.left.slash.chevron.right", iconType: .system),
        Icons(iconName: "square.fill", iconType: .system),
        Icons(iconName: "circle.fill", iconType: .system),
        Icons(iconName: "triangle.fill", iconType: .system),
        Icons(iconName: "jewelry ring wedding married diamond", iconType: .custom),
        Icons(iconName: "heart.fill", iconType: .system),
        Icons(iconName: "star.fill", iconType: .system)
    ]
}

struct Conversions {
    static func convertRadiansToDegrees(_ degrees: Double) -> CGFloat {
        let conversion = 180.0/3.14
        return CGFloat(degrees / conversion)
    }
}


struct RealmHelper {
    //Used to delete todos with no name.
    static func deleteEmptyRealmReminder() {
        let realm = MyRealm.getConfig()
        guard let emptyReminders = realm?.objects(Reminder.self).filter("name == %d", "") else { return }
        
        if emptyReminders.count > 0 {
            try! realm?.write {
                for reminder in emptyReminders {
                    realm?.delete(reminder)
                }
            }
        }
    }
}
