//
//  ProductsCollectionViewController.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

class ProductsCollectionViewController: ASViewController<ASCollectionNode> {

    // MARK: - Variables
    
    var products: [Product]
    
    private var collectionNode: ASCollectionNode {
        return node
    }
    
    // MARK: - Object life cycle
    
    init(products: [Product]) {
        self.products = products
        super.init(node: ASCollectionNode(collectionViewLayout: ProductsLayout()))
        collectionNode.delegate = self
        collectionNode.dataSource = self
        collectionNode.backgroundColor = UIColor.primaryBackgroundColor()
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

extension ProductsCollectionViewController: ASCollectionDataSource, ASCollectionDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.products.count
    }
    
    func collectionView(_ collectionView: ASCollectionView, nodeForItemAt indexPath: IndexPath) -> ASCellNode {
        let product = self.products[indexPath.row]
        return ProductCollectionNode(product: product)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let product = self.products[indexPath.row]
        let viewController = ProductViewController(product: product)
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension ProductsCollectionViewController {
    
    func setupTitle() {
        self.title = "Bears"
    }
    
}
