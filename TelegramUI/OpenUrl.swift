import Foundation
import Display
import SafariServices

func openExternalUrl(url: String, presentationData: PresentationData, applicationContext: TelegramApplicationContext, navigationController: NavigationController?) {
    if url.lowercased().hasPrefix("tel:") {
        applicationContext.applicationBindings.openUrl(url)
        return
    }
    
    var parsedUrlValue: URL?
    if let parsed = URL(string: url) {
        parsedUrlValue = parsed
    }
    if let parsed = parsedUrlValue, parsed.scheme == nil {
        parsedUrlValue = URL(string: "https://" + parsed.absoluteString)
    }
    
    guard let parsedUrl = parsedUrlValue else {
        return
    }
    
    if parsedUrl.scheme == "mailto" {
        applicationContext.applicationBindings.openUrl(url)
        return
    }
    
    if let host = parsedUrl.host?.lowercased() {
        if host == "itunes.apple.com" {
            if applicationContext.applicationBindings.canOpenUrl(parsedUrl.absoluteString) {
                applicationContext.applicationBindings.openUrl(url)
                return
            }
        }
        if host == "twitter.com" || host == "mobile.twitter.com" {
            if applicationContext.applicationBindings.canOpenUrl("twitter://status") {
                applicationContext.applicationBindings.openUrl(url)
                return
            }
        } else if host == "instagram.com" {
            if applicationContext.applicationBindings.canOpenUrl("instagram://photo") {
                applicationContext.applicationBindings.openUrl(url)
                return
            }
        }
    }
    
    if parsedUrl.scheme == "http" || parsedUrl.scheme == "https" {
        if #available(iOSApplicationExtension 9.0, *) {
            if let window = navigationController?.view.window {
                let controller = SFSafariViewController(url: parsedUrl)
                if #available(iOSApplicationExtension 10.0, *) {
                    controller.preferredBarTintColor = presentationData.theme.rootController.navigationBar.backgroundColor
                    controller.preferredControlTintColor = presentationData.theme.rootController.navigationBar.accentTextColor
                }
                window.rootViewController?.present(controller, animated: true)
            } else {
                applicationContext.applicationBindings.openUrl(parsedUrl.absoluteString)
            }
        } else {
            applicationContext.applicationBindings.openUrl(url)
        }
    } else {
        applicationContext.applicationBindings.openUrl(url)
    }
}
