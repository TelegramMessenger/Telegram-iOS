import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import StoryContainerScreen
import StoryStealthModeSheetScreen
import UndoUI

extension ChatListControllerImpl {
    func requestStealthMode(openStory: @escaping (@escaping (StoryContainerScreen) -> Void) -> Void) {
        let context = self.context
        
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState(),
            TelegramEngine.EngineData.Item.Configuration.App()
        )
        |> deliverOnMainQueue).start(next: { [weak self] config, appConfig in
            guard let self else {
                return
            }
            
            let timestamp = Int32(Date().timeIntervalSince1970)
            if let activeUntilTimestamp = config.stealthModeState.actualizedNow().activeUntilTimestamp, activeUntilTimestamp > timestamp {
                let remainingActiveSeconds = activeUntilTimestamp - timestamp
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                let text = presentationData.strings.Story_ToastStealthModeActiveText(timeIntervalString(strings: presentationData.strings, value: remainingActiveSeconds)).string
                let tooltipScreen = UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(title: presentationData.strings.Story_ToastStealthModeActiveTitle, text: text, cancel: "", destructive: false),
                    elevatedLayout: false,
                    animateInAsReplacement: false,
                    action: { _ in
                        return false
                    }
                )
                tooltipScreen.tag = "no_auto_dismiss"
                weak var tooltipScreenValue: UndoOverlayController? = tooltipScreen
                self.currentTooltipUpdateTimer?.invalidate()
                self.currentTooltipUpdateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    guard let tooltipScreenValue else {
                        self.currentTooltipUpdateTimer?.invalidate()
                        self.currentTooltipUpdateTimer = nil
                        return
                    }
                    
                    let timestamp = Int32(Date().timeIntervalSince1970)
                    let remainingActiveSeconds = max(1, activeUntilTimestamp - timestamp)
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                    let text = presentationData.strings.Story_ToastStealthModeActiveText(timeIntervalString(strings: presentationData.strings, value: remainingActiveSeconds)).string
                    tooltipScreenValue.content = .actionSucceeded(title: presentationData.strings.Story_ToastStealthModeActiveTitle, text: text, cancel: "", destructive: false)
                })
                
                openStory({ storyController in
                    storyController.presentExternalTooltip(tooltipScreen)
                })
                
                return
            }
            
            let pastPeriod: Int32
            let futurePeriod: Int32
            if let data = appConfig.data, let futurePeriodF = data["stories_stealth_future_period"] as? Double, let pastPeriodF = data["stories_stealth_past_period"] as? Double {
                futurePeriod = Int32(futurePeriodF)
                pastPeriod = Int32(pastPeriodF)
            } else {
                pastPeriod = 5 * 60
                futurePeriod = 25 * 60
            }
            
            let sheet = StoryStealthModeSheetScreen(
                context: context,
                mode: .control(external: true, cooldownUntilTimestamp: config.stealthModeState.actualizedNow().cooldownUntilTimestamp),
                forceDark: false,
                backwardDuration: pastPeriod,
                forwardDuration: futurePeriod,
                buttonAction: {
                    let _ = (context.engine.messages.enableStoryStealthMode()
                    |> deliverOnMainQueue).start(completed: {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                        let text = presentationData.strings.Story_ToastStealthModeActivatedText(timeIntervalString(strings: presentationData.strings, value: pastPeriod), timeIntervalString(strings: presentationData.strings, value: futurePeriod)).string
                        let tooltipScreen = UndoOverlayController(
                            presentationData: presentationData,
                            content: .actionSucceeded(title: presentationData.strings.Story_ToastStealthModeActivatedTitle, text: text, cancel: "", destructive: false),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in
                                return false
                            }
                        )
                        
                        openStory({ storyController in
                            storyController.presentExternalTooltip(tooltipScreen)
                        })
                        
                        HapticFeedback().success()
                    })
                }
            )
            self.push(sheet)
        })
    }
    
    func presentStealthModeUpgrade(action: @escaping () -> Void) {
        let context = self.context
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState(),
            TelegramEngine.EngineData.Item.Configuration.App()
        )
        |> deliverOnMainQueue).start(next: { [weak self] config, appConfig in
            guard let self else {
                return
            }
            
            let pastPeriod: Int32
            let futurePeriod: Int32
            if let data = appConfig.data, let futurePeriodF = data["stories_stealth_future_period"] as? Double, let pastPeriodF = data["stories_stealth_past_period"] as? Double {
                futurePeriod = Int32(futurePeriodF)
                pastPeriod = Int32(pastPeriodF)
            } else {
                pastPeriod = 5 * 60
                futurePeriod = 25 * 60
            }
            
            let sheet = StoryStealthModeSheetScreen(
                context: context,
                mode: .upgrade,
                forceDark: false,
                backwardDuration: pastPeriod,
                forwardDuration: futurePeriod,
                buttonAction: {
                    action()
                }
            )
            self.push(sheet)
        })
    }
    
    func presentUpgradeStoriesScreen() {
        let context = self.context
        var replaceImpl: ((ViewController) -> Void)?
        let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .stories, forceDark: false, action: {
            let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesStealthMode, forceDark: false, dismissed: nil)
            replaceImpl?(controller)
        }, dismissed: nil)
        replaceImpl = { [weak self, weak controller] c in
            controller?.dismiss(animated: true, completion: {
                guard let self else {
                    return
                }
                self.push(c)
            })
        }
        self.push(controller)
    }
}
