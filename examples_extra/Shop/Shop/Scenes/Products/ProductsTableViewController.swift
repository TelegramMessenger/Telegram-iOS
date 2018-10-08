//
//  ProductsTableViewController.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

class ProductsTableViewController: ASViewController<ASTableNode> {

    // MARK: - Variables
    
    var products: [Product]
    
    private var tableNode: ASTableNode {
        return node
    }
    
    // MARK: - Object life cycle
    
    init(products: [Product]) {
        self.products = products
        super.init(node: ASTableNode())
        tableNode.delegate = self
        tableNode.dataSource = self
        tableNode.backgroundColor = UIColor.white
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let indexPath = self.tableNode.indexPathForSelectedRow {
            self.tableNode.view.deselectRow(at: indexPath, animated: true)
        }
    }

}

extension ProductsTableViewController: ASTableDataSource, ASTableDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.products.count
    }
    
    func tableView(_ tableView: ASTableView, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
        let product = self.products[indexPath.row]
        let node = ProductTableNode(product: product)
        return node
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let product = self.products[indexPath.row]
        let viewController = ProductViewController(product: product)
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension ProductsTableViewController {
    
    func setupTitle() {
        self.title = "Bears"
    }
    
}
