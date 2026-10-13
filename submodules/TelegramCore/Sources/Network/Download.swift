import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

private func roundUp(_ value: Int, to multiple: Int) -> Int {
    if multiple == 0 {
        return value
    }
    
    let remainder = value % multiple
    if remainder == 0 {
        return value
    }
    
    return value + multiple - remainder
}

enum UploadPartError {
    case generic
    case invalidMedia
}

private func wrapMethodBody(_ body: (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>), useCompression: Bool) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
    if useCompression {
        if let compressed = MTGzip.compress(body.1.makeData()) {
            if compressed.count < body.1.size {
                let os = MTOutputStream()
                os.write(0x3072cfa1 as Int32)
                os.writeBytes(compressed)
                return (body.0, Buffer(data: os.currentBytes()), body.2)
            }
        }
    }
    
    return body
}

class Download: NSObject {
    let datacenterId: Int
    let isCdn: Bool
    let context: MTContext
    let session: NetworkEngineSession
    let requestService: NetworkEngineRequestService
    let useRequestTimeoutTimers: Bool
    
    private var shouldKeepConnectionDisposable: Disposable?
    private var isUserOnlineDisposable: Disposable?

    init(queue: Queue, engine: NetworkEngine, datacenterId: Int, isMedia: Bool, isCdn: Bool, context: MTContext, masterDatacenterId: Int, usageInfo: MTNetworkUsageCalculationInfo?, shouldKeepConnection: Signal<Bool, NoError>, isUserOnline: Signal<Bool, NoError>, useRequestTimeoutTimers: Bool) {
        self.datacenterId = datacenterId
        self.isCdn = isCdn
        self.context = context
        self.useRequestTimeoutTimers = useRequestTimeoutTimers
        
        self.session = engine.makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: masterDatacenterId, isMedia: isMedia, isCdn: isCdn), usageCalculationInfo: usageInfo, delegate: nil)
        self.requestService = self.session.requestService
        
        super.init()
        
        let session = self.session
        self.shouldKeepConnectionDisposable = (shouldKeepConnection |> distinctUntilChanged |> deliverOn(queue)).start(next: { [weak session] value in
            if let session = session {
                if value {
                    Logger.shared.log("Network", "Resume worker network connection")
                    session.setPaused(false)
                } else {
                    Logger.shared.log("Network", "Pause worker network connection")
                    session.setPaused(true)
                }
            }
        })
        self.isUserOnlineDisposable = (isUserOnline |> distinctUntilChanged |> deliverOn(queue)).start(next: { [weak session] value in
            session?.setOnline(value)
        })
    }

    deinit {
        self.session.stop()
        self.shouldKeepConnectionDisposable?.dispose()
        self.isUserOnlineDisposable?.dispose()
    }
    
    private func addRequest(_ request: NetworkEngineRequest) -> Disposable {
        let disposable = self.requestService.add(request)
        return ActionDisposable {
            withExtendedLifetime(self) {
                disposable.dispose()
            }
        }
    }
    
    static func uploadPart(multiplexedManager: MultiplexedRequestManager, datacenterId: Int, consumerId: Int64, tag: MediaResourceFetchTag?, fileId: Int64, index: Int, data: Data, asBigPart: Bool, bigTotalParts: Int? = nil, useCompression: Bool = false, onFloodWaitError: ((String) -> Void)? = nil) -> Signal<Void, UploadPartError> {
        let saveFilePart: (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>)
        if asBigPart {
            let totalParts: Int32
            if let bigTotalParts = bigTotalParts, bigTotalParts > 0 && bigTotalParts < Int32.max {
                totalParts = Int32(bigTotalParts)
            } else {
                totalParts = -1
            }
            saveFilePart = Api.functions.upload.saveBigFilePart(fileId: fileId, filePart: Int32(index), fileTotalParts: totalParts, bytes: Buffer(data: data))
        } else {
            saveFilePart = Api.functions.upload.saveFilePart(fileId: fileId, filePart: Int32(index), bytes: Buffer(data: data))
        }
        
        return multiplexedManager.request(to: .main(datacenterId), consumerId: consumerId, resourceId: nil, data: wrapMethodBody(saveFilePart, useCompression: useCompression), tag: tag, continueInBackground: true, onFloodWaitError: onFloodWaitError, expectedResponseSize: nil)
        |> mapError { error -> UploadPartError in
            if error.errorCode == 400 {
                return .invalidMedia
            } else {
               return .generic
            }
        }
        |> mapToSignal { _ -> Signal<Void, UploadPartError> in
            return .complete()
        }
    }
    
    func uploadPart(fileId: Int64, index: Int, data: Data, asBigPart: Bool, bigTotalParts: Int? = nil, useCompression: Bool = false, onFloodWaitError: ((String) -> Void)? = nil) -> Signal<Void, UploadPartError> {
        return Signal<Void, MTRpcError> { subscriber in
            var saveFilePart: (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>)
            if asBigPart {
                let totalParts: Int32
                if let bigTotalParts = bigTotalParts {
                    totalParts = Int32(bigTotalParts)
                } else {
                    totalParts = -1
                }
                saveFilePart = Api.functions.upload.saveBigFilePart(fileId: fileId, filePart: Int32(index), fileTotalParts: totalParts, bytes: Buffer(data: data))
            } else {
                saveFilePart = Api.functions.upload.saveFilePart(fileId: fileId, filePart: Int32(index), bytes: Buffer(data: data))
            }
            
            saveFilePart = wrapMethodBody(saveFilePart, useCompression: useCompression)
            
            let request = NetworkEngineRequest(
                payload: saveFilePart.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(saveFilePart.0), tag: nil),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(saveFilePart.0)),
                parse: { [saveFilePart] response in
                    if let result = saveFilePart.2.parse(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: true, onFloodWaitError: onFloodWaitError, failOnServerErrors: false),
                dependsOn: nil,
                acknowledged: nil,
                progress: nil,
                completed: { result in
                    switch result {
                    case .success:
                        subscriber.putCompletion()
                    case let .failure(failure):
                        subscriber.putError(failure.error)
                    }
                }
            )
            
            return self.addRequest(request)
        } |> `catch` { value -> Signal<Void, UploadPartError> in
            if value.errorCode == 400 {
                return .fail(.invalidMedia)
            } else {
               return .fail(.generic)
            }
        }
    }
    
    func webFilePart(location: Api.InputWebFileLocation, offset: Int, length: Int) -> Signal<Data, NoError> {
        return Signal<Data, MTRpcError> { subscriber in
            var updatedLength = roundUp(length, to: 4096)
            while updatedLength % 4096 != 0 || 1048576 % updatedLength != 0 {
                updatedLength += 1
            }
            
            let data = Api.functions.upload.getWebFile(location: location, offset: Int32(offset), limit: Int32(updatedLength))
            
            let request = NetworkEngineRequest(
                payload: data.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedFunctionDescription(data.0)),
                parse: { response in
                    if let result = data.2.parse(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(expectedResponseSize: Int32(length), needsTimeoutTimer: self.useRequestTimeoutTimers),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: true, onFloodWaitError: nil, failOnServerErrors: false),
                dependsOn: nil,
                acknowledged: nil,
                progress: nil,
                completed: { result in
                    switch result {
                    case let .success(response):
                        if let result = (response.result as! BoxedMessage).body as? Api.upload.WebFile {
                            switch result {
                                case let .webFile(webFileData):
                                    let bytes = webFileData.bytes
                                    subscriber.putNext(bytes.makeData())
                            }
                            subscriber.putCompletion()
                        }
                        else {
                            subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                        }
                    case let .failure(failure):
                        subscriber.putError(failure.error)
                    }
                }
            )
            
            return self.addRequest(request)
        } |> retryRequest
    }
    
    func part(location: Api.InputFileLocation, offset: Int64, length: Int) -> Signal<Data, NoError> {
        return Signal<Data, MTRpcError> { subscriber in
            var updatedLength = roundUp(length, to: 4096)
            while updatedLength % 4096 != 0 || 1048576 % updatedLength != 0 {
                updatedLength += 1
            }
            
            let data = Api.functions.upload.getFile(flags: 0, location: location, offset: offset, limit: Int32(updatedLength))
            
            let request = NetworkEngineRequest(
                payload: data.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)),
                parse: { response in
                    if let result = data.2.parse(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(expectedResponseSize: Int32(length), needsTimeoutTimer: self.useRequestTimeoutTimers),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: true, onFloodWaitError: nil, failOnServerErrors: false),
                dependsOn: nil,
                acknowledged: nil,
                progress: nil,
                completed: { result in
                    switch result {
                    case let .success(response):
                        if let result = (response.result as! BoxedMessage).body as? Api.upload.File {
                            switch result {
                                case let .file(fileData):
                                    let bytes = fileData.bytes
                                    subscriber.putNext(bytes.makeData())
                                case .fileCdnRedirect:
                                    break
                            }
                            subscriber.putCompletion()
                        }
                        else {
                            subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                        }
                    case let .failure(failure):
                        subscriber.putError(failure.error)
                    }
                }
            )
            
            return self.addRequest(request)
        }
        |> retryRequest
    }
    
    func request<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), expectedResponseSize: Int32? = nil, automaticFloodWait: Bool = true, onFloodWaitError: ((String) -> Void)? = nil) -> Signal<T, MTRpcError> {
        return Signal { subscriber in
            let request = NetworkEngineRequest(
                payload: data.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)),
                parse: { response in
                    if let result = data.2.parse(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(expectedResponseSize: expectedResponseSize ?? 0, needsTimeoutTimer: self.useRequestTimeoutTimers),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: automaticFloodWait, onFloodWaitError: onFloodWaitError, failOnServerErrors: false),
                dependsOn: nil,
                acknowledged: nil,
                progress: nil,
                completed: { result in
                    switch result {
                    case let .success(response):
                        if let result = (response.result as! BoxedMessage).body as? T {
                            subscriber.putNext(result)
                            subscriber.putCompletion()
                        }
                        else {
                            subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                        }
                    case let .failure(failure):
                        subscriber.putError(failure.error)
                    }
                }
            )
            
            return self.addRequest(request)
        }
    }
    
    func requestWithAdditionalData<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), automaticFloodWait: Bool = true, onFloodWaitError: ((String) -> Void)? = nil, failOnServerErrors: Bool = false, expectedResponseSize: Int32? = nil) -> Signal<(T, Double), (MTRpcError, Double)> {
        return Signal { subscriber in
            let request = NetworkEngineRequest(
                payload: data.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)),
                parse: { response in
                    if let result = data.2.parse(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(expectedResponseSize: expectedResponseSize ?? 0, needsTimeoutTimer: self.useRequestTimeoutTimers),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: automaticFloodWait, onFloodWaitError: onFloodWaitError, failOnServerErrors: failOnServerErrors),
                dependsOn: nil,
                acknowledged: nil,
                progress: nil,
                completed: { result in
                    switch result {
                    case let .success(response):
                        if let result = (response.result as! BoxedMessage).body as? T {
                            subscriber.putNext((result, response.info.timestamp))
                            subscriber.putCompletion()
                        }
                        else {
                            subscriber.putError((MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"), response.info.timestamp))
                        }
                    case let .failure(failure):
                        subscriber.putError((failure.error, failure.info.timestamp))
                    }
                }
            )
            
            return self.addRequest(request)
        }
    }
    
    func rawRequest(_ data: (FunctionDescription, Buffer, (Buffer) -> Any?), automaticFloodWait: Bool = true, onFloodWaitError: ((String) -> Void)? = nil, failOnServerErrors: Bool = false, logPrefix: String = "", expectedResponseSize: Int32? = nil) -> Signal<(Any, NetworkResponseInfo), (MTRpcError, Double)> {
        let requestService = self.requestService
        return Signal { [requestService] subscriber in
            let request = NetworkEngineRequest(
                payload: data.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)),
                parse: { response in
                    if let result = data.2(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(expectedResponseSize: expectedResponseSize ?? 0, needsTimeoutTimer: self.useRequestTimeoutTimers),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: automaticFloodWait, onFloodWaitError: onFloodWaitError, failOnServerErrors: failOnServerErrors),
                dependsOn: nil,
                acknowledged: nil,
                progress: nil,
                completed: { result in
                    switch result {
                    case let .success(response):
                        let mappedInfo = NetworkResponseInfo(
                            timestamp: response.info.timestamp,
                            networkType: response.info.networkType == 0 ? .wifi : .cellular,
                            networkDuration: response.info.duration
                        )
                        subscriber.putNext(((response.result as! BoxedMessage).body, mappedInfo))
                        subscriber.putCompletion()
                    case let .failure(failure):
                        subscriber.putError((failure.error, failure.info.timestamp))
                    }
                }
            )
            
            return requestService.add(request)
        }
    }
}
