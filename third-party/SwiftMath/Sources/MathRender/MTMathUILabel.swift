//
//  Created by Mike Griebling on 2022-12-31.
//  Translated from an Objective-C implementation by Kostub Deshmukh.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation
import CoreText

/**
 Different display styles supported by the `MTMathUILabel`.
 
 The only significant difference between the two modes is how fractions
 and limits on large operators are displayed.
 */
public enum MTMathUILabelMode {
    /// Display mode. Equivalent to $$ in TeX
    case display
    /// Text mode. Equivalent to $ in TeX.
    case text
}

/**
    Horizontal text alignment for `MTMathUILabel`.
 */
public enum MTTextAlignment : UInt {
    /// Align left.
    case left
    /// Align center.
    case center
    /// Align right.
    case right
}

/** The main view for rendering math.
 
 `MTMathLabel` accepts either a string in LaTeX or an `MTMathList` to display. Use
 `MTMathList` directly only if you are building it programmatically (e.g. using an
 editor), otherwise using LaTeX is the preferable method.
 
 The math display is centered vertically in the label. The default horizontal alignment is
 is left. This can be changed by setting `textAlignment`. The math is default displayed in
 *Display* mode. This can be changed using `labelMode`.
 
 When created it uses `[MTFontManager defaultFont]` as its font. This can be changed using
 the `font` parameter.
 */
@IBDesignable
public class MTMathUILabel : MTView {
        
    /** The `MTMathList` to render. Setting this will remove any
     `latex` that has already been set. If `latex` has been set, this will
     return the parsed `MTMathList` if the `latex` parses successfully. Use this
     setting if the `MTMathList` has been programmatically constructed, otherwise it
     is preferred to use `latex`.
     */
    public var mathList:MTMathList? {
        set {
            _mathList = newValue
            _error = nil
            _latex = MTMathListBuilder.mathListToString(newValue)
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
        }
        get { _mathList }
    }
    private var _mathList:MTMathList?
    
    /** The latex string to be displayed. Setting this will remove any `mathList` that
     has been set. If latex has not been set, this will return the latex output for the
     `mathList` that is set.
     @see error */
    @IBInspectable
    public var latex:String {
        set {
            _latex = newValue
            _error = nil
            var error : NSError? = nil
            _mathList = MTMathListBuilder.build(fromString: newValue, error: &error)
            if error != nil {
                _mathList = nil
                _error = error
                self.errorLabel?.text = error!.localizedDescription
                self.errorLabel?.frame = self.bounds
                self.errorLabel?.isHidden = !self.displayErrorInline
            } else {
                self.errorLabel?.isHidden = true
            }
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
        }
        get { _latex }
    }
    private var _latex = ""
    
    /** This contains any error that occurred when parsing the latex. */
    public var error:NSError? { _error }
    private var _error:NSError?
    
    /** If true, if there is an error it displays the error message inline. Default true. */
    public var displayErrorInline = true

    /** If true, enables detailed debug logging for intrinsicContentSize calculations.
     This helps diagnose rendering issues like missing row breaks in aligned environments.
     Default false. */
    public var debugLogging = false
    
    /** The MTFont to use for rendering. */
    public var font:MTFont? {
        set {
            guard newValue != nil else { return }
            _font = newValue
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
        }
        get { _font }
    }
    private var _font:MTFont?
    
    /** Convenience method to just set the size of the font without changing the fontface. */
    @IBInspectable
    public var fontSize:CGFloat {
        set {
            _fontSize = newValue
            let font = font?.copy(withSize: newValue)
            self.font = font  // also forces an update
        }
        get { _fontSize }
    }
    private var _fontSize:CGFloat=0
    
    /** This sets the text color of the rendered math formula. The default color is black. */
    @IBInspectable
    public var textColor:MTColor? {
        set {
            guard newValue != nil else { return }
            _textColor = newValue
            self.displayList?.textColor = newValue
            self.setNeedsDisplay()
        }
        get { _textColor }
    }
    private var _textColor:MTColor?
    
