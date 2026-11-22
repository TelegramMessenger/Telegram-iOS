import Foundation
import SwiftSignalKit

final class FileDownload: NSObject, URLSessionDownloadDelegate {
    let fileName: String
    let fileSize: Int64?
    let isMedia: Bool
    
    private var urlSession: URLSession!
    private var completion: ((URL?, Error?) -> Void)?
    private var progressHandler: ((Double) -> Void)?
    private var task: URLSessionDownloadTask!
    
    private let progressPromise = ValuePromise<Double>(0.0)
    var progressSignal: Signal<Double,  NoError> {
        return self.progressPromise.get()
    }
    
    init(from url: URL, fileName: String, fileSize: Int64?, isMedia: Bool, progressHandler: @escaping (Double) -> Void, completion: @escaping (URL?, Error?) -> Void) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.isMedia = isMedia
        self.completion = completion
        self.progressHandler = progressHandler
        
        super.init()
        
        let configuration = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        
        let downloadTask = self.urlSession.downloadTask(with: url)
        downloadTask.resume()
        self.task = downloadTask
    }
    
    func cancel() {
        self.task.cancel()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        var totalBytesExpectedToWrite = totalBytesExpectedToWrite
        if totalBytesExpectedToWrite == -1, let fileSize = self.fileSize {
            totalBytesExpectedToWrite = fileSize
        }
        let progress = max(0.0, min(1.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        self.progressHandler?(progress)
        self.progressPromise.set(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.completion?(location, nil)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.completion?(nil, error)
        }
    }
    
    static func getFileSize(url: String) -> Signal<Int64?, NoError> {
        if #available(iOS 13.0, *) {
            guard let url = URL(string: url) else {
                return .single(nil)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            
            return Signal { subscriber in
                let task = URLSession.shared.dataTask(with: request) { _, response, error in
                    if let _ = error {
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                        return
                    }
                    var fileSize: Int64?
                    if let httpResponse = response as? HTTPURLResponse, let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"), let size = Int64(contentLength) {
                        fileSize = size
                    }
                    subscriber.putNext(fileSize)
                    subscriber.putCompletion()
                }
                task.resume()
                return ActionDisposable {
                    task.cancel()
                }
            }
        } else {
            return .single(nil)
        }
    }
}
