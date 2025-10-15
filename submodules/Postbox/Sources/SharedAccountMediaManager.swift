import Foundation

final class SharedAccountMediaManager {
    private let basePath: String
    
    init(basePath: String) {
        self.basePath = basePath
    }
    
    private func fileNameForId(_ id: MediaResourceId) -> String {
        return "\(id.stringRepresentation)"
    }
    
    private func pathForId(_ id: MediaResourceId) -> String {
        return "\(self.basePath)/\(fileNameForId(id))"
    }
    
    func resourceData(resourceId: MediaResourceId) -> Data? {
        return try? Data(contentsOf: URL(fileURLWithPath: self.pathForId(resourceId)))
    }
    
    func storeResourceData(resourceId: MediaResourceId, data: Data) {
        let _ = try? data.write(to: URL(fileURLWithPath: self.pathForId(resourceId)))
    }
}
