//
//  IGListCollectionContext+ASDK.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
import IGListKit
import AsyncDisplayKit

extension ListCollectionContext {
    func nodeForItem(at index: Int, sectionController: ListSectionController) -> ASCellNode? {
        return (cellForItem(at: index, sectionController: sectionController) as? _ASCollectionViewCell)?.node
    }
}
