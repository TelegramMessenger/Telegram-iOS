import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import PlainButtonComponent

private final class WeakController {
    private weak var _value: MinimizableController?

    public var value: MinimizableController? {
        return self._value
    }

    public init(_ value: MinimizableController) {
        self._value = value
    }
}

private func makePanelPath(in rect: CGRect, topRadius: CGFloat, bottomRadius: CGFloat) -> UIBezierPath {
    let maxTop = min(topRadius, rect.width * 0.5, rect.height * 0.5)
    let maxBottom = bottomRadius - 13.0 //min(bottomRadius, rect.width * 0.5, rect.height * 0.5)

    let path = UIBezierPath()

    path.move(to: CGPoint(x: rect.minX, y: rect.minY + maxTop))
    path.addArc(withCenter: CGPoint(x: rect.minX + maxTop, y: rect.minY + maxTop),
                radius: maxTop,
                startAngle: .pi,
                endAngle: 1.5 * .pi,
                clockwise: true)

    path.addLine(to: CGPoint(x: rect.maxX - maxTop, y: rect.minY))
    path.addArc(withCenter: CGPoint(x: rect.maxX - maxTop, y: rect.minY + maxTop),
                radius: maxTop,
                startAngle: 1.5 * .pi,
                endAngle: 0,
                clockwise: true)

    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - maxBottom))
    path.addArc(withCenter: CGPoint(x: rect.maxX - maxBottom, y: rect.maxY - maxBottom),
                radius: maxBottom,
                startAngle: 0,
                endAngle: 0.5 * .pi,
                clockwise: true)

    path.addLine(to: CGPoint(x: rect.minX + maxBottom, y: rect.maxY))
    path.addArc(withCenter: CGPoint(x: rect.minX + maxBottom, y: rect.maxY - maxBottom),
                radius: maxBottom,
                startAngle: 0.5 * .pi,
                endAngle: .pi,
                clockwise: true)

    path.close()
    return path
}

private class BackgroundView: UIView {
    static override var layerClass: AnyClass {
        return SimpleShapeLayer.self
    }
    
    var shapeLayer: SimpleShapeLayer {
        return self.layer as! SimpleShapeLayer
    }
    
    private var params: (size: CGSize, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat)?
    
    func update(size: CGSize, color: UIColor, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat, transition: ComponentTransition) {
        if self.params?.size != size, self.params?.topCornerRadius != topCornerRadius, self.params?.bottomCornerRadius != bottomCornerRadius {
            self.params = (size, topCornerRadius, bottomCornerRadius)
            
            let inset: CGFloat = 5.0 - 0.333
            let width = size.width - inset * 2.0
            let path = makePanelPath(in: CGRect(origin: CGPoint(x: inset, y: 0.0), size: CGSize(width: width, height: size.height)), topRadius: topCornerRadius, bottomRadius: bottomCornerRadius)
            transition.setShapeLayerPath(layer: self.shapeLayer, path: path.cgPath)
        }
        transition.setShapeLayerFillColor(layer: self.shapeLayer, color: UIColor.gray)
    }
}

final class MinimizedHeaderNode: ASDisplayNode {
    var theme: NavigationControllerTheme {
        didSet {
            self.backgroundView.backgroundColor = self.theme.navigationBar.opaqueBackgroundColor
            self.progressView.backgroundColor = self.theme.navigationBar.primaryTextColor.withAlphaComponent(0.06)
            self.iconView.tintColor = self.theme.navigationBar.primaryTextColor
        }
    }
    let strings: PresentationStrings
    
    //private let backgroundView = BackgroundView()
    private let backgroundView = UIView()
    private let progressView = UIView()
    private var iconView = UIImageView()
    private let titleLabel = ComponentView<Empty>()
    private let closeButton = ComponentView<Empty>()
    private var titleDisposable: Disposable?
    
    private var closeIcon: UIImage?
    
    private var _controllers: [WeakController] = []
    var controllers: [MinimizableController] {
        get {
            return self._controllers.compactMap { $0.value }
        }
        set {
            if !newValue.isEmpty {
                if self.controllers.count == 1, let icon = self.controllers.first?.minimizedIcon {
                    self.icon = icon
                } else {
                    self.icon = nil
                }
                
                if self.controllers.count == 1, let progress = self.controllers.first?.minimizedProgress {
                    self.progress = progress
                } else {
                    self.progress = nil
                }
                
                if newValue.count != self.controllers.count {
                    self._controllers = newValue.map { WeakController($0) }
                    
                    self.titleDisposable?.dispose()
                    self.titleDisposable = nil
                    
                    var signals: [Signal<String?, NoError>] = []
                    for controller in newValue {
                        signals.append(controller.titleSignal)
                    }
                    
                    self.titleDisposable = (combineLatest(signals)
                    |> deliverOnMainQueue).start(next: { [weak self] titles in
                        guard let self else {
                            return
                        }
                        let titles = titles.compactMap { $0 }.filter { !$0.isEmpty }
                        if titles.count == 1, let title = titles.first {
                            self.title = title
                        } else if let title = titles.last {
                            var trimmedTitle = title
                            if trimmedTitle.count > 20 {
                                trimmedTitle = "\(trimmedTitle.prefix(20).trimmingCharacters(in: .whitespacesAndNewlines))\u{2026}"
                            }
                            let othersString = self.strings.WebApp_MinimizedTitle_Others(Int32(titles.count - 1))
                            self.title = self.strings.WebApp_MinimizedTitleFormat(trimmedTitle, othersString).string
                        } else {
                            self.title = nil
                        }
                    })
                }
            } else {
                self.icon = nil
                
                self.titleDisposable?.dispose()
                self.titleDisposable = nil
            }
        }
    }
    
