////
////  IAPPatch.swift
////  NGIAP
////
////  Created by Sergey on 01.10.2020.
////
//
//import Foundation
//import NGData
//import UIKit
//
//public func patchPurchasePremium() -> Void {
//    if #available(iOS 13, *) {
//    } else {
//        // try to patch old devices
//        NGSettings.premium = true
//        //validatePremium(isPremium(), forceValid: true)
//
//
//        var title = "Premium ❌"
//        var message = "Error. Purchase can't be validated "
//
//        if isPremium() {
//            title = "Premium ✅"
//            message = "Please, restart app."
//        }
//
////        var alertAction = UIAlertAction(title: "OK", style: .default) { (action) in }
////        var alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
////        alertController.addAction(alertAction)
////        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
//    }
//}
