import Foundation

public struct ProtoTcpPath: Equatable, Hashable {
    let host: String
    let port: Int32
    
    public init(host: String, port: Int32) {
        self.host = host
        self.port = port
    }
}

public enum ProtoPath: Equatable, Hashable {
    case tcp(ProtoTcpPath)
}
