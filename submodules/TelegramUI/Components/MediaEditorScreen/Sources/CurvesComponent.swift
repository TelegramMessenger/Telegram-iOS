import Foundation
import UIKit
import Display
import ComponentFlow
import LegacyComponents
import MediaEditor
import MultilineTextComponent
import TelegramPresentationData

private class HistogramView: UIView {
    private var size: CGSize?
    private var histogramBins: MediaEditorHistogram.HistogramBins?
    private var color: UIColor?
    
    private let shapeLayer = SimpleShapeLayer()
    
    var dataPointsUpdated: (([Float]) -> Void)?
    
    init() {
        super.init(frame: .zero)
        
        self.layer.addSublayer(self.shapeLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateSize(size: CGSize, histogramBins: MediaEditorHistogram.HistogramBins?, color: UIColor, transition: Transition) {
        guard self.size != size || self.color != color || self.histogramBins != histogramBins else {
            return
        }
        self.size = size
        self.histogramBins = histogramBins
        self.color = color
        self.update(transition: transition)
    }
    
    func update(transition: Transition) {
        guard let size = self.size, let histogramBins = self.histogramBins, histogramBins.count > 0, let color = self.color else {
            self.shapeLayer.path = nil
            return
        }
        
        transition.setShapeLayerFillColor(layer: self.shapeLayer, color: color)
        
        let (path, _) = curveThroughPoints(
            count: histogramBins.count,
            valueAtIndex: { index in
                return histogramBins.valueAtIndex(index, mirrored: true)
            },
            positionAtIndex: { index, step in
                return CGFloat(index) * step
            },
            size: size,
            type: .filled,
            granularity: 200,
            floor: true
        )
        
        transition.setShapeLayerPath(layer: self.shapeLayer, path: path.cgPath)
    }
}

enum CurvesSection {
    case all
    case red
    case green
    case blue
}

class CurvesInternalState {
    var section: CurvesSection = .all
}

final class CurvesComponent: Component {
    typealias EnvironmentType = Empty
    
    let strings: PresentationStrings
    let histogram: MediaEditorHistogram?
    let internalState: CurvesInternalState
    
    init(
        strings: PresentationStrings,
        histogram: MediaEditorHistogram?,
        internalState: CurvesInternalState
    ) {
        self.strings = strings
        self.histogram = histogram
        self.internalState = internalState
    }
    
    static func ==(lhs: CurvesComponent, rhs: CurvesComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.histogram != rhs.histogram {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let internalState: CurvesInternalState
        
        init(internalState: CurvesInternalState) {
            self.internalState = internalState
        }
        
        var section: CurvesSection {
            get {
                return self.internalState.section
            }
            set {
                self.internalState.section = newValue
            }
        }
    }
    
    func makeState() -> State {
        return State(internalState: self.internalState)
    }
    
    final class View: UIView {
        private var allButton = ComponentView<Empty>()
        private var redButton = ComponentView<Empty>()
        private var greenButton = ComponentView<Empty>()
        private var blueButton = ComponentView<Empty>()
        private let histogramView = HistogramView()
        
        private var component: CurvesComponent?
        private weak var state: State?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.histogramView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: CurvesComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
                    
            let topInset: CGFloat = 11.0
            let allButtonSize = self.allButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            Text(
                                text: component.strings.Story_Editor_Curves_All,
                                font: Font.regular(14.0),
                                color: state.section == .all ? .white : UIColor(rgb: 0x808080)
                            )
                        ),
                        action: { [weak state] in
                            state?.section = .all
                            state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let allButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(availableSize.width / 5.0 - allButtonSize.width / 2.0), y: topInset), size: allButtonSize)
            if let view = self.allButton.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: allButtonFrame)
            }
            
