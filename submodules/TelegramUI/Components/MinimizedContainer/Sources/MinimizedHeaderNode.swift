import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

final class MinimizedHeaderNode: ASDisplayNode {
    var theme: NavigationControllerTheme {
        didSet {
            self.minimizedBackgroundNode.backgroundColor = self.theme.navigationBar.opaqueBackgroundColor
            self.minimizedCloseButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Close"), color: self.theme.navigationBar.primaryTextColor), for: .normal)
        }
    }
    let strings: PresentationStrings
    
    private let minimizedBackgroundNode: ASDisplayNode
    private let minimizedTitleNode: ImmediateTextNode
    private let minimizedCloseButton: HighlightableButtonNode
    private var minimizedTitleDisposable: Disposable?
    
    private var _controllers: [Weak<ViewController>] = []
    var controllers: [ViewController] {
        get {
            return self._controllers.compactMap { $0.value }
        }
        set {
            if !newValue.isEmpty {
                if newValue.count != self.controllers.count {
                    self._controllers = newValue.map { Weak($0) }
                    
                    self.minimizedTitleDisposable?.dispose()
                    self.minimizedTitleDisposable = nil
                    
                    var signals: [Signal<String?, NoError>] = []
                    for controller in newValue {
                        signals.append(controller.titleSignal)
                    }
                    
                    self.minimizedTitleDisposable = (combineLatest(signals)
                    |> deliverOnMainQueue).start(next: { [weak self] titles in
                        guard let self else {
                            return
                        }
                        let titles = titles.compactMap { $0 }
                        if titles.count == 1, let title = titles.first {
                            self.title = title
                        } else if let title = titles.last {
                            let othersString = self.strings.WebApp_MinimizedTitle_Others(Int32(titles.count - 1))
                            self.title = self.strings.WebApp_MinimizedTitleFormat(title, othersString).string
                        } else {
                            self.title = nil
                        }
                    })
                }
            } else {
                self.minimizedTitleDisposable?.dispose()
                self.minimizedTitleDisposable = nil
            }
        }
    }
    
    var title: String? {
        didSet {
            if let (size, insets, isExpanded) = self.validLayout {
                self.update(size: size, insets: insets, isExpanded: isExpanded, transition: .immediate)
            }
        }
    }
    
    var requestClose: () -> Void = {}
    var requestMaximize: () -> Void = {}
    
    private var validLayout: (CGSize, UIEdgeInsets, Bool)?
    
    init(theme: NavigationControllerTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.minimizedBackgroundNode = ASDisplayNode()
        self.minimizedBackgroundNode.cornerRadius = 10.0
        self.minimizedBackgroundNode.clipsToBounds = true
        self.minimizedBackgroundNode.backgroundColor = theme.navigationBar.opaqueBackgroundColor
        if #available(iOS 11.0, *) {
            self.minimizedBackgroundNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
                
        self.minimizedTitleNode = ImmediateTextNode()
        
        self.minimizedCloseButton = HighlightableButtonNode()
        self.minimizedCloseButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Instant View/Close"), color: self.theme.navigationBar.primaryTextColor), for: .normal)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.minimizedBackgroundNode)
        self.minimizedBackgroundNode.addSubnode(self.minimizedTitleNode)
        self.minimizedBackgroundNode.addSubnode(self.minimizedCloseButton)
        
        self.minimizedCloseButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
        
        applySmoothRoundedCorners(self.minimizedBackgroundNode.layer)
    }
    
    deinit {
        self.minimizedTitleDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.minimizedBackgroundNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.maximizeTapGesture(_:))))
    }
    
    @objc private func closePressed() {
        self.requestClose()
    }
    
    @objc private func maximizeTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let location = recognizer.location(in: self.view)
            if location.x < 48.0 {
                self.requestClose()
            } else {
                self.requestMaximize()
            }
        }
    }
    
    func update(size: CGSize, insets: UIEdgeInsets, isExpanded: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets, isExpanded)
                
        let headerHeight: CGFloat = 44.0
        var titleSideInset: CGFloat = 56.0
        if !isExpanded {
            titleSideInset += insets.left
        }
        
        self.minimizedTitleNode.attributedText = NSAttributedString(string: self.title ?? "", font: Font.bold(17.0), textColor: self.theme.navigationBar.primaryTextColor)
        
        let titleSize = self.minimizedTitleNode.updateLayout(CGSize(width: size.width - titleSideInset * 2.0, height: headerHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((headerHeight - titleSize.height) / 2.0)), size: titleSize)
        self.minimizedTitleNode.bounds = CGRect(origin: .zero, size: titleFrame.size)
        transition.updatePosition(node: self.minimizedTitleNode, position: titleFrame.center)
        transition.updateFrame(node: self.minimizedCloseButton, frame: CGRect(origin: CGPoint(x: isExpanded ? 0.0 : insets.left, y: 0.0), size: CGSize(width: 44.0, height: 44.0)))
        
        transition.updateFrame(node: self.minimizedBackgroundNode, frame: CGRect(origin: .zero, size: CGSize(width: size.width, height: 243.0)))
    }
}
