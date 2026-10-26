import Foundation
import TelegramPresentationData
import TelegramStringFormatting
import WalletContext

struct WalletTransferPresentation {
    struct SigningField: Equatable {
        let name: String
        let value: String
    }

    enum SigningContent: Equatable {
        case text(String)
        case binary
        case message([[SigningField]])

        func explanation(strings: PresentationStrings) -> String? {
            switch self {
            case .text:
                return strings.Wallet_Sign_TextExplanation
            case .binary:
                return nil
            case .message:
                return strings.Wallet_Sign_MessageExplanation
            }
        }
    }

    struct PreviewItem {
        enum Kind: Equatable { case transfer, callContract, deployContract, excess, unknown }
        enum Direction: Equatable { case incoming, outgoing }

        let id: String
        let kind: Kind
        let direction: Direction?
        let address: String?
        let amount: String?
        let comment: String?
        let succeeded: Bool
    }

    let request: WalletContext.TonConnectOperationRequest
    let walletState: WalletContext.State?

    var isSigning: Bool {
        return self.request.method == .signData || self.request.method == .signMessage
    }

    func signingContent(strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> SigningContent? {
        switch self.request.method {
        case .sendTransaction:
            return nil
        case .signData:
            guard let signData = self.request.signData else { return .binary }
            switch signData.payload {
            case let .text(text):
                return .text(text)
            case .binary, .cell:
                return .binary
            }
        case .signMessage:
            var groups: [[SigningField]] = []
            if let validUntil = self.request.validUntil {
                groups.append([SigningField(name: strings.Wallet_Sign_FieldValidUntil, value: String(validUntil))])
            }
            for (index, message) in self.request.messages.enumerated() {
                var fields: [SigningField] = []
                if self.request.messages.count > 1 {
                    fields.append(SigningField(name: strings.Wallet_Sign_FieldMessage, value: String(index + 1)))
                }
                fields.append(SigningField(name: strings.Wallet_Sign_FieldAddress, value: message.destination))
                fields.append(SigningField(name: strings.Wallet_Sign_FieldAmount, value: formatTonConnectNanograms(message.amountNanograms, strings: strings, dateTimeFormat: dateTimeFormat)))
                switch message.payload {
                case .empty:
                    break
                case let .comment(text):
                    fields.append(SigningField(name: strings.Wallet_Sign_FieldComment, value: text))
                case let .raw(boc):
                    fields.append(SigningField(name: strings.Wallet_Sign_FieldPayload, value: boc))
                }
                if let stateInit = message.stateInit {
                    fields.append(SigningField(name: strings.Wallet_Sign_FieldStateInit, value: stateInit))
                }
                groups.append(fields)
            }
            return .message(groups)
        }
    }

    var amountNanograms: String? {
        var total = "0"
        for message in self.request.messages {
            if message.amountNanograms == "all" { return "all" }
            guard let amount = normalizedTonConnectNanograms(message.amountNanograms) else { return nil }
            // Keep the engine's unsigned amount precision, including batches beyond Int64.
            let lhs = Array(total.utf8.reversed())
            let rhs = Array(amount.utf8.reversed())
            var digits: [UInt8] = []
            var carry = 0
            for index in 0..<max(lhs.count, rhs.count) {
                let sum = (index < lhs.count ? Int(lhs[index] - 48) : 0)
                    + (index < rhs.count ? Int(rhs[index] - 48) : 0) + carry
                digits.append(UInt8(sum % 10) + 48)
                carry = sum / 10
            }
            if carry != 0 { digits.append(UInt8(carry) + 48) }
            total = String(decoding: digits.reversed(), as: UTF8.self)
        }
        return total
    }

    var recipient: String {
        guard let message = self.request.messages.first else { return "" }
        return WalletContext.transferAddress(from: message.destination) ?? message.destination
    }

    func recipientTitle(strings: PresentationStrings) -> String? {
        guard self.request.messages.count > 1 else { return nil }
        let recipients = Set(self.request.messages.map { WalletContext.transferAddress(from: $0.destination) ?? $0.destination })
        return recipients.count == 1 ? nil : strings.Wallet_Transfer_RecipientCount(Int32(clamping: recipients.count))
    }

    var previewItems: [PreviewItem] {
        if self.request.actions.isEmpty {
            return self.request.messages.map { message in
                let kind: PreviewItem.Kind
                let comment: String?
                switch message.payload {
                case .empty: kind = .transfer; comment = nil
                case let .comment(value): kind = .transfer; comment = value
                case .raw: kind = .callContract; comment = nil
                }
                return PreviewItem(id: message.id, kind: kind, direction: .outgoing,
                    address: WalletContext.transferAddress(from: message.destination) ?? message.destination,
                    amount: message.amountNanograms, comment: comment, succeeded: true)
            }
        }
        let walletAddress: String?
        if let state = self.walletState, case let .wallet(wallet) = state.phase {
            walletAddress = WalletContext.transferAddress(from: wallet.address)
        } else {
            walletAddress = nil
        }
        return self.request.actions.map { action in
            let kind: PreviewItem.Kind
            switch action.kind {
            case "ton_transfer": kind = .transfer
            case "call_contract": kind = .callContract
            case "contract_deploy", "deploy_contract": kind = .deployContract
            case "excess": kind = .excess
            default: kind = .unknown
            }
            let details = (try? JSONSerialization.jsonObject(with: Data(action.detailsJson.utf8))) as? [String: Any] ?? [:]
            let source = (details["source"] as? String).flatMap { WalletContext.transferAddress(from: $0) }
            let destination = (details["destination"] as? String).flatMap { WalletContext.transferAddress(from: $0) }
            let direction: PreviewItem.Direction?
            if let walletAddress, source == walletAddress { direction = .outgoing }
            else if let walletAddress, destination == walletAddress { direction = .incoming }
            else { direction = nil }
            let address = direction == .incoming ? source : destination
            let amount = action.kind == "ton_transfer"
                ? (details["value"] as? String).flatMap(normalizedTonConnectNanograms) : nil
            return PreviewItem(id: action.id, kind: kind, direction: direction,
                address: address ?? action.accounts.first.flatMap { WalletContext.transferAddress(from: $0) },
                amount: amount, comment: details["comment"] as? String, succeeded: action.succeeded)
        }
    }

    func submissionText(strings: PresentationStrings) -> String? {
        guard self.request.method == .signMessage else { return nil }
        if let validUntil = self.request.validUntil {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: strings.baseLanguageCode)
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let date = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(validUntil)))
            return strings.Wallet_Sign_SubmissionUntil(date).string
        }
        return strings.Wallet_Sign_Submission
    }

    func feeText(strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
        var text: String
        if let fee = self.request.feeNanograms {
            let formattedFee = formatTonConnectNanograms(fee, strings: strings, dateTimeFormat: dateTimeFormat)
            if let feeValue = Int64(fee), let fiatRate = self.walletState?.fiat.selectedRate {
                let currency = self.walletState?.fiat.selectedCurrency ?? .usd
                let fiatValue = Double(feeValue) / 1_000_000_000.0 * fiatRate.unitsPerGram
                let fiatFee: String
                if fiatValue > 0.0, fiatValue < 0.01 {
                    fiatFee = "<\(currency.symbol)0\(dateTimeFormat.decimalSeparator)01"
                } else {
                    fiatFee = formatTonFiatValue(feeValue, rate: fiatRate.unitsPerGram,
                        currencySymbol: currency.symbol, maxDecimalPositions: 2, dateTimeFormat: dateTimeFormat)
                }
                text = strings.Wallet_Sign_FeeWithFiat(formattedFee, fiatFee).string
            } else {
                text = strings.Wallet_Sign_Fee(formattedFee).string
            }
        } else {
            text = ""
        }
        return text
    }
}

private func normalizedTonConnectNanograms(_ value: String) -> String? {
    guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
    let digits = String(value.drop(while: { $0 == "0" }))
    return digits.isEmpty ? "0" : digits
}

func formatTonConnectNanograms(_ value: String, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
    if value == "all" {
        return strings.Wallet_Transfer_AllBalance
    }
    guard let digits = normalizedTonConnectNanograms(value) else { return strings.Wallet_Transfer_Unavailable }
    if let value = Int64(digits) {
        return formatTonAmountText(value, dateTimeFormat: dateTimeFormat, maxDecimalPositions: 9, formatString: strings.Currency_Grams)
    }
    let split = digits.index(digits.endIndex, offsetBy: -9)
    let integer = digits[..<split]
    let fraction = String(digits[split...].reversed().drop(while: { $0 == "0" }).reversed())
    let amount = fraction.isEmpty ? String(integer) : "\(integer)\(dateTimeFormat.decimalSeparator)\(fraction)"
    return strings.Currency_Grams(100).replacingOccurrences(of: "100", with: amount)
}
