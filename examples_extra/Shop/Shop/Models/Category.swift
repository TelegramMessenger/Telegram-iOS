//
//  Category.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

struct Category {
    
    var id: String = UUID().uuidString
    var imageURL: String
    var numberOfProducts: Int = 0
    var title: String
    var products: [Product]
    
    init(title: String, imageURL: String, products: [Product]) {
        self.title = title
        self.imageURL = imageURL
        self.products = products
        self.numberOfProducts = products.count
    }
    
}
