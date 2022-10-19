//
//  ReminderTypeDatasource.swift
//  AppleReminders
//
//  Created by Josh R on 7/15/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import Foundation
import UIKit

class ReminderTypeDatasource: NSObject, UICollectionViewDataSource {
    
    let types = ReminderType.allCases
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TypeCVCell.reuseIdentifier, for: indexPath) as! TypeCVCell
        
        let type = types[indexPath.row]
        cell.desiredType = type
        
        return cell
    }
}
