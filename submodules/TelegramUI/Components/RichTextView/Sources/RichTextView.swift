import Foundation
import UIKit

public final class RichTextView: UIView {
    public final class Params: Equatable {
        let string: NSAttributedString
        let constrainedSize: CGSize
        
        public init(
            string: NSAttributedString,
            constrainedSize: CGSize
        ) {
            self.string = string
            self.constrainedSize = constrainedSize
        }
        
        public static func ==(lhs: Params, rhs: Params) -> Bool {
            if !lhs.string.isEqual(to: rhs.string) {
                return false
            }
            if lhs.constrainedSize != rhs.constrainedSize {
                return false
            }
            return true
        }
    }
    
    public final class LayoutData: Equatable {
        init() {
        }
        
        public static func ==(lhs: LayoutData, rhs: LayoutData) -> Bool {
            return true
        }
    }
    
    public final class AsyncResult {
        public let view: () -> RichTextView
        public let layoutData: LayoutData
        
        init(view: @escaping () -> RichTextView, layoutData: LayoutData) {
            self.view = view
            self.layoutData = layoutData
        }
    }
    
    private static func performLayout(params: Params) -> LayoutData {
        return LayoutData()
    }
    
    public static func updateAsync(_ view: RichTextView?) -> (Params) -> AsyncResult {
        return { params in
            let layoutData = performLayout(params: params)
            
            return AsyncResult(
                view: {
                    let view = view ?? RichTextView(frame: CGRect())
                    view.layoutData = layoutData
                    return view
                },
                layoutData: layoutData
            )
        }
    }
    
    private var layoutData: LayoutData?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func draw(_ rect: CGRect) {
        guard let layoutData = self.layoutData else {
            return
        }
        let _ = layoutData
    }
}
