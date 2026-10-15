import Foundation
import UIKit
import Display
import TelegramPresentationData
import SwiftSignalKit

private final class QrStudioSwatchCache {
    static let shared = QrStudioSwatchCache()

    private let queue = DispatchQueue(label: "org.telegram.QrStudio.swatches", qos: .userInitiated)
    private var images: [String: CGImage] = [:]
    private var pending: [String: [(CGImage) -> Void]] = [:]

    func image(for palette: QrStudioPalette, pixelSide: Int, completion: @escaping (CGImage) -> Void) {
        let key = "\(palette.name)-\(pixelSide)"
        if let image = self.images[key] {
            completion(image)
            return
        }
        if self.pending[key] != nil {
            self.pending[key]?.append(completion)
            return
        }
        self.pending[key] = [completion]
        let colors = palette.colors
        self.queue.async {
            let image = qrStudioSwatchImage(colors: colors, side: pixelSide)
            DispatchQueue.main.async {
                let completions = self.pending.removeValue(forKey: key) ?? []
                guard let image else {
                    return
                }
                self.images[key] = image
                for completion in completions {
                    completion(image)
                }
            }
        }
    }
}

enum QrStudioColorsSelection: Equatable {
    case palette(QrStudioPaletteId)
    case theme(String)
}

final class QrStudioColorsTabView: UIView, UIScrollViewDelegate {
    private struct Cell {
        let selection: QrStudioColorsSelection
        let frame: CGRect
    }

    let scrollView = UIScrollView()
    var selected: ((QrStudioPaletteId) -> Void)?
    var selectedTheme: ((String) -> Void)?
    var themeImage: ((QrStudioTheme, Int) -> Signal<CGImage?, NoError>)?

    private var labels: [UILabel] = []
    private let vibrantHeaders = QrStudioVibrantHeaders()
    var tintMaskContainer: UIView? {
        didSet {
            self.vibrantHeaders.attach(to: self.tintMaskContainer)
        }
    }
    private var paletteLayers: [QrStudioPaletteId: CALayer] = [:]
    private var paletteNames: [QrStudioPaletteId: String] = [:]
    private var paletteIds: [QrStudioPaletteId] = []
    private var themeLayers: [String: CALayer] = [:]
    private var themeDisposables: [String: Disposable] = [:]
    private var themeIds: [String] = []
    private var cells: [Cell] = []
    private var rings: [QrStudioPaletteId: QrStudioPressRing] = [:]
    private var paletteFrames: [QrStudioPaletteId: CGRect] = [:]
    private var paletteColors: [QrStudioPaletteId: UIColor] = [:]
    private var didApplySelection = false
    private let fadeMask = CAGradientLayer()

    private var size = CGSize()
    private let hapticFeedback = HapticFeedback()

    private static let swatchSide: CGFloat = 48.0
    private static let cellSide: CGFloat = 58.0
    private static let columns = 6

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.delegate = self
        self.addSubview(self.scrollView)

        for _ in 0 ..< 2 {
            let label = UILabel()
            label.textAlignment = .center
            self.scrollView.addSubview(label)
            self.labels.append(label)
        }


        self.fadeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        self.layer.mask = self.fadeMask

        self.scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        for (_, disposable) in self.themeDisposables {
            disposable.dispose()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.vibrantHeaders.setContentOffset(scrollView.contentOffset)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard case .ended = recognizer.state else {
            return
        }
        let location = recognizer.location(in: self.scrollView)
        for cell in self.cells where cell.frame.contains(location) {
            self.hapticFeedback.tap()
            switch cell.selection {
            case let .palette(id):
                self.selected?(id)
            case let .theme(id):
                self.selectedTheme?(id)
            }
            return
        }
    }