    var icon: UIImage? {
        didSet {
            self.iconView.image = self.icon
            if let (size, insets, isExpanded) = self.validLayout {
                self.update(size: size, insets: insets, isExpanded: isExpanded, transition: .immediate)
            }
        }
    }
    
    var progress: Float? {
        didSet {
            if let (size, insets, isExpanded) = self.validLayout {
                self.update(size: size, insets: insets, isExpanded: isExpanded, transition: .immediate)
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
        
        self.backgroundView.clipsToBounds = true
        self.backgroundView.backgroundColor = theme.navigationBar.opaqueBackgroundColor
        self.backgroundView.layer.cornerRadius = 25.0
        if #available(iOS 11.0, *) {
            self.backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        
        self.progressView.backgroundColor = self.theme.navigationBar.primaryTextColor.withAlphaComponent(0.06)
        
        self.iconView.contentMode = .scaleAspectFit
        self.iconView.clipsToBounds = true
        self.iconView.layer.cornerRadius = 2.5
        self.iconView.tintColor = theme.navigationBar.primaryTextColor
                                
        super.init()
        
        self.clipsToBounds = true
        
        self.view.addSubview(self.backgroundView)
        self.backgroundView.addSubview(self.progressView)
        self.backgroundView.addSubview(self.iconView)
                
        applySmoothRoundedCorners(self.backgroundView.layer)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.maximizeTapGesture(_:))))
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
                        
        if self.closeIcon == nil {
            self.closeIcon = generateCloseButtonImage()?.withRenderingMode(.alwaysTemplate)
        }
        
        let headerHeight: CGFloat = 56.0
        let titleSpacing: CGFloat = 6.0
        var titleSideInset: CGFloat = 56.0
        if !isExpanded {
            titleSideInset += insets.left
        }
        
        let iconSize = CGSize(width: 20.0, height: 20.0)
                        
        let titleSize = self.titleLabel.update(
            transition: .immediate,
            component: AnyComponent(
                MultilineTextComponent(text: .plain(NSAttributedString(string: self.title ?? "", font: Font.bold(17.0), textColor: self.theme.navigationBar.primaryTextColor)), horizontalAlignment: .center, maximumNumberOfLines: 1)
            ),
            environment: {},
            containerSize: CGSize(width: size.width - titleSideInset * 2.0, height: headerHeight)
        )
        
        var totalWidth = titleSize.width
        if isExpanded, let icon = self.icon {
            self.iconView.image = icon
            totalWidth += iconSize.width + titleSpacing
        } else {
            self.iconView.image = nil
        }
        
        let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - totalWidth) / 2.0), y: floorToScreenPixels((headerHeight - iconSize.height) / 2.0)), size: iconSize)
        self.iconView.frame = iconFrame
        
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - totalWidth) / 2.0) + totalWidth - titleSize.width, y: floorToScreenPixels((headerHeight - titleSize.height) / 2.0)), size: titleSize)
        if let view = self.titleLabel.view {
            if view.superview == nil {
                self.backgroundView.addSubview(view)
            }
            
            view.bounds = CGRect(origin: .zero, size: titleFrame.size)
            transition.updatePosition(layer: view.layer, position: titleFrame.center)
        }
            
        let _ = self.closeButton.update(
            transition: .immediate,
            component: AnyComponent(
                PlainButtonComponent(
                    content: AnyComponent(
                        Image(image: self.closeIcon, tintColor: self.theme.navigationBar.primaryTextColor, size: CGSize(width: 14.0, height: 14.0))
                    ),
                    effectAlignment: .center,
                    minSize: CGSize(width: 56.0, height: 56.0),
                    action: { [weak self] in
                        self?.requestClose()
                    },
                    animateScale: false
                )
            ),
            environment: {},
            containerSize: CGSize(width: 56.0, height: 56.0)
        )
        let closeButtonFrame = CGRect(origin: CGPoint(x: isExpanded ? 0.0 : insets.left, y: 0.0), size: CGSize(width: 56.0, height: 56.0))
        if let view = self.closeButton.view {
            if view.superview == nil {
                self.backgroundView.addSubview(view)
            }
            
            transition.updateFrame(view: view, frame: closeButtonFrame)
        }
        
        transition.updateFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: CGSize(width: size.width, height: 246.0)))
        
        //self.backgroundView.update(size: CGSize(width: size.width, height: 243.0), color: self.theme.navigationBar.opaqueBackgroundColor, topCornerRadius: 25.0, bottomCornerRadius: 62.0, transition: .immediate)
        
        transition.updateAlpha(layer: self.progressView.layer, alpha: isExpanded && self.progress != nil ? 1.0 : 0.0)
        if let progress = self.progress {
            self.progressView.frame = CGRect(origin: .zero, size: CGSize(width: size.width * CGFloat(progress), height: 246.0))
        }
    }
}

private func generateCloseButtonImage() -> UIImage? {
    return generateImage(CGSize(width: 14.0, height: 14.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(UIColor.black.cgColor)
        
        let inset: CGFloat = 1.0 + UIScreenPixel
        
        context.move(to: CGPoint(x: inset, y: inset))
        context.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
        context.strokePath()
        
        context.move(to: CGPoint(x: size.width - inset, y: inset))
        context.addLine(to: CGPoint(x: inset, y: size.height - inset))
        context.strokePath()
    })
}
