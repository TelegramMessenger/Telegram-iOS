import Foundation
import Display
import AsyncDisplayKit
import UIKit
import SwiftSignalKit

final class MapInputController: ViewController {
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    var mapInputNode: MapInputControllerNode {
        get {
            return super.displayNode as! MapInputControllerNode
        }
    }
    
    init() {
        super.init(navigationBarPresentationData: nil)
        
        self._ready.set(.single(true))
        
        /*self.statusBar.style = .White
        self.navigationBar.backgroundColor = UIColor(white: 0.0, alpha: 0.9)
        self.navigationBar.foregroundColor = UIColor.white()
        self.navigationBar.accentColor = UIColor.white()
        self.navigationBar.stripeColor = UIColor.black()*/
        
        self.navigationItem.title = "Location"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func cancelPressed() {
        self.mapInputNode.animateOut()
    }
    
    override func loadDisplayNode() {
        self.displayNode = MapInputControllerNode()
        
        self.mapInputNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.mapInputNode.animateIn()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.mapInputNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
