//
//  MTDisplayGenerator.swift
//  SwiftMath
//
//  Created by Claude Code on 2025-12-16.
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation
import CoreGraphics
import CoreText

/// Generates MTDisplay objects from fitted lines of breakable elements
class MTDisplayGenerator {

    // MARK: - Properties

    let font: MTFont
    let style: MTLineStyle
    let widthCalculator: MTElementWidthCalculator

    // MARK: - Initialization

    init(font: MTFont, style: MTLineStyle) {
        self.font = font
        self.style = style
        self.widthCalculator = MTElementWidthCalculator(font: font, style: style)
    }

    // MARK: - Display Generation

    /// Generate displays from fitted lines
    func generateDisplays(from lines: [[MTBreakableElement]], startPosition: CGPoint) -> [MTDisplay] {
        var allDisplays: [MTDisplay] = []
        var currentY = startPosition.y

        // Minimum spacing between lines (20% of font size for breathing room)
        let minimumLineSpacing = font.fontSize * 0.2

        for (index, line) in lines.enumerated() {
            let (lineDisplays, currentLineMetrics) = generateLine(line, at: CGPoint(x: startPosition.x, y: currentY))
            allDisplays.append(contentsOf: lineDisplays)

            // Calculate spacing for next line based on actual content heights
            if index < lines.count - 1 {
                let nextLine = lines[index + 1]
                let nextLineAscent = nextLine.map { $0.ascent }.max() ?? 0

                // Space needed = current line's descent + minimum spacing + next line's ascent
                let spaceNeeded = currentLineMetrics.descent + minimumLineSpacing + nextLineAscent

                // Ensure minimum spacing of 1.2x font size for readability
                let minSpacing = font.fontSize * 1.2
                currentY -= max(spaceNeeded, minSpacing)
            }
        }

        return allDisplays
    }

    /// Line metrics for spacing calculation
    struct LineMetrics {
        let ascent: CGFloat
        let descent: CGFloat
        var height: CGFloat { ascent + descent }
    }

    /// Generate displays for a single line
    private func generateLine(_ elements: [MTBreakableElement], at position: CGPoint) -> ([MTDisplay], LineMetrics) {
        var displays: [MTDisplay] = []
        var xOffset: CGFloat = 0

        // Calculate line metrics
        let lineAscent = elements.map { $0.ascent }.max() ?? 0
        let lineDescent = elements.map { $0.descent }.max() ?? 0

        // Baseline y position
        let baseline = position.y

        var i = 0
        while i < elements.count {
            let element = elements[i]

            // Check if this is part of a group (base + scripts)
            if let groupId = element.groupId {
                // Collect all elements in this group
                var groupElements: [MTBreakableElement] = []
                var j = i
                while j < elements.count && elements[j].groupId == groupId {
                    groupElements.append(elements[j])
                    j += 1
                }

                // Render the group
                let groupAdvance = renderGroup(groupElements, at: CGPoint(x: position.x + xOffset, y: baseline), displays: &displays)
                xOffset += groupAdvance
                i = j
            } else {
                // Regular element (not part of a group)

                // CRITICAL: For operators, spacing should be split evenly before and after
                // The element.width includes both spacing, but we need to position the operator
                // with half spacing before it
                var spacingBefore: CGFloat = 0
                if case .operator(let op, _) = element.content {
                    // Get the actual text width vs element width to calculate spacing
                    let textWidth = widthCalculator.measureText(op)
                    let totalSpacing = element.width - textWidth
                    spacingBefore = totalSpacing / 2
                }

                let elementPosition = CGPoint(x: position.x + xOffset + spacingBefore, y: baseline)

                switch element.content {
                case .text(let text):
                    let display = createTextDisplay(text, at: elementPosition, element: element)
                    displays.append(display)

                case .display(let preRenderedDisplay):
                    // Use pre-rendered display (fraction, radical, etc.)
                    let mutableDisplay = preRenderedDisplay
                    mutableDisplay.position = elementPosition
                    displays.append(mutableDisplay)

                case .operator(let op, _):
                    let display = createTextDisplay(op, at: elementPosition, element: element)
                    displays.append(display)

                case .script:
                    // Standalone script (shouldn't happen, but handle gracefully)
                    break

                case .space:
                    // No display for space, just advance position
                    break
                }

                xOffset += element.width
                i += 1
            }
        }

        return (displays, LineMetrics(ascent: lineAscent, descent: lineDescent))
    }