    /** The minimum distance from the margin of the view to the rendered math. This value is
     `UIEdgeInsetsZero` by default. This is useful if you need some padding between the math and
     the border/background color. sizeThatFits: will have its returned size increased by these insets.
     */
    @IBInspectable
    public var contentInsets:MTEdgeInsets {
        set {
            _contentInsets = newValue
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
        }
        get { _contentInsets }
    }
    private var _contentInsets = MTEdgeInsetsZero
    
    /** The Label mode for the label. The default mode is Display */
    public var labelMode:MTMathUILabelMode {
        set {
            _labelMode = newValue
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
        }
        get { _labelMode }
    }
    private var _labelMode = MTMathUILabelMode.display
    
    /** Horizontal alignment for the text. The default is align left. */
    public var textAlignment:MTTextAlignment {
        set {
            _textAlignment = newValue
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
        }
        get { _textAlignment }
    }
    private var _textAlignment = MTTextAlignment.left
    
    /** The internal display of the MTMathUILabel. This is for advanced use only. */
    public var displayList: MTMathListDisplay? { _displayList }
    private var _displayList:MTMathListDisplay?

    /** The preferred maximum width (in points) for a multiline label.
     Set this property to enable line wrapping based on available width. */
    public var preferredMaxLayoutWidth: CGFloat {
        set {
            _preferredMaxLayoutWidth = newValue
            _displayList = nil  // Clear cached display list when width constraint changes
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
        }
        get { _preferredMaxLayoutWidth }
    }
    private var _preferredMaxLayoutWidth: CGFloat = 0

    public var currentStyle:MTLineStyle {
        switch _labelMode {
            case .display: return .display
            case .text: return .text
        }
    }
    