    private func updatePaletteLayers(_ palettes: [QrStudioPalette]) {
        let ids = palettes.compactMap { $0.id }
        let pixelSide = Int(QrStudioColorsTabView.swatchSide * UIScreenScale)
        for (id, layer) in self.paletteLayers where !ids.contains(id) {
            layer.removeFromSuperlayer()
            self.paletteLayers.removeValue(forKey: id)
            self.paletteNames.removeValue(forKey: id)
        }
        for palette in palettes {
            guard let id = palette.id, self.paletteNames[id] != palette.name else {
                continue
            }
            let swatchLayer: CALayer
            if let current = self.paletteLayers[id] {
                swatchLayer = current
            } else {
                swatchLayer = SimpleLayer()
                swatchLayer.contentsGravity = .resizeAspect
                self.scrollView.layer.addSublayer(swatchLayer)
                self.paletteLayers[id] = swatchLayer
            }
            self.paletteNames[id] = palette.name
            QrStudioSwatchCache.shared.image(for: palette, pixelSide: pixelSide, completion: { [weak self, weak swatchLayer] image in
                guard let self, self.paletteNames[id] == palette.name else {
                    return
                }
                swatchLayer?.contents = image
            })
        }
        self.paletteIds = ids
    }

    private func updateThemeLayers(_ themes: [QrStudioTheme]) {
        let ids = themes.map { $0.id }
        guard ids != self.themeIds else {
            return
        }
        self.themeIds = ids
        for (id, layer) in self.themeLayers where !ids.contains(id) {
            layer.removeFromSuperlayer()
            self.themeLayers.removeValue(forKey: id)
            self.themeDisposables.removeValue(forKey: id)?.dispose()
        }
        let pixelSide = Int(QrStudioColorsTabView.swatchSide * UIScreenScale)
        for theme in themes where self.themeLayers[theme.id] == nil {
            let layer = SimpleLayer()
            layer.contentsGravity = .resizeAspect
            layer.backgroundColor = (theme.colors.first ?? QrStudioColor(0.85, 0.85, 0.85)).uiColor.cgColor
            layer.cornerRadius = QrStudioColorsTabView.swatchSide * 0.5
            layer.masksToBounds = true
            self.scrollView.layer.addSublayer(layer)
            self.themeLayers[theme.id] = layer
            if let signal = self.themeImage?(theme, pixelSide) {
                self.themeDisposables[theme.id] = (signal |> deliverOnMainQueue).startStrict(next: { [weak layer] image in
                    if let image {
                        layer?.contents = image
                    }
                })
            }
        }
    }

