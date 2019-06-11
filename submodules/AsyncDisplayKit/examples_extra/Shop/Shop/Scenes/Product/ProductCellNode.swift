//
//  ProductCellNode.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

class ProductCellNode: ASCellNode {
    
    // MARK: - Variables

    private let productNode: ProductNode
    
    // MARK: - Object life cycle
    
    init(product: Product) {
        self.productNode = ProductNode(product: product)
        super.init()
        self.selectionStyle = .none
        self.addSubnode(self.productNode)
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: UIEdgeInsets.zero, child: self.productNode)
    }
    
}