            let redButtonSize = self.redButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            Text(
                                text: component.strings.Story_Editor_Curves_Red,
                                font: Font.regular(14.0),
                                color: state.section == .red ? .white : UIColor(rgb: 0x808080)
                            )
                        ),
                        action: { [weak state] in
                            state?.section = .red
                            state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let redButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(availableSize.width / 5.0 * 2.0 - redButtonSize.width / 2.0), y: topInset), size: redButtonSize)
            if let view = self.redButton.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: redButtonFrame)
            }
            
            let greenButtonSize = self.greenButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            Text(
                                text: component.strings.Story_Editor_Curves_Green,
                                font: Font.regular(14.0),
                                color: state.section == .green ? .white : UIColor(rgb: 0x808080)
                            )
                        ),
                        action: { [weak state] in
                            state?.section = .green
                            state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let greenButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(availableSize.width / 5.0 * 3.0 - greenButtonSize.width / 2.0), y: topInset), size: greenButtonSize)
            if let view = self.greenButton.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: greenButtonFrame)
            }
            
            let blueButtonSize = self.blueButton.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            Text(
                                text: component.strings.Story_Editor_Curves_Blue,
                                font: Font.regular(14.0),
                                color: state.section == .blue ? .white : UIColor(rgb: 0x808080)
                            )
                        ),
                        action: { [weak state] in
                            state?.section = .blue
                            state?.updated(transition: Transition(animation: .curve(duration: 0.2, curve: .easeInOut)))
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let blueButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(availableSize.width / 5.0 * 4.0 - blueButtonSize.width / 2.0), y: topInset), size: blueButtonSize)
            if let view = self.blueButton.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: blueButtonFrame)
            }
            
            let histogramHeight: CGFloat = 85.0
            let histogramColor: UIColor
            let histogramBins: MediaEditorHistogram.HistogramBins?
            switch state.section {
            case .all:
                histogramColor = .white
                histogramBins = component.histogram?.luminance
            case .red:
                histogramColor = UIColor(rgb: 0xed3d4c)
                histogramBins = component.histogram?.red
            case .green:
                histogramColor = UIColor(rgb: 0x10ee9d)
                histogramBins = component.histogram?.green
            case .blue:
                histogramColor = UIColor(rgb: 0x3377fb)
                histogramBins = component.histogram?.blue
            }
            let histogramSize = CGSize(width: availableSize.width, height: histogramHeight)
            let verticalSpacing: CGFloat = 3.0
            
            self.histogramView.updateSize(size: histogramSize, histogramBins: histogramBins, color: histogramColor, transition: transition)
            transition.setFrame(view: self.histogramView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + allButtonSize.height + verticalSpacing), size: histogramSize))
            return CGSize(width: availableSize.width, height: topInset + allButtonSize.height + verticalSpacing + histogramHeight)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class CurvesScreenComponent: Component {
    typealias EnvironmentType = Empty
    
    let value: CurvesValue
    let section: CurvesSection
    let valueUpdated: (CurvesValue) -> Void
    
    init(
        value: CurvesValue,
        section: CurvesSection,
        valueUpdated: @escaping (CurvesValue) -> Void
        
    ) {
        self.value = value
        self.section = section
        self.valueUpdated = valueUpdated
    }
    
    static func ==(lhs: CurvesScreenComponent, rhs: CurvesScreenComponent) -> Bool {
        if lhs.value != rhs.value {
            return false
        }
        if lhs.section != rhs.section {
            return false
        }
        return true
    }
        
    final class View: UIView {
        enum Field {
            case blacks
            case shadows
            case midtones
            case highlights
            case whites
        }
        
        private var blacks = ComponentView<Empty>()
        private var shadows = ComponentView<Empty>()
        private var midtones = ComponentView<Empty>()
        private var highlights = ComponentView<Empty>()
        private let whites = ComponentView<Empty>()
        
        private let line1 = SimpleLayer()
        private let line2 = SimpleLayer()
        private let line3 = SimpleLayer()
        private let line4 = SimpleLayer()
        
        private let curveContainer = SimpleLayer()
        private let guideLayer = SimpleShapeLayer()
        private let curveLayer = SimpleShapeLayer()
        
        private var component: CurvesScreenComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.line1)
            self.layer.addSublayer(self.line2)
            self.layer.addSublayer(self.line3)
            self.layer.addSublayer(self.line4)
            
            self.layer.addSublayer(self.curveContainer)
            self.curveContainer.addSublayer(self.guideLayer)
            self.curveContainer.addSublayer(self.curveLayer)
            
            self.curveContainer.masksToBounds = true
            self.curveContainer.cornerRadius = 12.0
            if #available(iOS 13.0, *) {
                self.curveContainer.cornerCurve = .continuous
            }
            
            self.line1.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
            self.line2.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
            self.line3.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
            self.line4.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
            
            self.guideLayer.lineWidth = 1.5
            self.guideLayer.lineDashPattern = [7, 4]
            self.guideLayer.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
            
            self.curveLayer.lineWidth = 2.0
            self.curveLayer.fillColor = UIColor.clear.cgColor
            
            let allLayers = [
                self.line1,
                self.line2,
                self.line3,
                self.line4,
                self.guideLayer,
            ]
            
            for layer in allLayers {
                layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                layer.shadowRadius = 1.5
                layer.shadowColor = UIColor.black.cgColor
                layer.shadowOpacity = 0.3
            }
            
            self.curveLayer.shadowOffset = CGSize(width: 0.0, height: 0.0)
            self.curveLayer.shadowRadius = 2.0
            self.curveLayer.shadowColor = UIColor.black.cgColor
            self.curveLayer.shadowOpacity = 0.16
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.addGestureRecognizer(panGestureRecognizer)
            
            let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleDoubleTap(_:)))
            doubleTapGestureRecognizer.numberOfTapsRequired = 2
            self.addGestureRecognizer(doubleTapGestureRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        private var selectedField: Field?
        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            
            let fieldWidth = self.frame.width / 5.0
            
            switch gestureRecognizer.state {
            case .began:
                let location = gestureRecognizer.location(in: gestureRecognizer.view).x
                let index = floor(location / fieldWidth)
                switch index {
                case 0:
                    self.selectedField = .blacks
                case 1:
                    self.selectedField = .shadows
                case 2:
                    self.selectedField = .midtones
                case 3:
                    self.selectedField = .highlights
                case 4:
                    self.selectedField = .whites
                default:
                    break
                }
            case .changed:
                guard let selectedField = self.selectedField else {
                    return
                }
                let translation = gestureRecognizer.translation(in: gestureRecognizer.view).y
                let delta = Float(min(2.0, -1.0 * translation / 8.0) / 100.0)
                
                var updatedValue = component.value
                
                var curve: CurvesValue.CurveValue
                switch component.section {
                case .all:
                    curve = updatedValue.all
                case .red:
                    curve = updatedValue.red
                case .green:
                    curve = updatedValue.green
                case .blue:
                    curve = updatedValue.blue
                }
                
                switch selectedField {
                case .blacks:
                    curve = curve.withUpdatedBlacks(max(0.0, min(1.0, curve.blacks + delta)))
                case .shadows:
                    curve = curve.withUpdatedShadows(max(0.0, min(1.0, curve.shadows + delta)))
                case .midtones:
                    curve = curve.withUpdatedMidtones(max(0.0, min(1.0, curve.midtones + delta)))
                case .highlights:
                    curve = curve.withUpdatedHighlights(max(0.0, min(1.0, curve.highlights + delta)))
                case .whites:
                    curve = curve.withUpdatedWhites(max(0.0, min(1.0, curve.whites + delta)))
                }
                
                switch component.section {
                case .all:
                    updatedValue = updatedValue.withUpdatedAll(curve)
                case .red:
                    updatedValue = updatedValue.withUpdatedRed(curve)
                case .green:
                    updatedValue = updatedValue.withUpdatedGreen(curve)
                case .blue:
                    updatedValue = updatedValue.withUpdatedBlue(curve)
                }
                
                component.valueUpdated(updatedValue)
                
                gestureRecognizer.setTranslation(.zero, in: gestureRecognizer.view)
            default:
                self.selectedField = nil
            }
        }
        
        @objc func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            switch component.section {
            case .all:
                component.valueUpdated(component.value.withUpdatedAll(.initial))
            case .red:
                component.valueUpdated(component.value.withUpdatedRed(.initial))
            case .green:
                component.valueUpdated(component.value.withUpdatedGreen(.initial))
            case .blue:
                component.valueUpdated(component.value.withUpdatedBlue(.initial))
            }
        }
        
        func update(component: CurvesScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let value: CurvesValue.CurveValue
            let lineColor: UIColor
            switch component.section {
            case .all:
                lineColor = UIColor.white
                value = component.value.all
            case .red:
                lineColor = UIColor(rgb: 0xed3d4c)
                value = component.value.red
            case .green:
                lineColor = UIColor(rgb: 0x10ee9d)
                value = component.value.green
            case .blue:
                lineColor = UIColor(rgb: 0x3377fb)
                value = component.value.blue
            }
            
            let fieldWidth = availableSize.width / 5.0
            let bottomInset: CGFloat = 5.0
            
            let blacksSize = self.blacks.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: String(format: "%.2f", value.blacks),
                                font: Font.regular(14.0),
                                textColor: UIColor(rgb: 0xffffff)
                            )
                        ),
                        textShadowColor: UIColor(rgb: 0x000000, alpha: 0.3),
                        textShadowBlur: 1.5
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let blacksFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((fieldWidth - blacksSize.width) / 2.0), y: availableSize.height - blacksSize.height - bottomInset), size: blacksSize)
            if let view = self.blacks.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.alpha = 0.75
                transition.setFrame(view: view, frame: blacksFrame)
            }
            
            let shadowsSize = self.shadows.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: String(format: "%.2f", value.shadows),
                                font: Font.regular(14.0),
                                textColor: UIColor(rgb: 0xffffff)
                            )
                        ),
                        textShadowColor: UIColor(rgb: 0x000000, alpha: 0.3),
                        textShadowBlur: 1.5
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let shadowsFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(fieldWidth + (fieldWidth - blacksSize.width) / 2.0), y: availableSize.height - shadowsSize.height - bottomInset), size: shadowsSize)
            if let view = self.shadows.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.alpha = 0.75
                transition.setFrame(view: view, frame: shadowsFrame)
            }
            
            let midtonesSize = self.midtones.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: String(format: "%.2f", value.midtones),
                                font: Font.regular(14.0),
                                textColor: UIColor(rgb: 0xffffff)
                            )
                        ),
                        textShadowColor: UIColor(rgb: 0x000000, alpha: 0.3),
                        textShadowBlur: 1.5
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let midtonesFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(fieldWidth * 2.0 + (fieldWidth - blacksSize.width) / 2.0), y: availableSize.height - midtonesSize.height - bottomInset), size: midtonesSize)
            if let view = self.midtones.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.alpha = 0.75
                transition.setFrame(view: view, frame: midtonesFrame)
            }
            
            let highlightsSize = self.highlights.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: String(format: "%.2f", value.highlights),
                                font: Font.regular(14.0),
                                textColor: UIColor(rgb: 0xffffff)
                            )
                        ),
                        textShadowColor: UIColor(rgb: 0x000000, alpha: 0.3),
                        textShadowBlur: 1.5
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let highlightsFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(fieldWidth * 3.0 + (fieldWidth - blacksSize.width) / 2.0), y: availableSize.height - highlightsSize.height - bottomInset), size: highlightsSize)
            if let view = self.highlights.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.alpha = 0.75
                transition.setFrame(view: view, frame: highlightsFrame)
            }
            
            let whitesSize = self.whites.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: String(format: "%.2f", value.whites),
                                font: Font.regular(14.0),
                                textColor: UIColor(rgb: 0xffffff)
                            )
                        ),
                        textShadowColor: UIColor(rgb: 0x000000, alpha: 0.3),
                        textShadowBlur: 1.5
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let whitesFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(fieldWidth * 4.0 + (fieldWidth - blacksSize.width) / 2.0), y: availableSize.height - whitesSize.height - bottomInset), size: whitesSize)
            if let view = self.whites.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.alpha = 0.75
                transition.setFrame(view: view, frame: whitesFrame)
            }
            
            self.curveContainer.frame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: availableSize.height + 12.0))
            
            let lineWidth: CGFloat = 1.0 - UIScreenPixel
            self.line1.frame = CGRect(x: fieldWidth, y: 0.0, width: lineWidth, height: availableSize.height)
            self.line2.frame = CGRect(x: fieldWidth * 2.0, y: 0.0, width: lineWidth, height: availableSize.height)
            self.line3.frame = CGRect(x: fieldWidth * 3.0, y: 0.0, width: lineWidth, height: availableSize.height)
            self.line4.frame = CGRect(x: fieldWidth * 4.0, y: 0.0, width: lineWidth, height: availableSize.height)
            
            let guidePath = UIBezierPath()
            guidePath.move(to: CGPoint(x: 0.0, y: availableSize.height))
            guidePath.addLine(to: CGPoint(x: availableSize.width, y: 0.0))
            
            self.guideLayer.frame = CGRect(origin: .zero, size: availableSize)
            self.guideLayer.path = guidePath.cgPath
            
            self.curveLayer.strokeColor = lineColor.cgColor
            self.curveLayer.frame = CGRect(origin: .zero, size: availableSize)
            
            let points: [Float] = [
                value.blacks,
                value.blacks,
                value.shadows,
                value.midtones,
                value.highlights,
                value.whites,
                value.whites
            ]
            
            let (curvePath, _) = curveThroughPoints(
                count: points.count,
                valueAtIndex: { index in
                    return 1.0 - points[index]
                },
                positionAtIndex: { index, _ in
                    switch index {
                    case 0:
                        return -1.0
                    case 1:
                        return 0.0
                    case 2:
                        return 0.25 * availableSize.width
                    case 3:
                        return 0.5 * availableSize.width
                    case 4:
                        return 0.75 * availableSize.width
                    case 5:
                        return availableSize.width
                    default:
                        return availableSize.width + 1.0
                    }
                },
                size: availableSize,
                type: .line,
                granularity: 100,
                floor: true
            )
            self.curveLayer.path = curvePath.cgPath
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

