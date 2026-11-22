//
//  MTTypesetter+Tokenization.swift
//  SwiftMath
//
//  Created by Claude Code on 2025-12-16.
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation
import CoreGraphics

extension MTTypesetter {

    /// Create a line for a math list using the new tokenization approach
    /// This is an alternative to the existing createLineForMathList that uses
    /// pre-tokenization and greedy line fitting
    static func createLineForMathListWithTokenization(
        _ mathList: MTMathList?,
        font: MTFont?,
        style: MTLineStyle,
        cramped: Bool,
        spaced: Bool,
        maxWidth: CGFloat
    ) -> MTMathListDisplay? {
        guard let mathList = mathList else { return nil }
        guard let font = font else { return nil }
        guard !mathList.atoms.isEmpty else {
            // Return empty display instead of nil (matches KaTeX behavior)
            return MTMathListDisplay(withDisplays: [], range: NSMakeRange(0, 0))
        }

        // Phase 0: Preprocess atoms to fuse ordinary characters
        // This is critical for accents and other structures where multi-character
        // text like "xyzw" should stay together as a single atom
        let preprocessedAtoms = MTTypesetter.preprocessMathList(mathList)

        // Phase 1: Tokenize atoms into breakable elements
        let tokenizer = MTAtomTokenizer(font: font, style: style, cramped: cramped, maxWidth: maxWidth)
        let elements = tokenizer.tokenize(preprocessedAtoms)

        guard !elements.isEmpty else { return nil }

        // Phase 2: Fit elements into lines
        let margin = spaced ? font.mathTable?.muUnit ?? 0 : 0
        let fitter = MTLineFitter(maxWidth: maxWidth, margin: margin)
        let fittedLines = fitter.fitLines(elements)

        // Phase 3: Generate displays from fitted lines
        let generator = MTDisplayGenerator(font: font, style: style)
        let displays = generator.generateDisplays(from: fittedLines, startPosition: CGPoint.zero)

        // Determine range from atoms
        let range: NSRange
        if let firstAtom = mathList.atoms.first, let lastAtom = mathList.atoms.last {
            let start = firstAtom.indexRange.location
            let end = NSMaxRange(lastAtom.indexRange)
            range = NSMakeRange(start, end - start)
        } else {
            range = NSMakeRange(0, 0)
        }

        // Create and return the math list display
        let mathListDisplay = MTMathListDisplay(withDisplays: displays, range: range)

        return mathListDisplay
    }
}
