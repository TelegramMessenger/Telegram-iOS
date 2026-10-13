import Foundation
import SwiftSignalKit
import WalletEngineFFI

@available(macOS 10.15, *)
public extension WalletContext {
    enum TransferFeeComment: Equatable, Sendable {
        case none
        case plainText(byteCount: Int)
        case encrypted
    }

    struct TransferFeeEstimate: Equatable, Sendable {
        public let fee: Int64
    }

    func estimateTransferFee(address: String, comment: TransferFeeComment) -> Signal<TransferFeeEstimate, WalletError> {
        return self.signal(name: "estimating_transfer_fee") { impl, operationId in
            try await impl.estimateTransferFee(address: address, comment: comment, operationId: operationId)
        }
    }
}

func walletMaximumEncryptedCommentFeePayload() -> String {
    let payload = [UInt8](repeating: 0, count: 1024)
    var chunks: [[UInt8]] = [[0x21, 0x67, 0xda, 0x4b] + Array(payload.prefix(35))]
    for offset in stride(from: 35, to: payload.count, by: 127) {
        chunks.append(Array(payload[offset ..< min(offset + 127, payload.count)]))
    }
    var cells = Data()
    for (index, chunk) in chunks.enumerated() {
        let hasReference = index + 1 < chunks.count
        cells.append(hasReference ? 1 : 0)
        cells.append(UInt8(chunk.count * 2))
        cells.append(contentsOf: chunk)
        if hasReference {
            cells.append(UInt8(index + 1))
        }
    }
    var boc = Data([0xb5, 0xee, 0x9c, 0x72, 0x01, 0x02, UInt8(chunks.count), 0x01, 0x00])
    boc.append(UInt8(cells.count >> 8))
    boc.append(UInt8(cells.count & 0xff))
    boc.append(0)
    boc.append(cells)
    return boc.base64EncodedString()
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func estimateTransferFee(address: String, comment: WalletContext.TransferFeeComment, operationId: UUID) async throws -> WalletContext.TransferFeeEstimate {
        return try await self.performOperation(.preparingTransfer, operationId: operationId, requiresAuthorization: false) {
            guard case .wallet = self.currentState.phase else { throw WalletContext.WalletError.unavailable }
            let destination = try WalletTransferDestination(address.trimmingCharacters(in: .whitespacesAndNewlines))
            let body: SendMessageBody
            switch comment {
            case .none:
                body = .empty
            case let .plainText(byteCount):
                guard byteCount >= 0 else { throw WalletContext.WalletError.previewFailed }
                body = .comment(text: String(repeating: "a", count: byteCount))
            case .encrypted:
                body = .rawPayload(boc: walletMaximumEncryptedCommentFeePayload())
            }
            let intent = SendIntent(
                expiration: .engineDefault,
                messages: [destination.message(amount: .exact(nanograms: "0"), body: body)]
            )
            let generation = self.activationGeneration
            let preview: SendPreview
            do {
                preview = try await self.runtime.previewSend(intent: intent)
            } catch {
                try Task.checkCancellation()
                guard !self.isShutdown, self.activationGeneration == generation else { throw WalletContext.WalletError.unavailable }
                guard walletPreviewNeedsSeqnoRetry(error) else { throw error }
                self.logger.log("event=wallet_fee_preview_seqno_retry operation_id=\(operationId.uuidString.lowercased()) error_code=133 retry_delay_ms=1000")
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try Task.checkCancellation()
                guard !self.isShutdown, self.activationGeneration == generation else { throw WalletContext.WalletError.unavailable }
                preview = try await self.runtime.previewSend(intent: intent)
            }
            try Task.checkCancellation()
            guard !self.isShutdown, self.activationGeneration == generation else { throw WalletContext.WalletError.unavailable }
            guard !preview.emulation.isIncomplete else { throw WalletContext.WalletError.previewIncomplete }
            guard let fee = Int64(preview.emulation.walletFeesNanograms), fee >= 0 else { throw WalletContext.WalletError.previewFailed }
            return WalletContext.TransferFeeEstimate(fee: fee)
        }
    }
}
