import Foundation
import Display
import TelegramPresentationData
import SwiftSignalKit

private func timeoutValue(value: Int32) -> String {
    let timestamp = Int32(Date().timeIntervalSince1970)
    let seconds = max(0, value - timestamp)
    return stringForDuration(seconds)
}

final class ChatSlowmodeHintController: TooltipController {
    private let strings: PresentationStrings
    private let activeUntilTimestamp: Int32
    
    private var timer: SwiftSignalKit.Timer?
    
    init(strings: PresentationStrings, activeUntilTimestamp: Int32) {
        self.strings = strings
        self.activeUntilTimestamp = activeUntilTimestamp
        let text = strings.Chat_SlowmodeTooltip(timeoutValue(value: activeUntilTimestamp)).0
        super.init(content: .text(text), timeout: 2.0, dismissByTapOutside: true)
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
            let text = strongSelf.strings.Chat_SlowmodeTooltip(timeoutValue(value: strongSelf.activeUntilTimestamp)).0
            strongSelf.updateContent(.text(text), animated: false, extendTimer: false)
        }, queue: .mainQueue())
        self.timer = timer
        timer.start()
    }
}
