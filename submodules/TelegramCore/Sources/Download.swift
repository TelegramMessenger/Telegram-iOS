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

class Download: NSObject, MTRequestMessageServiceDelegate {
    let datacenterId: Int
    let isCdn: Bool
    let context: MTContext
    let mtProto: MTProto
    let requestService: MTRequestMessageService
    
    private var shouldKeepConnectionDisposable: Disposable?
    
    init(queue: Queue, datacenterId: Int, isMedia: Bool, isCdn: Bool, context: MTContext, masterDatacenterId: Int, usageInfo: MTNetworkUsageCalculationInfo?, shouldKeepConnection: Signal<Bool, NoError>) {
        self.datacenterId = datacenterId
        self.isCdn = isCdn
        self.context = context

        var requiredAuthToken: Any?
        var authTokenMasterDatacenterId: Int = 0
        if !isCdn && datacenterId != masterDatacenterId {
            authTokenMasterDatacenterId = masterDatacenterId
            requiredAuthToken = Int(datacenterId) as NSNumber
        }
        
        self.mtProto = MTProto(context: self.context, datacenterId: datacenterId, usageCalculationInfo: usageInfo, requiredAuthToken: requiredAuthToken, authTokenMasterDatacenterId: authTokenMasterDatacenterId)
        self.mtProto.cdn = isCdn
        self.mtProto.useTempAuthKeys = self.context.useTempAuthKeys && !isCdn
        self.mtProto.media = isMedia
        self.requestService = MTRequestMessageService(context: self.context)
        self.requestService.forceBackgroundRequests = true
        
        super.init()
        
        self.requestService.delegate = self
        self.mtProto.add(self.requestService)
        
        let mtProto = self.mtProto
        self.shouldKeepConnectionDisposable = (shouldKeepConnection |> distinctUntilChanged |> deliverOn(queue)).start(next: { [weak mtProto] value in
            if let mtProto = mtProto {
                if value {
                    Logger.shared.log("Network", "Resume worker network connection")
                    mtProto.resume()
                } else {
                    Logger.shared.log("Network", "Pause worker network connection")
                    mtProto.pause()
                }
            }
        })
    }
    
    deinit {
        self.mtProto.remove(self.requestService)
        self.mtProto.stop()
        self.mtProto.finalizeSession()
        self.shouldKeepConnectionDisposable?.dispose()
    }
    
    func requestMessageServiceAuthorizationRequired(_ requestMessageService: MTRequestMessageService!) {
        self.context.updateAuthTokenForDatacenter(withId: self.datacenterId, authToken: nil)
        self.context.authTokenForDatacenter(withIdRequired: self.datacenterId, authToken:self.mtProto.requiredAuthToken, masterDatacenterId: self.mtProto.authTokenMasterDatacenterId)
    }
    
    static func uploadPart(multiplexedManager: MultiplexedRequestManager, datacenterId: Int, consumerId: Int64, tag: MediaResourceFetchTag?, fileId: Int64, index: Int, data: Data, asBigPart: Bool, bigTotalParts: Int? = nil, useCompression: Bool = false) -> Signal<Void, UploadPartError> {
        let saveFilePart: (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>)
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
        
        return multiplexedManager.request(to: .main(datacenterId), consumerId: consumerId, data: wrapMethodBody(saveFilePart, useCompression: useCompression), tag: tag, continueInBackground: true)
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
    
    func uploadPart(fileId: Int64, index: Int, data: Data, asBigPart: Bool, bigTotalParts: Int? = nil, useCompression: Bool = false) -> Signal<Void, UploadPartError> {
        return Signal<Void, MTRpcError> { subscriber in
            let request = MTRequest()
            
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
            
            request.setPayload(saveFilePart.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(saveFilePart.0), tag: nil), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(saveFilePart.0)), responseParser: { response in
                if let result = saveFilePart.2.parse(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                return true
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError(error)
                } else {
                    subscriber.putCompletion()
                }
            }
            
            let internalId: Any! = request.internalId
            
            self.requestService.add(request)
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
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
            let request = MTRequest()
            
            var updatedLength = roundUp(length, to: 4096)
            while updatedLength % 4096 != 0 || 1048576 % updatedLength != 0 {
                updatedLength += 1
            }
            
            let data = Api.functions.upload.getWebFile(location: location, offset: Int32(offset), limit: Int32(updatedLength))
            
            request.setPayload(data.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedFunctionDescription(data.0)), responseParser: { response in
                if let result = data.2.parse(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                return true
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError(error)
                } else {
                    if let result = (boxedResponse as! BoxedMessage).body as? Api.upload.WebFile {
                        switch result {
                            case .webFile(_, _, _, _, let bytes):
                                subscriber.putNext(bytes.makeData())
                        }
                        subscriber.putCompletion()
                    }
                    else {
                        subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                    }
                }
            }
            
            let internalId: Any! = request.internalId
            
            self.requestService.add(request)
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
        } |> retryRequest
    }
    
