import Foundation
import Display
import TelegramPresentationData
import SwiftSignalKit
import TelegramStringFormatting
import ChatPresentationInterfaceState

private func timeoutValue(strings: PresentationStrings, slowmodeState: ChatSlowmodeState) -> String {
    switch slowmodeState.variant {
    case .pendingMessages:
        return strings.Chat_SlowmodeTooltipPending
    case let .timestamp(untilTimestamp):
        let timestamp = Int32(Date().timeIntervalSince1970)
        let seconds = max(0, untilTimestamp - timestamp)
        return strings.Chat_SlowmodeTooltip(stringForDuration(seconds)).string
    }
}

final class ChatSlowmodeHintController: TooltipController {
    private let strings: PresentationStrings
    private let slowmodeState: ChatSlowmodeState
    
    private var timer: SwiftSignalKit.Timer?
    
    init(presentationData: PresentationData, slowmodeState: ChatSlowmodeState) {
        self.strings = presentationData.strings
        self.slowmodeState = slowmodeState
        super.init(content: .text(timeoutValue(strings: presentationData.strings, slowmodeState: slowmodeState)), baseFontSize: presentationData.listsFontSize.baseDisplaySize, timeout: 2.0, dismissByTapOutside: false, dismissByTapOutsideSource: true)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateContent(.text(timeoutValue(strings: strongSelf.strings, slowmodeState: strongSelf.slowmodeState)), animated: false, extendTimer: false)
        }, queue: .mainQueue())
        self.timer = timer
        timer.start()
    }
}
