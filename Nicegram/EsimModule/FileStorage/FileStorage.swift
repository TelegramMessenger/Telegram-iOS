import Foundation

public class FileStorage<Value: Codable> {
    
    //  MARK: - Logic
    
    private let fileUrl: URL?
    
    //  MARK: - Lifecycle
    
    public init(path: String, fileManager: FileManager = .default) {
        guard let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            self.fileUrl = nil
            return
        }
        
        let fileUrl = dir.appendingPathComponent(path)
        let folderUrl = fileUrl.deletingLastPathComponent()
        
        try? fileManager.createDirectory(at: folderUrl, withIntermediateDirectories: true)
        
        self.fileUrl = dir.appendingPathComponent(path)
    }
    
    //  MARK: - Public Functions

    public func read() -> Value? {
        guard let fileUrl = fileUrl else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileUrl)
            let value = try JSONDecoder().decode(Value.self, from: data)
            return value
        } catch {
            return nil
        }
    }
    
    public func save(_ value: Value?) {
        guard let fileUrl = fileUrl else {
            return
        }

        
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileUrl)
        } catch { }
    }
}
