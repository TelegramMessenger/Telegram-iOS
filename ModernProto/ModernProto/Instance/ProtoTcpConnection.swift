import Foundation

@available(iOSApplicationExtension 9.0, *)
private final class ProtoTcpConnectionDelegate: NSObject, URLSessionDelegate, URLSessionStreamDelegate {
    override init() {
        super.init()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
    }
    
    func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
    }
    
    func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
    }
}

private func tcpReadTimeout(byteCount: Int) -> TimeInterval {
    return 10.0
}

@available(iOSApplicationExtension 9.0, *)
final class ProtoTcpConnection {
    let session: URLSession
    let streamTask: URLSessionStreamTask
    
    init(host: String, port: Int32) {
        let configuration = URLSessionConfiguration.ephemeral.copy() as! URLSessionConfiguration
        if #available(iOSApplicationExtension 11.0, *) {
            configuration.waitsForConnectivity = true
        }
        
        self.session = URLSession(configuration: configuration, delegate: ProtoTcpConnectionDelegate(), delegateQueue: nil)
        self.streamTask = self.session.streamTask(withHostName: host, port: Int(port))
        self.streamTask.readData(ofMinLength: 1, maxLength: 1, timeout: tcpReadTimeout(byteCount: 1), completionHandler: { data, eof, error in
            
        })
    }
}
