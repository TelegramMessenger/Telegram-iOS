import Foundation
import AVFoundation
import SwiftSignalKit
import Postbox

private func streamingOrPartialData(account: Account, location: TelegramMediaLocation, size: Int, range: Range<Int>) -> Signal<Data, NoError> {
    let resource = CloudFileMediaResource(location: location, size: size)
    let chunkSize =  512 * 1024
    var chunkOffset = 0
    let data = account.postbox.mediaBox.resourceData(resource, in: range, mode: .incremental)
        |> mapToThrottled { data -> Signal<Data, NoError> in
            let loop = Signal<Data, NoError> { subscriber in
                let step: () -> Void = {
                    if chunkOffset >= data.count {
                        subscriber.putCompletion()
                    } else {
                        let currentChunk = min(chunkSize, data.count - chunkOffset)
                        let chunkRange: Range<Int> = chunkOffset ..< (chunkOffset + currentChunk)
                        print("streamingOrPartialData range \(range) respond with chunk \(chunkRange) from \(data.count)")
                        subscriber.putNext(data.subdata(in: chunkRange))
                        chunkOffset += chunkSize
                        if chunkOffset >= data.count {
                            subscriber.putCompletion()
                        }
                    }
                }
                step()
                let timer = SwiftSignalKit.Timer(timeout: 0.1, repeat: true, completion: {
                    step()
                }, queue: Queue.concurrentDefaultQueue())
                timer.start()
                
                return ActionDisposable {
                    timer.invalidate()
                }
            }
            
            return loop
        }
    return data
}

@objc final class StreamingAssetResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let queue: Queue
    private let account: Account
    private let resource: StreamingResource
    
    private var disposables: [(AVAssetResourceLoadingRequest, DisposableSet)] = []
    private var resourceLoaders: [AVAssetResourceLoader] = []
    
    init(queue: Queue, account: Account, resource: StreamingResource) {
        self.queue = queue
        self.account = account
        self.resource = resource
    }
    
    deinit {
        for (_, disposable) in self.disposables {
            disposable.dispose()
        }
    }
    
    @objc func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        let resource = self.resource
        loadingRequest.contentInformationRequest?.contentLength = Int64(resource.size)
        loadingRequest.contentInformationRequest?.contentType = resource.mimeType
        loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
        
        if let dataRequest = loadingRequest.dataRequest {
            self.queue.async {
                var currentDisposableSet: DisposableSet?
                for (request, disposable) in self.disposables {
                    if request === loadingRequest {
                        currentDisposableSet = disposable
                        break
                    }
                }
                let disposableSet: DisposableSet
                if let currentDisposableSet = currentDisposableSet {
                    disposableSet = currentDisposableSet
                } else {
                    disposableSet = DisposableSet()
                    self.disposables.append((loadingRequest, disposableSet))
                }
                
                self.resourceLoaders.append(resourceLoader)
                
                let range: Range<Int> = Int(dataRequest.requestedOffset) ..< (Int(dataRequest.requestedOffset) + dataRequest.requestedLength)
                
                print("request \(unsafeAddress(of: loadingRequest)) video range: \(range)")
                
                disposableSet.add((streamingOrPartialData(account: self.account, location: resource.location, size: resource.size, range: range) |> deliverOn(self.queue)).start(next: { data in
                    print("respond with streaming \(data.count) to \(range) (\(dataRequest.currentOffset) to \(range.upperBound))")
                    dataRequest.respond(with: data)
                }, error: { _ in
                    loadingRequest.finishLoading(with: NSError(domain: "Telegram", code: 1, userInfo: nil))
                }, completed: {
                    dataRequest.respond(with: Data())
                    loadingRequest.finishLoading()
                }))
            }
        }
        
        return true
    }
    
    @objc func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        self.queue.async {
            print("request \(unsafeAddress(of: loadingRequest)) cancelled")
            for i in 0 ..< self.disposables.count {
                if self.disposables[i].0 === loadingRequest {
                    self.disposables[i].1.dispose()
                    self.disposables.remove(at: i)
                    break
                }
            }
        }
    }
}
