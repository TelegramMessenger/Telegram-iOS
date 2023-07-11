import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import MediaEditor

public final class CameraStoredState: Codable {
    private enum CodingKeys: String, CodingKey {
        case isDualCameraEnabled
        case dualCameraPosition
    }
    
    public let isDualCameraEnabled: Bool
    public let dualCameraPosition: CameraScreen.PIPPosition
    
    public init(
        isDualCameraEnabled: Bool,
        dualCameraPosition: CameraScreen.PIPPosition
    ) {
        self.isDualCameraEnabled = isDualCameraEnabled
        self.dualCameraPosition = dualCameraPosition
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.isDualCameraEnabled = try container.decode(Bool.self, forKey: .isDualCameraEnabled)
        self.dualCameraPosition = CameraScreen.PIPPosition(rawValue: try container.decode(Int32.self, forKey: .dualCameraPosition)) ?? .topRight
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.isDualCameraEnabled, forKey: .isDualCameraEnabled)
        try container.encode(self.dualCameraPosition.rawValue, forKey: .dualCameraPosition)
    }
    
    public func withIsDualCameraEnabled(_ isDualCameraEnabled: Bool) -> CameraStoredState {
        return CameraStoredState(isDualCameraEnabled: isDualCameraEnabled, dualCameraPosition: self.dualCameraPosition)
    }
    
    public func withDualCameraPosition(_ dualCameraPosition: CameraScreen.PIPPosition) -> CameraStoredState {
        return CameraStoredState(isDualCameraEnabled: self.isDualCameraEnabled, dualCameraPosition: dualCameraPosition)
    }
}

func cameraStoredState(engine: TelegramEngine) -> Signal<CameraStoredState?, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.cameraState, id: key))
    |> map { entry -> CameraStoredState? in
        return entry?.get(CameraStoredState.self)
    }
}

func updateCameraStoredStateInteractively(engine: TelegramEngine, _ f: @escaping (CameraStoredState?) -> CameraStoredState?) {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    let _ = (engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.cameraState, id: key))
    |> map { entry -> CameraStoredState? in
        return entry?.get(CameraStoredState.self)
    }
    |> mapToSignal { state -> Signal<Never, NoError> in
        if let updatedState = f(state) {
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.cameraState, id: key, item: updatedState)
        } else {
            return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.cameraState, id: key)
        }
    }).start()
}
