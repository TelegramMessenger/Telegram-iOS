import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import TelegramAudio
import TelegramVoip

@available(iOS 12.0, *)
public final class DebugVoiceChatScreen: ViewController {
    @available(iOS 12.0, *)
    private final class Node: ViewControllerTracingNode {
        private let context: AccountContext
        private let audioSession: ManagedAudioSession
        
        private var callContext: DebugOngoingGroupCallContext?
        
        private var audioSessionDisposable: Disposable?
        private let audioSessionShouldBeActive = ValuePromise<Bool>(false, ignoreRepeated: true)
        private var audioSessionShouldBeActiveDisposable: Disposable?
        private var audioSessionControl: ManagedAudioSessionControl?
        
        init(
            context: AccountContext,
            audioSession: ManagedAudioSession
        ) {
            self.context = context
            self.audioSession = audioSession
            
            super.init()
            
            self.backgroundColor = .white
            
            /*self.audioSessionDisposable = self.audioSession.push(audioSessionType: .voiceCall, manualActivate: { [weak self] control in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.updateAudioSessionControl(control)
                    }
                }
            }, deactivate: {
                return Signal { subscriber in
                    Queue.mainQueue().async {
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
            }, availableOutputsChanged: { availableOutputs, currentOutput in
                Queue.mainQueue().async {
                }
            })*/
            
            self.audioSessionShouldBeActive.set(true)
            
            self.callContext = DebugOngoingGroupCallContext()
        }
        
        deinit {
            self.audioSessionDisposable?.dispose()
            self.audioSessionShouldBeActiveDisposable?.dispose()
        }
        
        private func updateAudioSessionControl(_ control: ManagedAudioSessionControl) {
            if self.audioSessionControl != nil {
                return
            }
            self.audioSessionControl = control
            
            self.audioSessionShouldBeActiveDisposable = (self.audioSessionShouldBeActive.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self {
                    if value {
                        if let audioSessionControl = strongSelf.audioSessionControl {
                            audioSessionControl.activate({ _ in
                                Queue.mainQueue().async {
                                    //strongSelf.audioSessionActive.set(.single(true))
                                }
                            })
                        } else {
                            //strongSelf.audioSessionActive.set(.single(false))
                        }
                    } else {
                        //strongSelf.audioSessionActive.set(.single(false))
                    }
                }
            })
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            
        }
    }
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    
    public init(
        context: AccountContext
    ) {
        self.context = context
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: context.sharedContext.currentPresentationData.with { $0 }))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(
            context: self.context,
            audioSession: self.context.sharedContext.mediaManager.audioSession
        )
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
