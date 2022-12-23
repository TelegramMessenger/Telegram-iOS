import NGCore
import UIKit

public extension AlertState {
    static func error(_ error: Error, onOk: (() -> Void)? = nil) -> AlertState {
        return AlertState(
            description: error.localizedDescription,
            image: UIImage(named: "ng.error.alert"),
            actions: [
                .init(
                    title: ngLocalized("Nicegram.Alert.Ok").uppercased(),
                    style: .preferred,
                    handler: onOk
                )
            ]
        )
    }
}

public extension AlertState {
    static func needLoginWithTelegram(onConfirm: @escaping () -> Void) -> AlertState {
        return AlertState(
            title: ngLocalized("Alert.TelegramLogin.Title"),
            description: ngLocalized("Alert.TelegramLogin.Desc"),
            image: UIImage(named: "ng.alert.telegramlogin"),
            actions: [
                .init(
                    title: ngLocalized("Alert.TelegramLogin.PositiveBtn"),
                    style: .gradientAction,
                    handler: onConfirm
                ),
                .init(
                    title: ngLocalized("Alert.TelegramLogin.NegativeBtn"),
                    style: .cancel
                ),
            ]
        )
    }
}
