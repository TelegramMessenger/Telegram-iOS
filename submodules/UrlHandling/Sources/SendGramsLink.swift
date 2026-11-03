import Foundation

struct SendGramsLink {
    let recipient: String?
    let amountNanograms: Int64?

    init?(queryItems: [URLQueryItem]) {
        let recipients = queryItems.filter { $0.name == "to" }
        let amounts = queryItems.filter { $0.name == "amount" }
        guard recipients.count <= 1, amounts.count <= 1 else {
            return nil
        }

        self.recipient = recipients.first?.value
        if !recipients.isEmpty {
            guard let recipient = self.recipient, !recipient.isEmpty,
                  !recipient.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains),
                  !recipient.contains("://") else {
                return nil
            }
            if recipient.hasPrefix("@") {
                let username = recipient.dropFirst()
                guard !username.isEmpty, username.utf8.allSatisfy({
                    (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 95
                }) else {
                    return nil
                }
            }
        }

        if let amount = amounts.first {
            guard self.recipient != nil, let value = amount.value,
                  let nanograms = sendGramsAmountNanograms(value) else {
                return nil
            }
            self.amountNanograms = nanograms
        } else {
            self.amountNanograms = nil
        }
    }
}

private func sendGramsAmountNanograms(_ value: String) -> Int64? {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard (1 ... 2).contains(parts.count),
          parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy({ (48 ... 57).contains($0) }) }),
          let whole = Int64(parts[0]) else {
        return nil
    }

    let (scaledWhole, wholeOverflow) = whole.multipliedReportingOverflow(by: 1_000_000_000)
    guard !wholeOverflow else {
        return nil
    }
    var fraction: Int64 = 0
    if parts.count == 2 {
        guard parts[1].count <= 9, let value = Int64(parts[1]) else {
            return nil
        }
        fraction = value
        for _ in parts[1].count ..< 9 {
            fraction *= 10
        }
    }
    let (amount, amountOverflow) = scaledWhole.addingReportingOverflow(fraction)
    guard !amountOverflow, amount > 0 else {
        return nil
    }
    return amount
}
