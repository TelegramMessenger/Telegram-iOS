import Foundation

private var telegramApiLogger: (String) -> Void = { _ in }

public func setTelegramApiLogger(_ f: @escaping (String) -> Void) {
    telegramApiLogger = f
}

func telegramApiLog(_ what: @autoclosure () -> String) {
    telegramApiLogger(what())
}