    func part(location: Api.InputFileLocation, offset: Int, length: Int) -> Signal<Data, NoError> {
        return Signal<Data, MTRpcError> { subscriber in
            let request = MTRequest()
            
            var updatedLength = roundUp(length, to: 4096)
            while updatedLength % 4096 != 0 || 1048576 % updatedLength != 0 {
                updatedLength += 1
            }
            
            let data = Api.functions.upload.getFile(flags: 0, location: location, offset: Int32(offset), limit: Int32(updatedLength))
            
            request.setPayload(data.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)), responseParser: { response in
                if let result = data.2.parse(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                return true
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError(error)
                } else {
                    if let result = (boxedResponse as! BoxedMessage).body as? Api.upload.File {
                        switch result {
                            case let .file(_, _, bytes):
                                subscriber.putNext(bytes.makeData())
                            case .fileCdnRedirect:
                                break
                        }
                        subscriber.putCompletion()
                    }
                    else {
                        subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                    }
                }
            }
            
            let internalId: Any! = request.internalId
            
            self.requestService.add(request)
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
        }
        |> retryRequest
    }
    
    func request<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>)) -> Signal<T, MTRpcError> {
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)), responseParser: { response in
                if let result = data.2.parse(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                return true
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError(error)
                } else {
                    if let result = (boxedResponse as! BoxedMessage).body as? T {
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    }
                    else {
                        subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                    }
                }
            }
            
            let internalId: Any! = request.internalId
            
            self.requestService.add(request)
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
        }
    }
    
    func requestWithAdditionalData<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), automaticFloodWait: Bool = true, failOnServerErrors: Bool = false) -> Signal<(T, Double), (MTRpcError, Double)> {
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)), responseParser: { response in
                if let result = data.2.parse(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                guard let errorContext = errorContext else {
                    return true
                }
                if errorContext.floodWaitSeconds > 0 && !automaticFloodWait {
                    return false
                }
                if errorContext.internalServerErrorCount > 0 && failOnServerErrors {
                    return false
                }
                return true
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError((error, timestamp))
                } else {
                    if let result = (boxedResponse as! BoxedMessage).body as? T {
                        subscriber.putNext((result, timestamp))
                        subscriber.putCompletion()
                    }
                    else {
                        subscriber.putError((MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"), timestamp))
                    }
                }
            }
            
            let internalId: Any! = request.internalId
            
            self.requestService.add(request)
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
        }
    }
    
    func rawRequest(_ data: (FunctionDescription, Buffer, (Buffer) -> Any?), automaticFloodWait: Bool = true, failOnServerErrors: Bool = false) -> Signal<(Any, Double), (MTRpcError, Double)> {
        let requestService = self.requestService
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: nil), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)), responseParser: { response in
                if let result = data.2(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                guard let errorContext = errorContext else {
                    return true
                }
                if errorContext.floodWaitSeconds > 0 && !automaticFloodWait {
                    return false
                }
                if errorContext.internalServerErrorCount > 0 && failOnServerErrors {
                    return false
                }
                return true
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError((error, timestamp))
                } else {
                    subscriber.putNext(((boxedResponse as! BoxedMessage).body, timestamp))
                    subscriber.putCompletion()
                }
            }
            
            let internalId: Any! = request.internalId
            
            requestService.add(request)
            
            return ActionDisposable { [weak requestService] in
                requestService?.removeRequest(byInternalId: internalId)
            }
        }
    }
}