    func update(size: CGSize, theme: PresentationTheme, strings: PresentationStrings, themes: [QrStudioTheme], palettes: [QrStudioPalette], selection: QrStudioColorsSelection?, revealSelection: Bool) {
        let sizeChanged = self.size != size
        let themesChanged = themes.map { $0.id } != self.themeIds || palettes.compactMap({ $0.id }) != self.paletteIds
        self.size = size
        self.updateThemeLayers(themes)
        self.updatePaletteLayers(palettes)

        self.scrollView.frame = CGRect(origin: CGPoint(), size: size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fadeMask.frame = CGRect(origin: CGPoint(), size: size)
        self.fadeMask.locations = [0.0, NSNumber(value: Double(14.0 / max(size.height, 1.0))), 1.0]
        self.fadeMask.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.fadeMask.endPoint = CGPoint(x: 0.5, y: 1.0)

        let titles = [strings.QrStudio_Colors_Themes, strings.QrStudio_Colors_Profile]
        let headerColor = theme.overallDarkAppearance ? theme.chat.inputMediaPanel.stickersSectionTextColor : theme.chat.inputMediaPanel.panelContentVibrantOverlayColor
        let sideInset: CGFloat = 10.0
        let columnSpacing: CGFloat = 4.0
        let rowSpacing: CGFloat = 8.0
        let columns = QrStudioColorsTabView.columns
        let cellSide = QrStudioColorsTabView.cellSide
        let swatchSide = QrStudioColorsTabView.swatchSide
        let columnWidth = (size.width - sideInset * 2.0 - columnSpacing * CGFloat(columns - 1)) / CGFloat(columns)

        if sizeChanged || themesChanged || self.cells.isEmpty {
            let sections: [[QrStudioColorsSelection]] = [
                themes.map { QrStudioColorsSelection.theme($0.id) },
                palettes.compactMap { $0.id.map { QrStudioColorsSelection.palette($0) } }
            ]
            var cells: [Cell] = []
            var y: CGFloat = 16.0
            for (sectionIndex, section) in sections.enumerated() {
                let label = self.labels[sectionIndex]
                let hasTitle = sectionIndex != 0
                label.isHidden = section.isEmpty || !hasTitle
                if section.isEmpty {
                    continue
                }
                if hasTitle {
                    label.frame = CGRect(x: 2.0, y: y, width: size.width - 4.0, height: 17.0)
                    y += 17.0 + 12.0
                }
                for (offset, selection) in section.enumerated() {
                    let column = offset % columns
                    let row = offset / columns
                    let cellFrame = CGRect(x: sideInset + CGFloat(column) * (columnWidth + columnSpacing) + (columnWidth - cellSide) * 0.5, y: y + CGFloat(row) * (cellSide + rowSpacing), width: cellSide, height: cellSide)
                    cells.append(Cell(selection: selection, frame: cellFrame))
                    let swatchFrame = cellFrame.insetBy(dx: (cellSide - swatchSide) * 0.5, dy: (cellSide - swatchSide) * 0.5)
                    switch selection {
                    case let .palette(id):
                        self.paletteFrames[id] = swatchFrame
                        if let swatchLayer = self.paletteLayers[id] {
                            swatchLayer.bounds = CGRect(origin: CGPoint(), size: swatchFrame.size)
                            swatchLayer.position = CGPoint(x: swatchFrame.midX, y: swatchFrame.midY)
                        }
                    case let .theme(id):
                        self.themeLayers[id]?.frame = swatchFrame
                    }
                }
                let rows = (section.count + columns - 1) / columns
                y += CGFloat(rows) * cellSide + CGFloat(max(0, rows - 1)) * rowSpacing + 18.0
            }
            self.cells = cells
            self.scrollView.contentSize = CGSize(width: size.width, height: y + 34.0)
        }

        var headers: [(text: NSAttributedString, frame: CGRect)] = []
        for (index, label) in self.labels.enumerated() {
            label.attributedText = NSAttributedString(string: titles[index].uppercased(), attributes: [
                .font: Font.semibold(13.0),
                .foregroundColor: headerColor,
                .kern: -0.078
            ])
            if !label.isHidden, let text = label.attributedText {
                headers.append((text, label.frame))
            }
        }
        self.vibrantHeaders.update(size: size, headers: headers, isEnabled: !theme.overallDarkAppearance)
        self.vibrantHeaders.setContentOffset(self.scrollView.contentOffset)

        for palette in palettes {
            if let id = palette.id {
                let color = palette.colors.count > 4 ? palette.colors[4] : (palette.colors.first ?? QrStudioColor(0.5, 0.5, 0.5))
                self.paletteColors[id] = color.uiColor
            }
        }
        var selectedPaletteId: QrStudioPaletteId?
        if case let .palette(id) = selection {
            selectedPaletteId = id
        }
        if let selectedPaletteId, self.rings[selectedPaletteId] == nil, self.paletteLayers[selectedPaletteId] != nil {
            let ring = QrStudioPressRing()
            self.scrollView.layer.addSublayer(ring.layer)
            self.rings[selectedPaletteId] = ring
        }
        for (id, ring) in self.rings {
            guard let frame = self.paletteFrames[id], let swatchLayer = self.paletteLayers[id] else {
                ring.layer.removeFromSuperlayer()
                self.rings.removeValue(forKey: id)
                continue
            }
            ring.update(frame: frame, cornerRadius: nil, color: self.paletteColors[id] ?? theme.list.itemAccentColor, isSelected: id == selectedPaletteId, target: swatchLayer, animated: self.didApplySelection && !revealSelection)
        }
        self.didApplySelection = true

        if revealSelection, size.height > 0.0, !self.scrollView.isTracking, let selection, let cell = self.cells.first(where: { $0.selection == selection }) {
            let frame = cell.frame
            let offset = self.scrollView.contentOffset.y
            if frame.minY < offset + 14.0 || frame.maxY > offset + size.height - 40.0 {
                let maxOffset = max(0.0, self.scrollView.contentSize.height - size.height)
                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: min(maxOffset, max(0.0, frame.midY - size.height * 0.5))), animated: false)
            }
        }
        CATransaction.commit()
    }
}
