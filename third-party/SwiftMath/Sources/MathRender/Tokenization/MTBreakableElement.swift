//
//  MTBreakableElement.swift
//  SwiftMath
//
//  Created by Claude Code on 2025-12-16.
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation
import CoreGraphics

// MARK: - MTElementContent

/// Represents the content type of a breakable element
enum MTElementContent {
    /// Simple text content
    case text(String)
    /// Pre-rendered display (fraction, radical, etc.)
    case display(MTDisplay)
    /// Math operator with spacing
    case `operator`(String, type: MTMathAtomType)
    /// Explicit spacing
    case space(CGFloat)
    /// Superscript or subscript display
    case script(MTDisplay, isSuper: Bool)
}

// MARK: - MTBreakableElement

/// Represents a breakable element with pre-calculated width and break rules
struct MTBreakableElement {
    // MARK: Display properties

    /// The content of this element
    let content: MTElementContent

    /// Pre-calculated width (cached)
    let width: CGFloat

    /// Height of the element
    let height: CGFloat

    /// Distance from baseline to top
    let ascent: CGFloat

    /// Distance from baseline to bottom
    let descent: CGFloat

    // MARK: Breaking rules

    /// Can break BEFORE this element?
    let isBreakBefore: Bool

    /// Can break AFTER this element?
    let isBreakAfter: Bool

    /// Penalty for breaking before (0=good, 100=bad, 150=never)
    let penaltyBefore: Int

    /// Penalty for breaking after (0=good, 100=bad, 150=never)
    let penaltyAfter: Int

    // MARK: Relationship tracking

    /// Elements with same groupId must stay together
    let groupId: UUID?

    /// Parent element ID (for scripts)
    let parentId: UUID?

    // MARK: Source tracking

    /// Original atom this element was created from
    let originalAtom: MTMathAtom

    /// Index range in the original math list
    let indexRange: NSRange

    // MARK: Optional attributes

    /// Text color for this element
    let color: MTColor?

    /// Background color for this element
    let backgroundColor: MTColor?

    // MARK: Atomicity flag

    /// If true, NEVER break this element internally
    let indivisible: Bool
}

// MARK: - Penalty Constants

/// Penalty values for line breaking decisions
enum MTBreakPenalty {
    /// Best break points (operators, relations)
    static let best = 0

    /// Good break points (ordinary atoms, after scripts)
    static let good = 10

    /// Moderate penalty (before fractions, radicals)
    static let moderate = 15

    /// Acceptable break points
    static let acceptable = 50

    /// Bad break points (avoid if possible)
    static let bad = 100

    /// Never break here (grouped elements)
    static let never = 150
}
