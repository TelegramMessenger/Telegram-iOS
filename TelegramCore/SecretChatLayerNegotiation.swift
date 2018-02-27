import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private let topSupportedLayer: SecretChatSequenceBasedLayer = .layer73

func secretChatCommonSupportedLayer(remoteLayer: Int32) -> SecretChatSequenceBasedLayer {
    switch remoteLayer {
        case 46:
            return .layer46
        case 73:
            return .layer73
        default:
            return topSupportedLayer
    }
}

func secretChatAddReportCurrentLayerSupportOperationAndUpdateRequestedLayer(modifier: Modifier, peerId: PeerId, state: SecretChatState) -> SecretChatState {
    switch state.embeddedState {
        case .basicLayer:
            var updatedState = state
            updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: peerId, operation: .reportLayerSupport(layer: topSupportedLayer.secretChatLayer, actionGloballyUniqueId: arc4random64(), layerSupport: topSupportedLayer.rawValue), state: updatedState)
            return updatedState
        case let .sequenceBasedLayer(sequenceState):
            var updatedState = state
            updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: peerId, operation: .reportLayerSupport(layer: sequenceState.layerNegotiationState.activeLayer.secretChatLayer, actionGloballyUniqueId: arc4random64(), layerSupport: topSupportedLayer.rawValue), state: updatedState)
            updatedState =  updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedLayerNegotiationState(sequenceState.layerNegotiationState.withUpdatedLocallyRequestedLayer(topSupportedLayer.rawValue))))
            return updatedState
        default:
            return state
    }
}

func secretChatCheckLayerNegotiationIfNeeded(modifier: Modifier, peerId: PeerId, state: SecretChatState) -> SecretChatState {
    switch state.embeddedState {
        case let .sequenceBasedLayer(sequenceState):
            if sequenceState.layerNegotiationState.activeLayer != topSupportedLayer {
                var updatedState = state
                
                if let remotelyRequestedLayer = sequenceState.layerNegotiationState.remotelyRequestedLayer {
                    let updatedSequenceState = sequenceState.withUpdatedLayerNegotiationState(sequenceState.layerNegotiationState.withUpdatedActiveLayer(secretChatCommonSupportedLayer(remoteLayer: remotelyRequestedLayer)))
                    updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(updatedSequenceState))
                }
                
                if (sequenceState.layerNegotiationState.locallyRequestedLayer ?? 0) < topSupportedLayer.rawValue {
                    updatedState = secretChatAddReportCurrentLayerSupportOperationAndUpdateRequestedLayer(modifier: modifier, peerId: peerId, state: updatedState)
                }
                
                return updatedState
            } else {
                return state
            }
        case .basicLayer:
            return state
        default:
            return state
    }
}
