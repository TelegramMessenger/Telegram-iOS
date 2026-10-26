import Foundation
import SwiftSignalKit
import MtProtoKit

class RustContextAuthInfoListener: NSObject {
    let queue: Queue
    weak var session: RustNetworkSession?

    init(queue: Queue) {
        self.queue = queue

        super.init()
    }

    @objc(contextDatacenterAuthInfoUpdated:datacenterId:authInfo:selector:)
    func authInfoUpdated(_ context: MTContext, datacenterId: Int, authInfo: MTDatacenterAuthInfo?, selector: MTDatacenterAuthInfoSelector) {
        self.queue.async { [weak self] in
            self?.session?.contextAuthInfoUpdated(datacenterId: datacenterId, authInfo: authInfo, selector: selector)
        }
    }
}

final class RustContextListener: RustContextAuthInfoListener, MTContextChangeListener {
    @objc(contextDatacenterAuthTokenUpdated:datacenterId:authToken:)
    func contextDatacenterAuthTokenUpdated(_ context: MTContext, datacenterId: Int, authToken: Any?) {
        self.queue.async { [weak self] in
            self?.session?.contextAuthTokenUpdated(datacenterId: datacenterId, authToken: authToken)
        }
    }

    @objc(contextDatacenterAuthInfoRequestFailed:datacenterId:selector:)
    func contextDatacenterAuthInfoRequestFailed(_ context: MTContext, datacenterId: Int, selector: MTDatacenterAuthInfoSelector) {
        self.queue.async { [weak self] in
            self?.session?.contextAuthInfoRequestFailed(datacenterId: datacenterId, selector: selector)
        }
    }

    @objc(contextDatacenterAuthTokenTransferFailed:datacenterId:)
    func contextDatacenterAuthTokenTransferFailed(_ context: MTContext, datacenterId: Int) {
        self.queue.async { [weak self] in
            self?.session?.contextAuthTokenTransferFailed(datacenterId: datacenterId)
        }
    }

    @objc(contextDatacenterTransportSchemesUpdated:datacenterId:shouldReset:)
    func contextDatacenterTransportSchemesUpdated(_ context: MTContext, datacenterId: Int, shouldReset: Bool) {
        self.queue.async { [weak self] in
            self?.session?.contextTransportSchemesUpdated(datacenterId: datacenterId, shouldReset: shouldReset)
        }
    }

    @objc(contextApiEnvironmentUpdated:apiEnvironment:)
    func contextApiEnvironmentUpdated(_ context: MTContext, apiEnvironment: MTApiEnvironment) {
        self.queue.async { [weak self] in
            self?.session?.contextApiEnvironmentUpdated(apiEnvironment)
        }
    }
}
