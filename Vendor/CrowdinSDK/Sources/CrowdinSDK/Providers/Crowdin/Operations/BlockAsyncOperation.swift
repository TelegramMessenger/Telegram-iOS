//
//  BlockAsyncOperation.swift
//  OperationUtils
//
//  Created by Serhii Londar on 5/25/18.
//  Copyright © 2018 Serhii Londar. All rights reserved.
//

import Foundation

protocol AnyBlockOperation: AnyAsyncOperation {
    var block: () -> Void { get }
    init(block: @escaping () -> Void)
}

class BlockAsyncOperation: AsyncOperation, AnyBlockOperation {
    var block: () -> Void
    required init(block: @escaping () -> Void) {
        self.block = block
    }
    
    override func main() {
        block()
    }
}
