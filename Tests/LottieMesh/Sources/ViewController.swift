import Foundation
import UIKit

import LottieMeshSwift
import Postbox

public final class ViewController: UIViewController {
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        TempBox.initializeShared(basePath: NSTemporaryDirectory(), processType: "test", launchSpecificId: Int64.random(in: Int64.min ..< Int64.max))
        
        self.view.backgroundColor = .black
        
        //let path = Bundle.main.path(forResource: "SUPER Fire", ofType: "json")!
        let path = Bundle.main.path(forResource: "Fireworks", ofType: "json")!
        //let path = Bundle.main.path(forResource: "Cat", ofType: "json")!
        /*for _ in 0 ..< 100 {
            let _ = generateMeshAnimation(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!
        }*/
        
        if #available(iOS 13.0, *) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let animationFile = generateMeshAnimation(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!
            print("Time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)")
            let buffer = MeshReadBuffer(data: try! Data(contentsOf: URL(fileURLWithPath: animationFile.path)))
            let animation = MeshAnimation.read(buffer: buffer)
            
            let renderer = MeshRenderer(wireframe: false)!
            
            renderer.frame = CGRect(origin: CGPoint(x: 0.0, y: 50.0), size: CGSize(width: 300.0, height: 300.0))
            self.view.addSubview(renderer)
            
            renderer.add(mesh: animation, offset: CGPoint(), loop: true)
        }
    }
}
