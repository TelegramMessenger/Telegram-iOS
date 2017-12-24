//
//  IGListCollectionContext+ASDK.swift
//  RepoSearcher
//
//  Created by Marvin Nazari on 2017-02-18.
//  Copyright © 2017 Marvin Nazari. All rights reserved.
//

import Foundation
import IGListKit
import AsyncDisplayKit

extension ListCollectionContext {
    func nodeForItem(at index: Int, sectionController: ListSectionController) -> ASCellNode? {
        return (cellForItem(at: index, sectionController: sectionController) as? _ASCollectionViewCell)?.node
    }
}