    /// Render a group of elements (base + scripts) and return the horizontal advance
    private func renderGroup(_ groupElements: [MTBreakableElement], at position: CGPoint, displays: inout [MTDisplay]) -> CGFloat {
        var baseWidth: CGFloat = 0
        var superscriptWidth: CGFloat = 0
        var subscriptWidth: CGFloat = 0
        var baseXOffset: CGFloat = 0

        // Check if this group has any scripts
        let hasScripts = groupElements.contains { element in
            if case .script = element.content {
                return true
            }
            return false
        }

        // Track the start index of base displays for dimension adjustment
        let baseDisplayStartIndex = displays.count

        // First pass: render base elements and collect script widths
        for element in groupElements {
            switch element.content {
            case .script:
                // Skip scripts in first pass
                break
            default:
                // Render base element
                let basePosition = CGPoint(x: position.x + baseXOffset, y: position.y)

                switch element.content {
                case .text(let text):
                    let display = createTextDisplay(text, at: basePosition, element: element, hasScript: hasScripts)
                    displays.append(display)
                case .display(let preRenderedDisplay):
                    let mutableDisplay = preRenderedDisplay
                    mutableDisplay.position = basePosition
                    displays.append(mutableDisplay)
                case .operator(let op, _):
                    let display = createTextDisplay(op, at: basePosition, element: element, hasScript: hasScripts)
                    displays.append(display)
                default:
                    break
                }

                baseWidth += element.width
                baseXOffset += element.width
            }
        }

        // Second pass: collect script information for joint positioning
        var superscriptDisplay: MTDisplay? = nil
        var subscriptDisplay: MTDisplay? = nil
        var hasBothScripts = false

        for element in groupElements {
            if case .script(let scriptDisplay, let isSuper) = element.content {
                if isSuper {
                    superscriptDisplay = scriptDisplay
                } else {
                    subscriptDisplay = scriptDisplay
                }
            }
        }

        hasBothScripts = superscriptDisplay != nil && subscriptDisplay != nil

        // Third pass: render scripts with proper positioning
        var superScriptShiftUp: CGFloat = 0
        var subscriptShiftDown: CGFloat = 0

        // Check if base is a glyph (not CTLineDisplay) for special positioning
        // For glyphs (like large operators), position scripts relative to glyph edges
        var isGlyphBase = false
        for disp in displays[baseDisplayStartIndex..<displays.count] {
            if disp is MTGlyphDisplay {
                isGlyphBase = true
                // Get script font metrics for display-based positioning
                let scriptStyle: MTLineStyle = (style == .display || style == .text) ? .script : .scriptOfScript
                let scriptFontSize = MTTypesetter.getStyleSize(scriptStyle, font: font)
                let scriptFont = font.copy(withSize: scriptFontSize)

                if let scriptFontMetrics = scriptFont.mathTable {
                    // Position scripts relative to the glyph's edges (matches MTTypesetter line 571-572)
                    superScriptShiftUp = disp.ascent - scriptFontMetrics.superscriptBaselineDropMax
                    subscriptShiftDown = disp.descent + scriptFontMetrics.subscriptBaselineDropMin
                }
                break
            }
        }

        for element in groupElements {
            if case .script(let scriptDisplay, let isSuper) = element.content {
                guard let mathTable = font.mathTable else { continue }

                if !isGlyphBase {
                    // Standard positioning for text (CTLineDisplay)
                    if isSuper {
                        superScriptShiftUp = mathTable.superscriptShiftUp
                        superScriptShiftUp = max(superScriptShiftUp, scriptDisplay.descent + mathTable.superscriptBottomMin)
                    } else {
                        subscriptShiftDown = mathTable.subscriptShiftDown
                        subscriptShiftDown = max(subscriptShiftDown, scriptDisplay.ascent - mathTable.subscriptTopMax)
                    }
                } else {
                    // For glyphs, apply the minimum constraints (matches MTTypesetter line 594-595, 581-582)
                    if isSuper {
                        superScriptShiftUp = max(superScriptShiftUp, mathTable.superscriptShiftUp)
                        superScriptShiftUp = max(superScriptShiftUp, scriptDisplay.descent + mathTable.superscriptBottomMin)
                    } else {
                        subscriptShiftDown = max(subscriptShiftDown, mathTable.subscriptShiftDown)
                        subscriptShiftDown = max(subscriptShiftDown, scriptDisplay.ascent - mathTable.subscriptTopMax)
                    }
                }

                if isSuper {
                    superscriptWidth = element.width
                } else {
                    subscriptWidth = element.width
                }
            }
        }

        // If both scripts present, apply joint positioning adjustments
        if hasBothScripts, let superDisp = superscriptDisplay, let subDisp = subscriptDisplay,
           let mathTable = font.mathTable {
            let subSuperScriptGap = (superScriptShiftUp - superDisp.descent) + (subscriptShiftDown - subDisp.ascent)
            if subSuperScriptGap < mathTable.subSuperscriptGapMin {
                // Set the gap to at least the minimum
                subscriptShiftDown += mathTable.subSuperscriptGapMin - subSuperScriptGap
                let superscriptBottomDelta = mathTable.superscriptBottomMaxWithSubscript - (superScriptShiftUp - superDisp.descent)
                if superscriptBottomDelta > 0 {
                    // Superscript is lower than the max allowed by the font with a subscript
                    superScriptShiftUp += superscriptBottomDelta
                    subscriptShiftDown -= superscriptBottomDelta
                }
            }
        }

        // Calculate italic correction (delta) for superscript positioning
        // Superscripts are positioned at baseWidth + delta, subscripts at baseWidth
        var delta: CGFloat = 0
        if superscriptDisplay != nil {
            // Get italic correction from the base display if it's a glyph
            for disp in displays[baseDisplayStartIndex..<displays.count] {
                if let glyphDisplay = disp as? MTGlyphDisplay,
                   let mathTable = font.mathTable {
                    delta = mathTable.getItalicCorrection(glyphDisplay.glyph)
                    break
                }
            }
        }

        // Fourth pass: create wrapped script displays with final positions
        for element in groupElements {
            if case .script(let scriptDisplay, let isSuper) = element.content {
                let scriptShift = isSuper ? superScriptShiftUp : -subscriptShiftDown
                let scriptType: MTMathListDisplay.LinePosition = isSuper ? .superscript : .ssubscript
                // Superscripts get delta added, subscripts don't (matches MTTypesetter line 622, 624)
                let deltaOffset = isSuper ? delta : 0
                let scriptPosition = CGPoint(x: position.x + baseWidth + deltaOffset, y: position.y + scriptShift)

                // Reset the scriptDisplay's position to (0, 0) since it will be positioned by the wrapper
                let mutableScript = scriptDisplay
                mutableScript.position = CGPoint.zero

                let wrappedScript = MTMathListDisplay(
                    withDisplays: [mutableScript],
                    range: scriptDisplay.range
                )
                wrappedScript.type = scriptType
                wrappedScript.position = scriptPosition
                wrappedScript.index = 0  // Index of the base atom this script belongs to

                displays.append(wrappedScript)
            }
        }

        // Calculate horizontal advance: base width + max(script widths) + spacing
        // This matches MTTypesetter.makeScripts() logic (line 626)
        // Superscript width includes delta, subscript doesn't
        let scriptWidth = max(superscriptWidth + delta, subscriptWidth)
        let spaceAfterScript = font.mathTable?.spaceAfterScript ?? 0
        let totalWidth = baseWidth + scriptWidth + spaceAfterScript

        // If this group has scripts, adjust the base display's dimensions to include scripts
        // This matches the legacy typesetter behavior where display.ascent == line.ascent
        if hasScripts && displays.count > baseDisplayStartIndex {
            // Calculate the full extent of the group including scripts
            var maxAscent: CGFloat = 0
            var maxDescent: CGFloat = 0

            for i in baseDisplayStartIndex..<displays.count {
                let disp = displays[i]
                let topY = disp.position.y + disp.ascent
                let bottomY = disp.position.y - disp.descent

                maxAscent = max(maxAscent, topY - position.y)
                maxDescent = max(maxDescent, position.y - bottomY)
            }

            // Update the first base display's dimensions to reflect the full extent
            // Width should be base + script, without the spaceAfterScript (that's for cursor advancement)
            let baseDisplay = displays[baseDisplayStartIndex]
            baseDisplay.ascent = maxAscent
            baseDisplay.descent = maxDescent
            baseDisplay.width = baseWidth + scriptWidth
            displays[baseDisplayStartIndex] = baseDisplay
        }

        return totalWidth
    }

    /// Create a text display for a character or string
    private func createTextDisplay(_ text: String, at position: CGPoint, element: MTBreakableElement, hasScript: Bool = false) -> MTDisplay {
        let attrString = NSMutableAttributedString(string: text)
        attrString.addAttribute(
            NSAttributedString.Key(kCTFontAttributeName as String),
            value: font.ctFont as Any,
            range: NSMakeRange(0, attrString.length)
        )

        // If the atom was fused (multiple ordinary chars combined), use fusedAtoms
        // Otherwise, use the original atom
        let atoms: [MTMathAtom]
        if !element.originalAtom.fusedAtoms.isEmpty {
            atoms = element.originalAtom.fusedAtoms
        } else {
            atoms = [element.originalAtom]
        }

        let display = MTCTLineDisplay(
            withString: attrString,
            position: position,
            range: element.indexRange,
            font: font,
            atoms: atoms
        )

        // Mark if this base element has associated scripts
        display.hasScript = hasScript

        return display
    }
}
