import Foundation
import Postbox
import SafariServices
import Display

enum PeerUrlParameter {
    case botStart(String)
    case groupBotStart(String)
}

enum ParsedUrl {
    case external(String)
    case peerId(PeerId)
    case peerName(String, [PeerUrlParameter])
}

func parseUrl(_ url: String) -> ParsedUrl {
    return .external(url)
}

private final class SafariLegacyPresentedController: LegacyPresentedController, SFSafariViewControllerDelegate {
    @available(iOSApplicationExtension 9.0, *)
    init(legacyController: SFSafariViewController) {
        super.init(legacyController: legacyController, presentation: .custom)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @available(iOSApplicationExtension 9.0, *)
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        self.dismiss()
    }
}

func openUrl(_ url: String, in window: Window) {
    if #available(iOSApplicationExtension 9.0, *) {
        if let url = URL(string: url) {
            let controller = SFSafariViewController(url: url)
            //window.rootViewController?.present(controller, animated: true, completion: nil)
            let legacyController = SafariLegacyPresentedController(legacyController: controller)
            controller.delegate = legacyController
            window.present(legacyController)
        }
    } else {
    }
}
