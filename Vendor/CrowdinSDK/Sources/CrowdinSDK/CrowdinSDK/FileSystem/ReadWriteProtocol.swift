//
//  ReadWriteProtocol.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 2/10/19.
//

import UIKit

protocol ReadWriteProtocol {
    func write(to path: String)
    static func read(from path: String) -> Self?
}

extension NSDictionary: ReadWriteProtocol {
    func write(to path: String) {
        self.write(toFile: path, atomically: true)
    }
    
    static func read(from path: String) -> Self? {
        return self.init(contentsOfFile: path)
    }
}

extension Dictionary: ReadWriteProtocol {
    func write(to path: String) {
        NSDictionary(dictionary: self).write(toFile: path, atomically: true)
    }
    
    static func read(from path: String) -> Dictionary<Key, Value>? {
        return NSDictionary(contentsOfFile: path) as? Dictionary
    }
}

extension UIImage: ReadWriteProtocol {
    static func read(from path: String) -> Self? {
        return self.init(contentsOfFile: path)
    }
    
    func write(to path: String) {
        try? self.pngData()?.write(to: URL(fileURLWithPath: path))
    }
}

/// TODO: Add custon JSONEncode & JSONDecoder support.
class CodableWrapper<T: Codable> {
    var object: T
    
    required init(object: T) {
        self.object = object
    }
}

extension CodableWrapper: ReadWriteProtocol {
    func write(to path: String) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
    
    static func read(from path: String) -> Self? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        guard let object = try? JSONDecoder().decode(T.self, from: data) else { return nil }
        return self.init(object: object)
    }
}
