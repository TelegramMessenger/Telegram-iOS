import Foundation

private final class StreamingResourceServerConnection {
    
}

final class StreamingResourceServer: NSObject {
    let serverThread: Thread
    
    @objc static func clientThreadFunc(_ socketValue: NSNumber) {
        let clientSocket = socketValue.int32Value
        
        let buffer = malloc(1024)
        let readLength = read(clientSocket, buffer, 1024)
        print("buffer \(String(data: Data(bytes: UnsafePointer<UInt8>(buffer!), count: readLength), encoding: .utf8))")
        free(buffer)
    }
    
    @objc static func serverThreadFunc() {
        let serverSocket = socket(PF_INET, SOCK_STREAM, 0)
        var serverAddress = sockaddr_in()
        
        serverAddress.sin_family = sa_family_t(AF_INET)
        serverAddress.sin_port = UInt16(4000).bigEndian
        serverAddress.sin_addr.s_addr = UInt32(0x00000000)
        
        let pServerAddress = withUnsafeMutablePointer(&serverAddress, { return $0 })
        let bindResult = bind(serverSocket, unsafeBitCast(pServerAddress, to: UnsafeMutablePointer<sockaddr>.self), socklen_t(sizeof(sockaddr_in.self)))
        
        print("bind \(bindResult)")
        
        let listenResult = listen(serverSocket, 5)
        if listenResult == -1 {
            return
        }
        
        while true {
            var clientAddress = sockaddr_in()
            let pClientAddress = withUnsafeMutablePointer(&clientAddress, { return $0 })
            var clientAddrSize = socklen_t(sizeof(sockaddr_in.self))
            let clientSocket = accept(serverSocket, unsafeBitCast(pClientAddress, to: UnsafeMutablePointer<sockaddr>.self), &clientAddrSize)
            
            Thread(target: StreamingResourceServer.self, selector: #selector(StreamingResourceServer.clientThreadFunc), object: Int(clientSocket) as NSNumber).start()
        }
    }
    
    override init() {
        self.serverThread = Thread(target: StreamingResourceServer.self, selector: #selector(StreamingResourceServer.serverThreadFunc), object: nil)
        //self.serverThread.start()
        
        super.init()
    }
}
