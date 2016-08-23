import Foundation
import SwiftSignalKit
import MtProtoKit

class Download {
    let datacenterId: Int
    let context: MTContext
    let mtProto: MTProto
    let requestService: MTRequestMessageService
    
    init(datacenterId: Int, context: MTContext, masterDatacenterId: Int) {
        self.datacenterId = datacenterId
        self.context = context

        self.mtProto = MTProto(context: self.context, datacenterId: datacenterId)
        if datacenterId != masterDatacenterId {
            self.mtProto.authTokenMasterDatacenterId = masterDatacenterId
            self.mtProto.requiredAuthToken = Int(datacenterId) as NSNumber
        }
        self.requestService = MTRequestMessageService(context: self.context)
        self.mtProto.add(self.requestService)
    }
    
    deinit {
        self.mtProto.remove(self.requestService)
        self.mtProto.stop()
    }
    
    func part(location: Api.InputFileLocation, offset: Int, length: Int) -> Signal<Data, NoError> {
        return Signal<Data, MTRpcError> { subscriber in
            let request = MTRequest()
            
            let data = Api.functions.upload.getFile(location: location, offset: Int32(offset), limit: Int32(length))
            
            request.setPayload(data.1.makeData() as Data!, metadata: WrappedRequestMetadata(metadata: data.0), responseParser: { response in
                if let result = data.2(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError(error)
                } else {
                    if let result = (boxedResponse as! BoxedMessage).body as? Api.upload.File {
                        switch result {
                            case let .file(_, _, bytes):
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
    
    func request<T>(_ data: (CustomStringConvertible, Buffer, (Buffer) -> T?)) -> Signal<T, MTRpcError> {
        return self.request(data, dependsOnPasswordEntry: true)
    }
    
    func request<T>(_ data: (CustomStringConvertible, Buffer, (Buffer) -> T?), dependsOnPasswordEntry: Bool) -> Signal<T, MTRpcError> {
        let requestService = self.requestService
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data!, metadata: WrappedRequestMetadata(metadata: data.0), responseParser: { response in
                if let result = data.2(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = dependsOnPasswordEntry
            
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
            
            requestService.add(request)
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
        }
    }
}
