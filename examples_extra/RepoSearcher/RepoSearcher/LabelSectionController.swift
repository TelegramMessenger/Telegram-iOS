//
//  LabelSectionController.swift
//  RepoSearcher
//
//  Created by Marvin Nazari on 2017-02-18.
//  Copyright © 2017 Marvin Nazari. All rights reserved.
//

import Foundation
import AsyncDisplayKit
import IGListKit

final class LabelSectionController: ListSectionController, ASSectionController {
    var object: String?

    func nodeBlockForItem(at index: Int) -> ASCellNodeBlock {
        let text = object ?? ""
        return {
            let node = ASTextCellNode()
            node.text = text
            return node
        }
    }
    
    override func numberOfItems() -> Int {
        return 1
    }
    
    override func didUpdate(to object: Any) {
        self.object = String(describing: object)
    }
    
    override func didSelectItem(at index: Int) {}
    
    //ASDK Replacement
    override func sizeForItem(at index: Int) -> CGSize {
        return ASIGListSectionControllerMethods.sizeForItem(at: index)
    }
    
    override func cellForItem(at index: Int) -> UICollectionViewCell {
        return ASIGListSectionControllerMethods.cellForItem(at: index, sectionController: self)
    }
}

