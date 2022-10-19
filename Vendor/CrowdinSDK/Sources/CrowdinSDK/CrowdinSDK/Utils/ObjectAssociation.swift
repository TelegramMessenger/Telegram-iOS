//
//  ObjectAssociation.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/27/19.
//

import Foundation

final class ObjectAssociation<T: Any> {
    private let policy: objc_AssociationPolicy
    
    /// - Parameter policy: An association policy that will be used when linking objects.
    init(policy: objc_AssociationPolicy = .OBJC_ASSOCIATION_RETAIN_NONATOMIC) {
        self.policy = policy
    }
    
    /// Accesses associated object.
    /// - Parameter index: An object whose associated object is to be accessed.
    subscript(index: AnyObject) -> T? {
        // swiftlint:disable force_cast
        get { return objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as! T? }
        set { objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, policy) }
    }
}
