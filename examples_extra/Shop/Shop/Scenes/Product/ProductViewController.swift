//
//  ProductViewController.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

class ProductViewController: ASViewController<ASTableNode> {

    // MARK: - Variables
    
    let product: Product
    
    private var tableNode: ASTableNode {
        return node
    }
    
    // MARK: - Object life cycle
    
    init(product: Product) {
        self.product = product
        super.init(node: ASTableNode())
        tableNode.delegate = self
        tableNode.dataSource = self
        tableNode.backgroundColor = UIColor.primaryBackgroundColor()
        tableNode.view.separatorStyle = .none
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTitle()
    }

}

extension ProductViewController: ASTableDataSource, ASTableDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: ASTableView, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
        let node = ProductCellNode(product: self.product)
        return node
    }
    
}

extension ProductViewController {
    func setupTitle() {
        self.title = self.product.title
    }
}
