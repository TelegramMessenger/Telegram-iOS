import Foundation
import Postbox
import SwiftSignalKit


private let topSupportedLayer: SecretChatSequenceBasedLayer = .layer101

func secretChatCommonSupportedLayer(remoteLayer: Int32) -> SecretChatSequenceBasedLayer {
    switch remoteLayer {
        case 46:
            return .layer46
        case 73:
            return .layer73
        case 101:
            return .layer101
        default:
            return topSupportedLayer
    }
}

func secretChatAddReportCurrentLayerSupportOperationAndUpdateRequestedLayer(transaction: Transaction, peerId: PeerId, state: SecretChatState) -> SecretChatState {
    switch state.embeddedState {
        case .basicLayer:
            var updatedState = state
            updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: .reportLayerSupport(layer: .layer8, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), layerSupport: topSupportedLayer.rawValue), state: updatedState)
            return updatedState
        case let .sequenceBasedLayer(sequenceState):
            var updatedState = state
            updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: .reportLayerSupport(layer: sequenceState.layerNegotiationState.activeLayer.secretChatLayer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), layerSupport: topSupportedLayer.rawValue), state: updatedState)
            updatedState =  updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceState.withUpdatedLayerNegotiationState(sequenceState.layerNegotiationState.withUpdatedLocallyRequestedLayer(topSupportedLayer.rawValue))))
            return updatedState
        default:
            return state
    }
}

func secretChatCheckLayerNegotiationIfNeeded(transaction: Transaction, peerId: PeerId, state: SecretChatState) -> SecretChatState {
    switch state.embeddedState {
        case let .sequenceBasedLayer(sequenceState):
            if sequenceState.layerNegotiationState.activeLayer != topSupportedLayer {
                var updatedState = state
                
                if let remotelyRequestedLayer = sequenceState.layerNegotiationState.remotelyRequestedLayer {
                    let updatedSequenceState = sequenceState.withUpdatedLayerNegotiationState(sequenceState.layerNegotiationState.withUpdatedActiveLayer(secretChatCommonSupportedLayer(remoteLayer: remotelyRequestedLayer)))
                    updatedState = updatedState.withUpdatedEmbeddedState(.sequenceBasedLayer(updatedSequenceState))
                }
                
                if (sequenceState.layerNegotiationState.locallyRequestedLayer ?? 0) < topSupportedLayer.rawValue {
                    updatedState = secretChatAddReportCurrentLayerSupportOperationAndUpdateRequestedLayer(transaction: transaction, peerId: peerId, state: updatedState)
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
