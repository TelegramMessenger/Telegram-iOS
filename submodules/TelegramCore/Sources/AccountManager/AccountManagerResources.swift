import Foundation
import SwiftSignalKit
import Postbox

public final class AccountManagerResources {
    private let mediaBox: MediaBox

    init(mediaBox: MediaBox) {
        self.mediaBox = mediaBox
    }

    public func data(
        resource: EngineMediaResource,
        pathExtension: String? = nil,
        waitUntilFetchStatus: Bool = false,
        attemptSynchronously: Bool = false
    ) -> Signal<EngineMediaResource.ResourceData, NoError> {
        return self.mediaBox.resourceData(
            resource._asResource(),
            pathExtension: pathExtension,
            option: .complete(waitUntilFetchStatus: waitUntilFetchStatus),
            attemptSynchronously: attemptSynchronously
        )
        |> map { EngineMediaResource.ResourceData($0) }
    }

    public func storeResourceData(id: EngineMediaResource.Id, data: Data, synchronous: Bool = false) {
        self.mediaBox.storeResourceData(MediaResourceId(id.stringRepresentation), data: data, synchronous: synchronous)
    }

    public func completedResourcePath(resource: EngineMediaResource, pathExtension: String? = nil) -> String? {
        return self.mediaBox.completedResourcePath(resource._asResource(), pathExtension: pathExtension)
    }

    public func completedResourcePath(id: EngineMediaResource.Id, pathExtension: String? = nil) -> String? {
        return self.mediaBox.completedResourcePath(id: MediaResourceId(id.stringRepresentation), pathExtension: pathExtension)
    }

    public func status(resource: EngineMediaResource, approximateSynchronousValue: Bool = false) -> Signal<EngineMediaResource.FetchStatus, NoError> {
        return self.mediaBox.resourceStatus(resource._asResource(), approximateSynchronousValue: approximateSynchronousValue)
        |> map { EngineMediaResource.FetchStatus($0) }
    }

    public func moveResourceData(from: EngineMediaResource.Id, to: EngineMediaResource.Id, synchronous: Bool = false) {
        self.mediaBox.moveResourceData(from: MediaResourceId(from.stringRepresentation), to: MediaResourceId(to.stringRepresentation), synchronous: synchronous)
    }

    public func fetch(reference: MediaResourceReference, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType) -> Signal<FetchResourceSourceType, FetchResourceError> {
        return fetchedMediaResource(mediaBox: self.mediaBox, userLocation: userLocation, userContentType: userContentType, reference: reference)
    }
}

public extension AccountManager {
    var resources: AccountManagerResources {
        return AccountManagerResources(mediaBox: self.mediaBox)
    }
}
