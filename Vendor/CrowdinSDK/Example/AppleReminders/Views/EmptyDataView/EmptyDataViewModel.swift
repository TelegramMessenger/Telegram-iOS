//
//  EmptyDataViewModel.swift
//  AppleReminders
//
//  Created by Nazar Yavornytskyy on 2/25/21.
//  Copyright © 2021 Josh R. All rights reserved.
//

import Foundation
import UIKit

protocol EmptyDataPresentationModel: AnyObject {
  
  var message: String { get }
}

final class EmptyDataViewModel: EmptyDataPresentationModel {
  
  let message: String
  
  init(message: String) {
    self.message = message
  }
}
