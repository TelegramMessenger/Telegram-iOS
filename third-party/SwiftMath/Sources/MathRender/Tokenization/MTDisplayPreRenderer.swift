//
//  MTDisplayPreRenderer.swift
//  SwiftMath
//
//  Created by Claude Code on 2025-12-16.
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation
import CoreGraphics

/// Pre-renders complex atoms (fractions, radicals, etc.) as MTDisplay objects during tokenization
class MTDisplayPreRenderer {

    // MARK: - Properties

    let font: MTFont
    let style: MTLineStyle
    let cramped: Bool

    // MARK: - Initialization

    init(font: MTFont, style: MTLineStyle, cramped: Bool) {
        self.font = font
        self.style = style
        self.cramped = cramped
    }

    // MARK: - Script Rendering

    /// Render a script (superscript or subscript) as a display
    func renderScript(_ mathList: MTMathList, isSuper: Bool) -> MTDisplay? {
        let scriptStyle = getScriptStyle()
        let scriptCramped = isSuper ? cramped : true  // Subscripts are always cramped

        // Scale the font for the script style
        let scriptFontSize = MTTypesetter.getStyleSize(scriptStyle, font: font)
        let scriptFont = font.copy(withSize: scriptFontSize)

        guard let display = MTTypesetter.createLineForMathList(
            mathList,
            font: scriptFont,
            style: scriptStyle,
            cramped: scriptCramped,
            spaced: false
        ) else {
            return nil
        }

        // If the result is a MTMathListDisplay with a single subdisplay, unwrap it
        // This matches the behavior of the legacy typesetter
        if display.subDisplays.count == 1 {
            return display.subDisplays[0]
        }

        return display
    }

    /// Get the appropriate style for scripts
    private func getScriptStyle() -> MTLineStyle {
        switch style {
        case .display, .text:
            return .script
        case .script, .scriptOfScript:
            return .scriptOfScript
        }
    }

    // MARK: - Helper Methods

    /// Pre-render a simple math list without width constraints
    /// Used for rendering content inside fractions, radicals, etc.
    func renderMathList(_ mathList: MTMathList?, style renderStyle: MTLineStyle? = nil, cramped renderCramped: Bool? = nil) -> MTDisplay? {
        guard let mathList = mathList else { return nil }

        let actualStyle = renderStyle ?? style
        let actualCramped = renderCramped ?? cramped

        return MTTypesetter.createLineForMathList(
            mathList,
            font: font,
            style: actualStyle,
            cramped: actualCramped,
            spaced: false
        )
    }
}
