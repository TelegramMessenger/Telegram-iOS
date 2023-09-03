import UIKit
import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import AppBundle
import LocalizedPeerData
import ContextUI
import TelegramBaseController

@objc(Application) class Application: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
        if let str = viewType(of: event) {
//            print(str)
        }
    }
}

private func viewType(of event: UIEvent) -> Any? {
    var result = "\n" + "COMPONENT" + "\n"
    var superview = event.allTouches?.compactMap{ $0.view }.first
    for i in 1...5 {
        guard let s = superview?.superview else {
            return result
        }
        superview = s
        let space = String(repeating: "==", count: i)
        let coder = String(describing: s)
        let nodeCoder = findNodeText(coder)
        result = (result) + (space + (nodeCoder ?? "") + "\(s.frame)" + "\n")
    }
    return result
}

private func findNodeText(_ str: String) -> String? {
    let range = NSRange(location: 0, length: str.count)
    let regex1 = try? NSRegularExpression(pattern: "node[A-Za-z0-9=<>;:. ]*>")
    let regex2 = try? NSRegularExpression(pattern: "<[A-Za-z0-9=<>;:. ]*:")
    
    if let match = regex1?.firstMatch(in: str, range: range),
       let r = Range(match.range, in: str) {
        return String(String(str[r]).dropFirst(7))
    }
    if let match = regex2?.firstMatch(in: str, range: range),
       let r = Range(match.range, in: str) {
        return String(String(str[r]).dropFirst(7))
    }
    return nil
}
