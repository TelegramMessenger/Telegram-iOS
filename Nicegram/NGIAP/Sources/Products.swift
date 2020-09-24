//
//  Products.swift
//  NicegramLib
//
//  Created by Sergey Akentev on 28.10.2019.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
import NGEnv

public struct NicegramProducts {
    
    public static let Premium = NGENV.premium_bundle
    
    private static let productIdentifiers: Set<ProductIdentifier> = [NicegramProducts.Premium]
    
    public static let store = IAPHelper(productIds: NicegramProducts.productIdentifiers)
}

func resourceNameForProductIdentifier(_ productIdentifier: String) -> String? {
    return productIdentifier.components(separatedBy: ".").last
}

