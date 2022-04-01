import Foundation
import UIKit
import Display
import WebKit
import SwiftSignalKit

private let findFixedPositionClasses = """
function findFixedPositionClasses() {
    var elems = document.body.getElementsByTagName("*");
    var len = elems.length

    var result = []
    var j = 0;
    for (var i = 0; i < len; i++) {
        if ((window.getComputedStyle(elems[i],null).getPropertyValue('position') == 'fixed') && (window.getComputedStyle(elems[i],null).getPropertyValue('bottom') == '0px')) {
            result[j] = elems[i].className;
            j++;
        }
    }
    return result;
}
findFixedPositionClasses();
"""

private func findFixedPositionViews(webView: WKWebView, classes: [String]) -> [(String, UIView)] {
    if let contentView = webView.scrollView.subviews.first {
        func recursiveSearch(_ view: UIView) -> [(String, UIView)] {
            var result: [(String, UIView)] = []
            
            let description = view.description
            if description.contains("class='") {
                for className in classes {
                    if description.contains(className) {
                        result.append((className, view))
                        break
                    }
                }
            }
            
            for subview in view.subviews {
                result.append(contentsOf: recursiveSearch(subview))
            }
            
            return result
        }
        
        return recursiveSearch(contentView)
    } else {
        return []
    }
}

final class WebAppWebView: WKWebView {
    private var fixedPositionClasses: [String] = []
    private var currentFixedViews: [(String, UIView, UIView)] = []
    
    private var timer: SwiftSignalKit.Timer?
    
    deinit {
        self.timer?.invalidate()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if self.timer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.evaluateJavaScript(findFixedPositionClasses, completionHandler: { [weak self] result, _ in
                    if let result = result {
                        Queue.mainQueue().async {
                            self?.fixedPositionClasses = (result as? [String]) ?? []
                        }
                    }
                })
            }, queue: Queue.mainQueue())
            timer.start()
            self.timer = timer
        }
    }
    
    
    
    func updateFrame(frame: CGRect, panning: Bool, transition: ContainedViewLayoutTransition) {
        let reset = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            for (_, view, snapshotView) in strongSelf.currentFixedViews {
                view.isHidden = false
                snapshotView.removeFromSuperview()
            }
            strongSelf.currentFixedViews = []
        }
        
        let update = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            for (_, view, snapshotView) in strongSelf.currentFixedViews {
                view.isHidden = true
                
                var snapshotFrame = view.frame
                snapshotFrame.origin.y = frame.height - snapshotFrame.height
                transition.updateFrame(view: snapshotView, frame: snapshotFrame)
            }
        }
        
        if panning {
            let fixedPositionViews = findFixedPositionViews(webView: self, classes: self.fixedPositionClasses)
            if fixedPositionViews.count != self.currentFixedViews.count {
                var existing: [String: (UIView, UIView)] = [:]
                for (className, originalView, snapshotView) in self.currentFixedViews {
                    existing[className] = (originalView, snapshotView)
                }
                
                var updatedFixedViews: [(String, UIView, UIView)] = []
                for (className, view) in fixedPositionViews {
                    if let (_, existingSnapshotView) = existing[className] {
                        updatedFixedViews.append((className, view, existingSnapshotView))
                        existing[className] = nil
                    } else if let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                        updatedFixedViews.append((className, view, snapshotView))
                        self.addSubview(snapshotView)
                    }
                }
                
                for (_, originalAndSnapshotView) in existing {
                    originalAndSnapshotView.0.isHidden = false
                    originalAndSnapshotView.1.removeFromSuperview()
                }
                
                self.currentFixedViews = updatedFixedViews
            }
            transition.updateFrame(view: self, frame: frame)
            update()
        } else {
            update()
            transition.updateFrame(view: self, frame: frame, completion: { _ in
                reset()
            })
        }
        
    }
}