    public var errorLabel: MTLabel?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.initCommon()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.initCommon()
    }
    
    func initCommon() {
#if os(macOS)
        self.layer?.isGeometryFlipped = true
#else
        self.layer.isGeometryFlipped = true
        self.clipsToBounds = true
#endif
        _fontSize = 20
        _contentInsets = MTEdgeInsetsZero
        _labelMode = .display
        let font = MTFontManager.fontManager.defaultFont
        self.font = font
        _textAlignment = .left
        _displayList = nil
        displayErrorInline = true
        self.backgroundColor = MTColor.clear
        
        _textColor = MTColor.black
        let label = MTLabel()
        self.errorLabel = label
#if os(macOS)
        label.layer?.isGeometryFlipped = true
#else
        label.layer.isGeometryFlipped = true
#endif
        label.isHidden = true
        label.textColor = MTColor.red
        self.addSubview(label)
    }
    
    override public func draw(_ dirtyRect: MTRect) {
        super.draw(dirtyRect)
        if self.mathList == nil { return }
        if self.font == nil { return }

        // Ensure display list is created before drawing
        if _displayList == nil {
            _layoutSubviews()
        }

        guard let displayList = _displayList else { return }

        // drawing code
        let context = MTGraphicsGetCurrentContext()!
        context.saveGState()

        // CRITICAL FIX for clipping: If the displayList is wider than our bounds,
        // expand the clipping rect to prevent content clipping.
        // This handles cases where preferredMaxLayoutWidth is a hint but the content
        // cannot fit within it even with line breaking.
        let contentWidth = displayList.width + contentInsets.left + contentInsets.right
        if contentWidth > bounds.size.width {
            // Content is wider than bounds - expand clip rect
            let expandedRect = CGRect(
                x: bounds.origin.x,
                y: bounds.origin.y,
                width: contentWidth,
                height: bounds.size.height
            )
            context.clip(to: expandedRect)
        }

        displayList.draw(context)
        context.restoreGState()
    }
    
    func _layoutSubviews() {
        guard _mathList != nil && self.font != nil else {
            _displayList = nil
            errorLabel?.frame = self.bounds
            self.setNeedsDisplay()
            return
        }
        // Ensure we have a valid font before attempting to typeset
        if self.font == nil {
            // No valid font - try to get default font
            if let defaultFont = MTFontManager.fontManager.defaultFont {
                self._font = defaultFont
            } else {
                // Cannot typeset without a font, clear display list
                _displayList = nil
                errorLabel?.frame = self.bounds
                self.setNeedsDisplay()
                return
            }
        }

        // Use the effective width for layout
        let effectiveWidth = _preferredMaxLayoutWidth > 0 ? _preferredMaxLayoutWidth : bounds.size.width
        var availableWidth = effectiveWidth - contentInsets.left - contentInsets.right
        // CRITICAL FIX: Ensure availableWidth is never negative
        // Negative maxWidth passed to MTTypesetter can cause "Negative value is not representable" crashes
        availableWidth = max(0, availableWidth)

        _displayList = MTTypesetter.createLineForMathList(_mathList, font: self.font, style: currentStyle, maxWidth: availableWidth)

        guard let displayList = _displayList else {
            // Empty or invalid input - nothing to display
            return
        }

        displayList.textColor = textColor
        var textX = CGFloat(0)
        switch self.textAlignment {
            case .left:   textX = contentInsets.left
            case .center: textX = (bounds.size.width - contentInsets.left - contentInsets.right - displayList.width) / 2 + contentInsets.left
            case .right:  textX = bounds.size.width - displayList.width - contentInsets.right
        }
        let availableHeight = bounds.size.height - contentInsets.bottom - contentInsets.top

        // center things vertically
        var height = displayList.ascent + displayList.descent
        if height < fontSize/2 {
            height = fontSize/2  // set height to half the font size
        }
        let textY = (availableHeight - height) / 2 + displayList.descent + contentInsets.bottom

        displayList.position = CGPointMake(textX, textY)
        errorLabel?.frame = self.bounds
        self.setNeedsDisplay()
    }
    
    func _sizeThatFits(_ size:CGSize) -> CGSize {
        // Check if we have empty latex (empty string case)
        if _latex.isEmpty {
            // Empty latex - return zero size
            return CGSize(width: 0, height: 0)
        }

        guard _mathList != nil else {
            // No content - return no-intrinsic-size marker
            return CGSize(width: -1, height: -1)
        }

        // Ensure we have a valid font before attempting to typeset
        if self.font == nil {
            // No valid font - try to get default font
            if let defaultFont = MTFontManager.fontManager.defaultFont {
                self._font = defaultFont
            } else {
                // Cannot typeset without a font
                return CGSize(width: -1, height: -1)
            }
        }

        // Determine the maximum width to use
        var maxWidth: CGFloat = 0
        if _preferredMaxLayoutWidth > 0 {
            maxWidth = _preferredMaxLayoutWidth - contentInsets.left - contentInsets.right
            // CRITICAL FIX: Ensure maxWidth is never negative
            // If contentInsets exceed available width, clamp to 0
            maxWidth = max(0, maxWidth)
        } else if size.width > 0 {
            maxWidth = size.width - contentInsets.left - contentInsets.right
            // CRITICAL FIX: Ensure maxWidth is never negative
            maxWidth = max(0, maxWidth)
        }

        var displayList:MTMathListDisplay? = nil
        displayList = MTTypesetter.createLineForMathList(_mathList, font: self.font, style: currentStyle, maxWidth: maxWidth)

        guard displayList != nil else {
            // Failed to create display list
            return CGSize(width: -1, height: -1)
        }

        var resultWidth = displayList!.width + contentInsets.left + contentInsets.right
        var resultHeight = displayList!.ascent + displayList!.descent + contentInsets.top + contentInsets.bottom

        // DEBUG LOGGING for width calculation
        if debugLogging {
            print("\n=== MTMathUILabel intrinsicContentSize DEBUG ===")
            print("LaTeX: \(self.latex)")
            // Show raw bytes to help debug escaping issues
            let latexBytes = Array(self.latex.utf8.prefix(100))
            print("LaTeX bytes (first 100): \(latexBytes)")
            print("preferredMaxLayoutWidth: \(_preferredMaxLayoutWidth)")
            print("size constraint: \(size)")
            print("maxWidth passed to typesetter: \(maxWidth)")
            print("displayList.width: \(displayList!.width)")
            print("displayList.ascent: \(displayList!.ascent)")
            print("displayList.descent: \(displayList!.descent)")
            print("Number of subDisplays: \(displayList!.subDisplays.count)")
            // Count lines by unique Y positions
            let yPositions = Set(displayList!.subDisplays.map { $0.position.y })
            print("Number of lines (unique Y positions): \(yPositions.count)")
            print("contentInsets: \(contentInsets)")
            print("resultWidth (before clamping): \(resultWidth)")
            print("resultHeight (before clamping): \(resultHeight)")

            // HELPFUL WARNING: Detect common escaping mistake
            // Check for environments that typically have multiple rows but only 1 row is rendered
            let multiRowEnvs = ["aligned", "align", "eqnarray", "gather", "split"]
            let latexLower = self.latex.lowercased()
            for env in multiRowEnvs {
                if latexLower.contains("\\begin{\(env)}") {
                    // Check if there's a table with only 1 row
                    if let ml = _mathList {
                        for atom in ml.atoms {
                            if let table = atom as? MTMathTable, table.numRows == 1 {
                                // Check if latex contains single backslash (spacing) where double might be intended
                                // Pattern: \\ followed by non-backslash (like space or letter)
                                if self.latex.contains("\\ ") || self.latex.range(of: #"\\[a-zA-Z]"#, options: .regularExpression) != nil {
                                    print("⚠️ WARNING: '\(env)' environment has only 1 row.")
                                    print("   If you intended multiple rows, use '\\\\\\\\' (4 backslashes in Swift strings)")
                                    print("   or use raw strings: #\"...42\\\\ \\\\dfrac...\"#")
                                    print("   Current input has '\\\\ ' which is a SPACING command, not a row break.")
                                }
                            }
                        }
                    }
                }
            }
        }

        // CRITICAL FIX: Ensure dimensions are never negative
        // Negative values cause crashes in NSRange calculations and SwiftUI layout
        resultWidth = max(0, resultWidth)
        resultHeight = max(0, resultHeight)

        // CRITICAL FIX for accented character clipping:
        // The preferredMaxLayoutWidth is a HINT for line breaking, NOT a hard constraint.
        // If the typesetter cannot fit content within that width (even with line breaking),
        // we MUST return the actual content width to prevent clipping.
        //
        // ONLY clamp in extreme cases to prevent layout explosion (>50% over or >100pt over)
        if _preferredMaxLayoutWidth > 0 && resultWidth > _preferredMaxLayoutWidth {
            let overflow = resultWidth - _preferredMaxLayoutWidth
            let overflowPercent = (overflow / _preferredMaxLayoutWidth) * 100

            if debugLogging {
                print("  Content exceeds preferredMaxLayoutWidth:")
                print("    preferredMaxLayoutWidth: \(_preferredMaxLayoutWidth)")
                print("    resultWidth: \(resultWidth)")
                print("    overflow: \(overflow) (\(String(format: "%.1f", overflowPercent))%)")

                // Check line breaking
                let yPositions = Set(displayList!.subDisplays.map { $0.position.y })
                print("    hasMultipleLines: \(yPositions.count > 1) (yPositions: \(yPositions.count))")

                // Check if any content would be clipped at different widths
                print("    SubDisplay analysis:")
                for (i, sub) in displayList!.subDisplays.enumerated() {
                    let rightEdge = sub.position.x + sub.width
                    let clippedAtPreferred = rightEdge > _preferredMaxLayoutWidth
                    let clippedAtResult = rightEdge > resultWidth
                    print("      Sub[\(i)]: rightEdge=\(rightEdge) clippedAt\(_preferredMaxLayoutWidth)=\(clippedAtPreferred) clippedAt\(resultWidth)=\(clippedAtResult)")
                }
            }

            // ONLY clamp for truly excessive overflow (>50% or >100pt)
            // This prevents layout explosion while allowing normal overflow
            let extremeOverflowThreshold: CGFloat = max(_preferredMaxLayoutWidth * 0.5, 100.0)

            if overflow > extremeOverflowThreshold {
                // Extreme overflow - clamp to prevent layout issues
                let clampedWidth = _preferredMaxLayoutWidth + extremeOverflowThreshold
                if debugLogging {
                    print("    ⚠️ EXTREME OVERFLOW - clamping from \(resultWidth) to \(clampedWidth)")
                    print("    ⚠️ WARNING: This will cause content clipping!")
                }
                resultWidth = clampedWidth
            } else {
                // Normal overflow - keep actual content width to prevent clipping
                if debugLogging {
                    print("    ✓ Normal overflow - keeping actual width \(resultWidth) to prevent clipping")
                }
                // resultWidth stays as is - NO CLAMPING
            }
        } else if _preferredMaxLayoutWidth == 0 && size.width > 0 && resultWidth > size.width {
            // Similar tolerance for size.width constraint
            let tolerance = max(size.width * 0.05, 10.0)
            let maxAllowedWidth = size.width + tolerance

            if debugLogging {
                print("  Exceeds size.width constraint:")
                print("    tolerance: \(tolerance)")
                print("    maxAllowedWidth: \(maxAllowedWidth)")
                print("    overflow amount: \(resultWidth - size.width)")
            }

            if resultWidth <= maxAllowedWidth {
                // Within tolerance - use actual content width
                // resultWidth stays as is
                if debugLogging {
                    print("    ✓ Within tolerance - keeping actual width")
                }
            } else {
                if debugLogging {
                    print("    ⚠️ CLAMPING to maxAllowedWidth (may clip content!)")
                }
                resultWidth = maxAllowedWidth
            }
        }

        if debugLogging {
            print("  Final resultWidth: \(resultWidth)")
            print("  Final resultHeight: \(resultHeight)")

            // Check if any display elements would be clipped
            if let display = displayList {
                print("  Display subdisplays: \(display.subDisplays.count)")
                let yPositions = Set(display.subDisplays.map { $0.position.y }).sorted()
                print("  Unique Y positions (lines): \(yPositions.count) -> \(yPositions)")

                for (i, sub) in display.subDisplays.enumerated() {
                    let rightEdge = sub.position.x + sub.width
                    let clipped = rightEdge > resultWidth

                    // Extract text content if this is a CTLineDisplay
                    var textContent = ""
                    if let ctLineDisplay = sub as? MTCTLineDisplay,
                       let attrString = ctLineDisplay.attributedString {
                        textContent = " text=\"\(attrString.string)\""
                    }

                    print("    Sub[\(i)]: type=\(type(of: sub)), y=\(sub.position.y), x=\(sub.position.x), width=\(sub.width), rightEdge=\(rightEdge)\(textContent)\(clipped ? " ⚠️ CLIPPED" : "")")

                    // Show internal structure for MTMathListDisplay
                    if let mathListDisplay = sub as? MTMathListDisplay, !mathListDisplay.subDisplays.isEmpty {
                        print("      → Contains \(mathListDisplay.subDisplays.count) sub-displays:")
                        for (j, innerSub) in mathListDisplay.subDisplays.enumerated() {
                            var innerTextContent = ""
                            if let innerCTLineDisplay = innerSub as? MTCTLineDisplay,
                               let innerAttrString = innerCTLineDisplay.attributedString {
                                innerTextContent = " text=\"\(innerAttrString.string)\""
                            }
                            print("        [\(j)]: type=\(type(of: innerSub)), y=\(innerSub.position.y), x=\(innerSub.position.x), width=\(innerSub.width)\(innerTextContent)")
                        }
                    }

                    if clipped {
                        print("      ⚠️ CLIPPING: rightEdge \(rightEdge) > resultWidth \(resultWidth)")
                        print("      Clipped amount: \(rightEdge - resultWidth)")
                    }
                }
            }
            print("=== END DEBUG ===\n")
        }

        return CGSize(width: resultWidth, height: resultHeight)
    }

    #if os(macOS)
    public func sizeThatFits(_ size: CGSize) -> CGSize {
        return _sizeThatFits(size)
    }
    #else
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return _sizeThatFits(size)
    }
    #endif

#if os(macOS)
    func setNeedsDisplay() { self.needsDisplay = true }
    func setNeedsLayout() { self.needsLayout = true }
    public override var fittingSize: CGSize { _sizeThatFits(CGSizeZero) }
    public override var intrinsicContentSize: CGSize { _sizeThatFits(CGSizeZero) }
    override public func layout() {
        self._layoutSubviews()
        super.layout()
    }
#else
    public override var intrinsicContentSize: CGSize { _sizeThatFits(CGSizeZero) }
    override public func layoutSubviews() { _layoutSubviews() }
#endif
    
}
