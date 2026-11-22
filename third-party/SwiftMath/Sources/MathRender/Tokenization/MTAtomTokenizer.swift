//
//  MTAtomTokenizer.swift
//  SwiftMath
//
//  Created by Claude Code on 2025-12-16.
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation
import CoreGraphics

/// Tokenizes MTMathAtom lists into breakable elements
class MTAtomTokenizer {

    // MARK: - Properties

    let font: MTFont
    let style: MTLineStyle
    let cramped: Bool
    let maxWidth: CGFloat
    let widthCalculator: MTElementWidthCalculator
    let displayRenderer: MTDisplayPreRenderer

    // MARK: - Initialization

    init(font: MTFont, style: MTLineStyle, cramped: Bool = false, maxWidth: CGFloat = 0) {
        self.font = font
        self.style = style
        self.cramped = cramped
        self.maxWidth = maxWidth
        self.widthCalculator = MTElementWidthCalculator(font: font, style: style)
        self.displayRenderer = MTDisplayPreRenderer(font: font, style: style, cramped: cramped)
    }

    // MARK: - Main Tokenization

    /// Tokenize a list of atoms into breakable elements
    func tokenize(_ atoms: [MTMathAtom]) -> [MTBreakableElement] {
        var elements: [MTBreakableElement] = []
        var index = 0
        var currentStyle = self.style

        while index < atoms.count {
            let atom = atoms[index]
            let prevAtom = index > 0 ? atoms[index - 1] : nil

            // Check for style change atoms
            if atom.type == .style, let styleAtom = atom as? MTMathStyle {
                // Update style for subsequent atoms
                currentStyle = styleAtom.style
                index += 1
                continue
            }

            // Create a tokenizer with the current style for this atom
            let atomTokenizer: MTAtomTokenizer
            if currentStyle != self.style {
                atomTokenizer = MTAtomTokenizer(font: font, style: currentStyle, cramped: cramped, maxWidth: maxWidth)
            } else {
                atomTokenizer = self
            }

            // Handle scripts (subscript/superscript) - these must be grouped with their base
            if atom.superScript != nil || atom.subScript != nil {
                let baseElements = atomTokenizer.tokenizeAtomWithScripts(atom, prevAtom: prevAtom, atomIndex: index, allAtoms: atoms)
                elements.append(contentsOf: baseElements)
            } else {
                // Check if this is a multi-character text atom that needs character-level tokenization
                let isTextAtom = atom.fontStyle == .roman
                let isMultiChar = atom.nucleus.count > 1

                if isTextAtom && isMultiChar {
                    // Break down multi-character text into individual characters for punctuation rules
                    let charElements = atomTokenizer.tokenizeMultiCharText(atom, prevElements: elements, atomIndex: index, allAtoms: atoms)
                    elements.append(contentsOf: charElements)
                } else {
                    // Regular atom without scripts
                    if let element = atomTokenizer.tokenizeAtom(atom, prevAtom: prevAtom, atomIndex: index, allAtoms: atoms) {
                        elements.append(element)
                    }
                }
            }

            index += 1
        }

        return elements
    }

    // MARK: - Atom Tokenization

    /// Tokenize a single atom (without scripts)
    private func tokenizeAtom(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int, allAtoms: [MTMathAtom]) -> MTBreakableElement? {
        switch atom.type {
        // Simple text and variables
        case .ordinary, .variable, .number:
            return tokenizeTextAtom(atom, prevAtom: prevAtom, atomIndex: atomIndex, allAtoms: allAtoms)

        // Operators
        case .binaryOperator, .relation, .unaryOperator:
            return tokenizeOperator(atom, prevAtom: prevAtom, atomIndex: atomIndex)

        // Delimiters
        case .open:
            return tokenizeOpenDelimiter(atom, prevAtom: prevAtom, atomIndex: atomIndex)

        case .close:
            return tokenizeCloseDelimiter(atom, prevAtom: prevAtom, atomIndex: atomIndex)

        // Punctuation
        case .punctuation:
            return tokenizePunctuation(atom, prevAtom: prevAtom, atomIndex: atomIndex)

        // Complex structures (atomic)
        case .fraction:
            return tokenizeFraction(atom as! MTFraction, prevAtom: prevAtom, atomIndex: atomIndex)

        case .radical:
            return tokenizeRadical(atom as! MTRadical, prevAtom: prevAtom, atomIndex: atomIndex)

        case .largeOperator:
            return tokenizeLargeOperator(atom as! MTLargeOperator, prevAtom: prevAtom, atomIndex: atomIndex)

        case .accent:
            return tokenizeAccent(atom as! MTAccent, prevAtom: prevAtom, atomIndex: atomIndex, allAtoms: allAtoms)

        case .underline:
            return tokenizeUnderline(atom as! MTUnderLine, prevAtom: prevAtom, atomIndex: atomIndex)

        case .overline:
            return tokenizeOverline(atom as! MTOverLine, prevAtom: prevAtom, atomIndex: atomIndex)

        case .table:
            return tokenizeTable(atom as! MTMathTable, prevAtom: prevAtom, atomIndex: atomIndex)

        case .inner:
            return tokenizeInner(atom as! MTInner, prevAtom: prevAtom, atomIndex: atomIndex)

        // Spacing
        case .space:
            return tokenizeSpace(atom, prevAtom: prevAtom, atomIndex: atomIndex)

        // Style changes - these don't create elements
        case .style:
            return nil

        // Color - extract inner content with color attribute
        case .color, .colorBox, .textcolor:
            // For now, treat as ordinary (color will be handled in display generation)
            return tokenizeTextAtom(atom, prevAtom: prevAtom, atomIndex: atomIndex, allAtoms: allAtoms)

        default:
            // Treat unknown types as ordinary
            return tokenizeTextAtom(atom, prevAtom: prevAtom, atomIndex: atomIndex, allAtoms: allAtoms)
        }
    }

    // MARK: - Text Atom Tokenization

    private func tokenizeTextAtom(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int, allAtoms: [MTMathAtom]) -> MTBreakableElement? {
        let text = atom.nucleus
        guard !text.isEmpty else { return nil }

        // Calculate width
        let width = widthCalculator.measureText(text)

        // Calculate ascent/descent (approximate using font metrics)
        let ascent = font.mathTable?.axisHeight ?? font.fontSize * 0.5
        let descent = font.fontSize * 0.2
        let height = ascent + descent

        // Determine break rules using Unicode word boundary detection
        var isBreakBefore = true
        var isBreakAfter = true
        var penaltyBefore = MTBreakPenalty.good
        var penaltyAfter = MTBreakPenalty.good

        let isTextAtom = atom.fontStyle == .roman

        // Only apply word boundary logic to text atoms (not math variables)
        if isTextAtom {
            // First apply punctuation rules for single-character text
            // This handles cases where punctuation appears in roman text rather than as separate punctuation atoms
            if text.count == 1, let char = text.first {
                let (punctBreakBefore, punctBreakAfter, punctPenaltyBefore, punctPenaltyAfter) = punctuationBreakRules(char)

                // Apply punctuation rules
                isBreakBefore = punctBreakBefore
                penaltyBefore = punctPenaltyBefore
                isBreakAfter = punctBreakAfter
                penaltyAfter = punctPenaltyAfter
            }

            // Then apply word boundary logic - this ANDs with punctuation rules
            // Both rules must allow breaking for a break to be permitted

            // Check if we should break BEFORE this atom
            if let prevAtom = prevAtom {
                // Handle previous accent atoms (e.g., "é" before "r" in "bactéries")
                if prevAtom.type == .accent && isTextLetterAtom(prevAtom) {
                    // Previous is a text accent - don't break if current is a letter
                    if text.first?.isLetter == true {
                        isBreakBefore = false
                        penaltyBefore = MTBreakPenalty.never
                    }
                } else if prevAtom.fontStyle == .roman {
                    let prevText = prevAtom.nucleus
                    if !prevText.isEmpty && !text.isEmpty {
                        // Use Unicode word boundary detection
                        if !hasWordBoundaryBetween(prevText, and: text) {
                            // No word boundary = we're in the middle of a word
                            isBreakBefore = false
                            penaltyBefore = MTBreakPenalty.never
                        }
                    }
                }
            }

            // Check if we should break AFTER this atom
            if atomIndex + 1 < allAtoms.count {
                let nextAtom = allAtoms[atomIndex + 1]
                // Handle next accent atoms (e.g., "t" before "é" in "bactéries")
                if nextAtom.type == .accent && isTextLetterAtom(nextAtom) {
                    // Next is a text accent - don't break if current is a letter
                    if text.last?.isLetter == true {
                        isBreakAfter = false
                        penaltyAfter = MTBreakPenalty.never
                    }
                } else if nextAtom.fontStyle == .roman {
                    let nextText = nextAtom.nucleus
                    if !text.isEmpty && !nextText.isEmpty {
                        // Use Unicode word boundary detection
                        if !hasWordBoundaryBetween(text, and: nextText) {
                            // No word boundary = next atom is part of same word
                            isBreakAfter = false
                            penaltyAfter = MTBreakPenalty.never
                        }
                    }
                }
            }
        }

        return MTBreakableElement(
            content: .text(text),
            width: width,
            height: height,
            ascent: ascent,
            descent: descent,
            isBreakBefore: isBreakBefore,
            isBreakAfter: isBreakAfter,
            penaltyBefore: penaltyBefore,
            penaltyAfter: penaltyAfter,
            groupId: nil,
            parentId: nil,
            originalAtom: atom,
            indexRange: atom.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: false
        )
    }

    /// Tokenize a multi-character text atom into individual character elements
    /// This enables character-level line breaking with proper punctuation rules
    private func tokenizeMultiCharText(_ atom: MTMathAtom, prevElements: [MTBreakableElement], atomIndex: Int, allAtoms: [MTMathAtom]) -> [MTBreakableElement] {
        let text = atom.nucleus
        guard text.count > 1 else { return [] }

        let debugTokenization = !"".isEmpty  // Enable to debug text tokenization
        if debugTokenization {
            print("\n=== Tokenizing multi-char text: '\(text)' ===")
        }

        var charElements: [MTBreakableElement] = []
        let characters = Array(text)

        for (charIndex, char) in characters.enumerated() {
            let charString = String(char)

            // Calculate width for this character
            let width = widthCalculator.measureText(charString)

            // Calculate ascent/descent (approximate using font metrics)
            let ascent = font.mathTable?.axisHeight ?? font.fontSize * 0.5
            let descent = font.fontSize * 0.2
            let height = ascent + descent

            // Determine break rules for this character
            let (isBreakBefore, isBreakAfter, penaltyBefore, penaltyAfter) = characterBreakRules(
                char: char,
                prevChar: charIndex > 0 ? characters[charIndex - 1] : nil,
                nextChar: charIndex < characters.count - 1 ? characters[charIndex + 1] : nil,
                isFirstInAtom: charIndex == 0,
                isLastInAtom: charIndex == characters.count - 1,
                prevElements: prevElements,
                nextAtom: atomIndex + 1 < allAtoms.count ? allAtoms[atomIndex + 1] : nil
            )

            let element = MTBreakableElement(
                content: .text(charString),
                width: width,
                height: height,
                ascent: ascent,
                descent: descent,
                isBreakBefore: isBreakBefore,
                isBreakAfter: isBreakAfter,
                penaltyBefore: penaltyBefore,
                penaltyAfter: penaltyAfter,
                groupId: nil,
                parentId: nil,
                originalAtom: atom,
                indexRange: atom.indexRange,
                color: nil,
                backgroundColor: nil,
                indivisible: false
            )

            if debugTokenization {
                print("  [\(charIndex)] '\(charString)' breakBefore=\(isBreakBefore) breakAfter=\(isBreakAfter) penaltyBefore=\(penaltyBefore) penaltyAfter=\(penaltyAfter) width=\(width)")
            }

            charElements.append(element)
        }

        return charElements
    }

    /// Determine break rules for a character in a multi-character text string
    private func characterBreakRules(
        char: Character,
        prevChar: Character?,
        nextChar: Character?,
        isFirstInAtom: Bool,
        isLastInAtom: Bool,
        prevElements: [MTBreakableElement],
        nextAtom: MTMathAtom?
    ) -> (isBreakBefore: Bool, isBreakAfter: Bool, penaltyBefore: Int, penaltyAfter: Int) {

        // Apply punctuation rules
        let (punctBreakBefore, punctBreakAfter, punctPenaltyBefore, punctPenaltyAfter) = punctuationBreakRules(char)

        var isBreakBefore = punctBreakBefore
        var isBreakAfter = punctBreakAfter
        var penaltyBefore = punctPenaltyBefore
        var penaltyAfter = punctPenaltyAfter

        // Apply word boundary logic
        // Don't break in the middle of a word (but CJK characters CAN break between each other)
        if let prevChar = prevChar {
            if char.isLetter && prevChar.isLetter {
                // Check if either character is CJK - CJK allows breaks between characters
                let isCJKBreak = isCJKCharacter(char) || isCJKCharacter(prevChar)

                if !isCJKBreak {
                    // Both letters in same non-CJK script - middle of word, don't break
                    isBreakBefore = false
                    penaltyBefore = MTBreakPenalty.never
                }
                // else: At least one is CJK - allow break (keep punctBreakBefore value)
            } else if prevChar == "'" || prevChar == "-" {
                // Apostrophe or hyphen - part of word
                isBreakBefore = false
                penaltyBefore = MTBreakPenalty.never
            }
        } else if isFirstInAtom {
            // First character - check against previous element
            if let lastElement = prevElements.last {
                switch lastElement.content {
                case .text(let prevText):
                    if let prevLastChar = prevText.last {
                        if char.isLetter && prevLastChar.isLetter {
                            // Check if either character is CJK
                            let isCJKBreak = isCJKCharacter(char) || isCJKCharacter(prevLastChar)

                            if !isCJKBreak {
                                // Both non-CJK letters - don't break
                                isBreakBefore = false
                                penaltyBefore = MTBreakPenalty.never
                            }
                        } else if prevLastChar == "'" || prevLastChar == "-" {
                            isBreakBefore = false
                            penaltyBefore = MTBreakPenalty.never
                        }
                    }
                case .display:
                    // Check if previous element is a text-mode accent (e.g., "é")
                    // Accents in text mode should not allow breaks after them if current is a letter
                    if lastElement.originalAtom.type == .accent,
                       isTextLetterAtom(lastElement.originalAtom),
                       char.isLetter {
                        isBreakBefore = false
                        penaltyBefore = MTBreakPenalty.never
                    }
                default:
                    break
                }
            }
        }

        if let nextChar = nextChar {
            if char.isLetter && nextChar.isLetter {
                // Check if either character is CJK
                let isCJKBreak = isCJKCharacter(char) || isCJKCharacter(nextChar)

                if !isCJKBreak {
                    // Both non-CJK letters - middle of word, don't break
                    isBreakAfter = false
                    penaltyAfter = MTBreakPenalty.never
                }
            } else if nextChar == "'" || nextChar == "-" {
                // Before apostrophe or hyphen - part of word
                isBreakAfter = false
                penaltyAfter = MTBreakPenalty.never
            }
        } else if isLastInAtom {
            // Last character - check against next atom
            if let nextAtom = nextAtom {
                // Handle next accent atoms (e.g., "t" before "é" in "bactéries")
                if nextAtom.type == .accent && isTextLetterAtom(nextAtom) {
                    if char.isLetter {
                        isBreakAfter = false
                        penaltyAfter = MTBreakPenalty.never
                    }
                } else if nextAtom.fontStyle == .roman,
                   let nextFirstChar = nextAtom.nucleus.first {
                    if char.isLetter && nextFirstChar.isLetter {
                        // Check if either character is CJK
                        let isCJKBreak = isCJKCharacter(char) || isCJKCharacter(nextFirstChar)

                        if !isCJKBreak {
                            // Both non-CJK letters - don't break
                            isBreakAfter = false
                            penaltyAfter = MTBreakPenalty.never
                        }
                    }
                }
            }
        }

        return (isBreakBefore, isBreakAfter, penaltyBefore, penaltyAfter)
    }

    // MARK: - Word Boundary Detection

    /// Determines if a character is a CJK (Chinese, Japanese, Korean) character
    /// CJK characters can break between each other even though they are technically "letters"
    private func isCJKCharacter(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        let value = scalar.value

        // CJK Unified Ideographs and extensions
        return (value >= 0x4E00 && value <= 0x9FFF) ||   // CJK Unified Ideographs (most common Chinese/Japanese kanji)
               (value >= 0x3400 && value <= 0x4DBF) ||   // CJK Unified Ideographs Extension A
               (value >= 0x20000 && value <= 0x2A6DF) || // CJK Unified Ideographs Extension B
               (value >= 0x3040 && value <= 0x309F) ||   // Hiragana (Japanese)
               (value >= 0x30A0 && value <= 0x30FF) ||   // Katakana (Japanese)
               (value >= 0xAC00 && value <= 0xD7AF)      // Hangul Syllables (Korean)
    }

    /// Determines if there's a word boundary between two text fragments
    /// Combines Unicode word segmentation with special handling for contractions and hyphenated words
    private func hasWordBoundaryBetween(_ text1: String, and text2: String) -> Bool {
        // RULE 1: Check for apostrophes and hyphens between letters (contractions and hyphenated words)
        // These should NOT be treated as word boundaries even though Unicode does
        if let lastChar1 = text1.last, let firstChar2 = text2.first {
            // Pattern: letter + apostrophe|hyphen + letter → NOT a word boundary
            if lastChar1.isLetter && (firstChar2 == "'" || firstChar2 == "-") {
                return false  // Don't break before apostrophe/hyphen
            }
            if (lastChar1 == "'" || lastChar1 == "-") && firstChar2.isLetter {
                return false  // Don't break after apostrophe/hyphen
            }
        }

        // RULE 2: Use Unicode word boundary detection for everything else
        // This properly handles:
        // - International text (café, naïve, etc.)
        // - Various Unicode whitespace characters
        // - Em-dashes, ellipses, and other Unicode punctuation
        // - Complex scripts (Thai, Japanese, etc.)
        let combined = text1 + text2
        let junctionIndex = text1.endIndex

        var wordBoundaries: Set<String.Index> = []
        combined.enumerateSubstrings(in: combined.startIndex..<combined.endIndex, options: .byWords) { _, substringRange, _, _ in
            wordBoundaries.insert(substringRange.lowerBound)
            wordBoundaries.insert(substringRange.upperBound)
        }

        return wordBoundaries.contains(junctionIndex)
    }

    // MARK: - Punctuation Classification

    /// Classification for punctuation line breaking rules
    enum PunctuationClass {
        case openingPunctuation   // Never break after these: ( [ { " ' « ‹ and CJK 「『（【〔〈《
        case closingPunctuation   // Never break before these: ) ] } " ' » › and CJK 」』）】〕〉》
        case sentenceEnding       // Never break before these: . , ; : ! ? and CJK 。、！？：；
        case cjkSmallKana         // Never break before these: ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ
        case neutral              // Normal punctuation with no special rules
    }

    /// Classify a character for punctuation line breaking rules
    private func classifyPunctuation(_ char: Character) -> PunctuationClass {
        let scalar = String(char).unicodeScalars.first?.value ?? 0

        // Latin opening punctuation - never break after
        if "([{".contains(char) { return .openingPunctuation }

        // Latin closing punctuation and sentence-ending - never break before
        if ")]}".contains(char) { return .closingPunctuation }
        if ".,;:!?".contains(char) { return .sentenceEnding }

        // Latin quotation marks - opening quotes
        // U+0022 " QUOTATION MARK, U+0027 ' APOSTROPHE
        // U+2018 ' LEFT SINGLE QUOTATION MARK, U+201C " LEFT DOUBLE QUOTATION MARK
        // U+00AB « LEFT-POINTING DOUBLE ANGLE QUOTATION MARK, U+2039 ‹ SINGLE LEFT-POINTING ANGLE QUOTATION MARK
        if scalar == 0x0022 || scalar == 0x0027 ||  // Basic quotes
           scalar == 0x2018 || scalar == 0x201C ||  // Curly left quotes
           scalar == 0x00AB || scalar == 0x2039 {   // Guillemets
            return .openingPunctuation
        }

        // Latin quotation marks - closing quotes
        // U+2019 ' RIGHT SINGLE QUOTATION MARK, U+201D " RIGHT DOUBLE QUOTATION MARK
        // U+00BB » RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK, U+203A › SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
        if scalar == 0x2019 || scalar == 0x201D ||  // Curly right quotes
           scalar == 0x00BB || scalar == 0x203A {   // Guillemets
            return .closingPunctuation
        }

        // CJK opening brackets (禁則: line-start prohibited)
        // Japanese/Chinese full-width brackets and corner brackets
        if "「『（【〔〈《".contains(char) {
            return .openingPunctuation
        }

        // CJK closing brackets (禁則: line-end prohibited)
        if "」』）】〕〉》".contains(char) {
            return .closingPunctuation
        }

        // CJK sentence-ending punctuation (禁則: line-end prohibited)
        // Japanese/Chinese full-width periods, commas, and other punctuation
        if "。、！？：；".contains(char) {
            return .sentenceEnding
        }

        // CJK small kana (禁則: line-end prohibited)
        // These are smaller versions of hiragana/katakana that must not start a line
        if "ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ".contains(char) {
            return .cjkSmallKana
        }

        // CJK iteration marks (禁則: line-end prohibited)
        if "ゝゞヽヾ々〻".contains(char) {
            return .cjkSmallKana  // Same rules as small kana
        }

        // CJK prolonged sound mark (禁則: line-end prohibited)
        if char == "ー" {
            return .cjkSmallKana  // Same rules as small kana
        }

        return .neutral
    }

    /// Determine break rules for punctuation based on its classification
    private func punctuationBreakRules(_ char: Character) -> (isBreakBefore: Bool, isBreakAfter: Bool, penaltyBefore: Int, penaltyAfter: Int) {
        let classification = classifyPunctuation(char)

        switch classification {
        case .openingPunctuation:
            // Opening punctuation: can break before, NEVER after
            // Examples: ( [ { " ' « 「『
            return (true, false, MTBreakPenalty.good, MTBreakPenalty.never)

        case .closingPunctuation:
            // Closing punctuation: NEVER before, can break after
            // Examples: ) ] } " ' » 」』
            return (false, true, MTBreakPenalty.never, MTBreakPenalty.good)

        case .sentenceEnding:
            // Sentence-ending punctuation: NEVER before, good break after
            // Examples: . , ; : ! ? 。、
            return (false, true, MTBreakPenalty.never, MTBreakPenalty.best)

        case .cjkSmallKana:
            // CJK small kana and iteration marks: NEVER before, can break after
            // Examples: っゃゅょゎ ゝゞ ー
            return (false, true, MTBreakPenalty.never, MTBreakPenalty.good)

        case .neutral:
            // Other punctuation: use default rules
            return (true, true, MTBreakPenalty.good, MTBreakPenalty.good)
        }
    }

    // MARK: - Operator Tokenization

    private func tokenizeOperator(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let op = atom.nucleus
        guard !op.isEmpty else { return nil }

        // Calculate width with operator spacing
        let width = widthCalculator.measureOperator(op, type: atom.type)

        let ascent = font.fontSize * 0.5
        let descent = font.fontSize * 0.2
        let height = ascent + descent

        return MTBreakableElement(
            content: .operator(op, type: atom.type),
            width: width,
            height: height,
            ascent: ascent,
            descent: descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.best,  // Operators are best break points
            penaltyAfter: MTBreakPenalty.best,
            groupId: nil,
            parentId: nil,
            originalAtom: atom,
            indexRange: atom.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: false
        )
    }

    // MARK: - Delimiter Tokenization

    private func tokenizeOpenDelimiter(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let delimiter = atom.nucleus
        let width = widthCalculator.measureText(delimiter)
        let ascent = font.fontSize * 0.6
        let descent = font.fontSize * 0.2

        return MTBreakableElement(
            content: .text(delimiter),
            width: width,
            height: ascent + descent,
            ascent: ascent,
            descent: descent,
            isBreakBefore: true,
            isBreakAfter: false,  // NEVER break after open delimiter
            penaltyBefore: MTBreakPenalty.acceptable,
            penaltyAfter: MTBreakPenalty.bad,
            groupId: nil,
            parentId: nil,
            originalAtom: atom,
            indexRange: atom.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: false
        )
    }

    private func tokenizeCloseDelimiter(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let delimiter = atom.nucleus
        let width = widthCalculator.measureText(delimiter)
        let ascent = font.fontSize * 0.6
        let descent = font.fontSize * 0.2

        return MTBreakableElement(
            content: .text(delimiter),
            width: width,
            height: ascent + descent,
            ascent: ascent,
            descent: descent,
            isBreakBefore: false,  // NEVER break before close delimiter
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.bad,
            penaltyAfter: MTBreakPenalty.acceptable,
            groupId: nil,
            parentId: nil,
            originalAtom: atom,
            indexRange: atom.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: false
        )
    }

    // MARK: - Punctuation Tokenization

    private func tokenizePunctuation(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let punct = atom.nucleus
        let width = widthCalculator.measureText(punct)
        let ascent = font.fontSize * 0.5
        let descent = font.fontSize * 0.2

        // Apply proper punctuation breaking rules based on character classification
        // Default rules for multi-character punctuation or empty
        var isBreakBefore = false
        var isBreakAfter = true
        var penaltyBefore = MTBreakPenalty.bad
        var penaltyAfter = MTBreakPenalty.good

        // For single-character punctuation, use classification rules
        if punct.count == 1, let char = punct.first {
            (isBreakBefore, isBreakAfter, penaltyBefore, penaltyAfter) = punctuationBreakRules(char)
        }

        return MTBreakableElement(
            content: .text(punct),
            width: width,
            height: ascent + descent,
            ascent: ascent,
            descent: descent,
            isBreakBefore: isBreakBefore,
            isBreakAfter: isBreakAfter,
            penaltyBefore: penaltyBefore,
            penaltyAfter: penaltyAfter,
            groupId: nil,
            parentId: nil,
            originalAtom: atom,
            indexRange: atom.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: false
        )
    }

    // MARK: - Script Tokenization

    private func tokenizeAtomWithScripts(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int, allAtoms: [MTMathAtom]) -> [MTBreakableElement] {
        var elements: [MTBreakableElement] = []
        let groupId = UUID()  // All elements in this group must stay together

        // First, create the base element
        if let baseElement = tokenizeAtom(atom, prevAtom: prevAtom, atomIndex: atomIndex, allAtoms: allAtoms) {
            var modifiedBase = baseElement
            // Modify to be part of group
            modifiedBase = MTBreakableElement(
                content: baseElement.content,
                width: baseElement.width,
                height: baseElement.height,
                ascent: baseElement.ascent,
                descent: baseElement.descent,
                isBreakBefore: baseElement.isBreakBefore,
                isBreakAfter: false,  // Cannot break after base - must include scripts
                penaltyBefore: baseElement.penaltyBefore,
                penaltyAfter: MTBreakPenalty.never,
                groupId: groupId,
                parentId: nil,
                originalAtom: baseElement.originalAtom,
                indexRange: baseElement.indexRange,
                color: baseElement.color,
                backgroundColor: baseElement.backgroundColor,
                indivisible: baseElement.indivisible
            )
            elements.append(modifiedBase)
        }

        // Add superscript first if present (matches legacy typesetter order)
        if let superScript = atom.superScript {
            if let scriptDisplay = displayRenderer.renderScript(superScript, isSuper: true) {
                let scriptElement = MTBreakableElement(
                    content: .script(scriptDisplay, isSuper: true),
                    width: scriptDisplay.width,
                    height: scriptDisplay.ascent + scriptDisplay.descent,
                    ascent: scriptDisplay.ascent,
                    descent: scriptDisplay.descent,
                    isBreakBefore: false,  // Must stay with base
                    isBreakAfter: atom.subScript == nil,  // Can break after if last script
                    penaltyBefore: MTBreakPenalty.never,
                    penaltyAfter: atom.subScript == nil ? MTBreakPenalty.good : MTBreakPenalty.never,
                    groupId: groupId,
                    parentId: nil,
                    originalAtom: atom,
                    indexRange: atom.indexRange,
                    color: nil,
                    backgroundColor: nil,
                    indivisible: true
                )
                elements.append(scriptElement)
            }
        }

        // Add subscript after superscript (matches legacy typesetter order)
        if let subScript = atom.subScript {
            if let scriptDisplay = displayRenderer.renderScript(subScript, isSuper: false) {
                let scriptElement = MTBreakableElement(
                    content: .script(scriptDisplay, isSuper: false),
                    width: scriptDisplay.width,
                    height: scriptDisplay.ascent + scriptDisplay.descent,
                    ascent: scriptDisplay.ascent,
                    descent: scriptDisplay.descent,
                    isBreakBefore: false,  // Must stay with base
                    isBreakAfter: true,  // Can break after subscript (it's always last)
                    penaltyBefore: MTBreakPenalty.never,
                    penaltyAfter: MTBreakPenalty.good,
                    groupId: groupId,
                    parentId: nil,
                    originalAtom: atom,
                    indexRange: atom.indexRange,
                    color: nil,
                    backgroundColor: nil,
                    indivisible: true
                )
                elements.append(scriptElement)
            }
        }

        return elements
    }

    // MARK: - Complex Structure Tokenization

    private func tokenizeFraction(_ fraction: MTFraction, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        // Create a temporary typesetter to render the fraction
        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false)
        guard let display = typesetter.makeFraction(fraction) else { return nil }

        return MTBreakableElement(
            content: .display(display),
            width: display.width,
            height: display.ascent + display.descent,
            ascent: display.ascent,
            descent: display.descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.moderate,
            penaltyAfter: MTBreakPenalty.moderate,
            groupId: nil,
            parentId: nil,
            originalAtom: fraction,
            indexRange: fraction.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true  // Fractions are atomic
        )
    }

    private func tokenizeRadical(_ radical: MTRadical, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false)
        guard let display = typesetter.makeRadical(radical.radicand, range: radical.indexRange) else { return nil }

        // Add degree if present
        if radical.degree != nil {
            // Use .script style (71% size) instead of .scriptOfScript (50% size)
            // This matches TeX standard for radical degrees
            let degree = MTTypesetter.createLineForMathList(radical.degree, font: font, style: .script)
            display.setDegree(degree, fontMetrics: font.mathTable)
        }

        return MTBreakableElement(
            content: .display(display),
            width: display.width,
            height: display.ascent + display.descent,
            ascent: display.ascent,
            descent: display.descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.good,
            penaltyAfter: MTBreakPenalty.good,
            groupId: nil,
            parentId: nil,
            originalAtom: radical,
            indexRange: radical.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true  // Radicals are atomic
        )
    }

    private func tokenizeLargeOperator(_ op: MTLargeOperator, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        // CRITICAL DISTINCTION:
        // - If op.limits=true (e.g., \sum, \prod, \lim in text mode): Scripts go ABOVE/BELOW
        //   → makeLargeOp() creates MTLargeOpLimitsDisplay, which is self-contained
        //   → We should NOT clear scripts, let makeLargeOp() handle everything
        //
        // - If op.limits=false (e.g., \int in text mode): Scripts go TO THE SIDE
        //   → makeLargeOp() would create scripts via makeScripts(), causing duplication
        //   → We MUST clear scripts and let tokenizeAtomWithScripts() handle them separately

        let limits = op.limits && (style == .display || style == .text)

        let originalSuperScript = op.superScript
        let originalSubScript = op.subScript

        // Only clear scripts for side-script operators (limits=false)
        if !limits && (originalSuperScript != nil || originalSubScript != nil) {
            op.superScript = nil
            op.subScript = nil
        }

        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false)
        guard let operatorDisplay = typesetter.makeLargeOp(op) else {
            // Restore scripts before returning
            op.superScript = originalSuperScript
            op.subScript = originalSubScript
            return nil
        }

        // CRITICAL: Handle scripts based on positioning mode
        if !limits {
            // Side-script operators (limits=false): Restore scripts for tokenizeAtomWithScripts to handle
            op.superScript = originalSuperScript
            op.subScript = originalSubScript
        } else {
            // Limit operators (limits=true): Scripts are already rendered in MTLargeOpLimitsDisplay
            // MUST clear them from atom to prevent tokenizeAtomWithScripts from rendering them again
            op.superScript = nil
            op.subScript = nil
        }

        // CRITICAL: Handle italic correction (delta) for side-script operators
        // When scripts are present and limits is false, the operator width is reduced by delta
        // (see MTTypesetter.makeLargeOp line 1046-1050)
        // Since we cleared scripts for side-script operators, makeLargeOp() didn't apply this reduction
        var finalWidth = operatorDisplay.width

        if !limits && (originalSubScript != nil) {
            // Get the italic correction for the operator glyph
            if let glyphDisplay = operatorDisplay as? MTGlyphDisplay,
               let mathTable = font.mathTable {
                let delta = mathTable.getItalicCorrection(glyphDisplay.glyph)
                finalWidth -= delta
            }
        }

        let finalDisplay = operatorDisplay

        return MTBreakableElement(
            content: .display(finalDisplay),
            width: finalWidth,
            height: finalDisplay.ascent + finalDisplay.descent,
            ascent: finalDisplay.ascent,
            descent: finalDisplay.descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.good,
            penaltyAfter: MTBreakPenalty.good,
            groupId: nil,
            parentId: nil,
            originalAtom: op,
            indexRange: op.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true
        )
    }

    private func tokenizeAccent(_ accent: MTAccent, prevAtom: MTMathAtom?, atomIndex: Int, allAtoms: [MTMathAtom]) -> MTBreakableElement? {
        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false)
        guard let display = typesetter.makeAccent(accent) else { return nil }

        // Determine break rules - accents in text mode should respect word boundaries
        var isBreakBefore = true
        var isBreakAfter = true
        var penaltyBefore = MTBreakPenalty.good
        var penaltyAfter = MTBreakPenalty.good

        // Check if this accent is in a text context (the accented character is roman text)
        // An accent's innerList contains the base character(s)
        let isTextAccent = accent.innerList?.atoms.first?.fontStyle == .roman

        if isTextAccent {
            // Check previous atom - if it's a letter in text mode, don't break before
            if let prevAtom = prevAtom {
                let prevIsTextLetter = isTextLetterAtom(prevAtom)
                if prevIsTextLetter {
                    isBreakBefore = false
                    penaltyBefore = MTBreakPenalty.never
                }
            }

            // Check next atom - if it's a letter in text mode, don't break after
            if atomIndex + 1 < allAtoms.count {
                let nextAtom = allAtoms[atomIndex + 1]
                let nextIsTextLetter = isTextLetterAtom(nextAtom)
                if nextIsTextLetter {
                    isBreakAfter = false
                    penaltyAfter = MTBreakPenalty.never
                }
            }
        }

        return MTBreakableElement(
            content: .display(display),
            width: display.width,
            height: display.ascent + display.descent,
            ascent: display.ascent,
            descent: display.descent,
            isBreakBefore: isBreakBefore,
            isBreakAfter: isBreakAfter,
            penaltyBefore: penaltyBefore,
            penaltyAfter: penaltyAfter,
            groupId: nil,
            parentId: nil,
            originalAtom: accent,
            indexRange: accent.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true
        )
    }

    /// Helper to check if an atom is a letter in text mode (roman style)
    private func isTextLetterAtom(_ atom: MTMathAtom) -> Bool {
        // For accent atoms, check their inner content FIRST
        // (accent atom's nucleus contains the accent mark, not the letter)
        if let accent = atom as? MTAccent {
            if let firstInner = accent.innerList?.atoms.first {
                return isTextLetterAtom(firstInner)
            }
            return false
        }
        // For regular text atoms with roman style
        if atom.fontStyle == .roman {
            // Check if the nucleus contains only letters
            let nucleus = atom.nucleus
            if !nucleus.isEmpty {
                return nucleus.allSatisfy { $0.isLetter }
            }
        }
        return false
    }

    private func tokenizeUnderline(_ underline: MTUnderLine, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false)
        guard let display = typesetter.makeUnderline(underline) else { return nil }

        return MTBreakableElement(
            content: .display(display),
            width: display.width,
            height: display.ascent + display.descent,
            ascent: display.ascent,
            descent: display.descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.good,
            penaltyAfter: MTBreakPenalty.good,
            groupId: nil,
            parentId: nil,
            originalAtom: underline,
            indexRange: underline.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true
        )
    }

    private func tokenizeOverline(_ overline: MTOverLine, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false)
        guard let display = typesetter.makeOverline(overline) else { return nil }

        return MTBreakableElement(
            content: .display(display),
            width: display.width,
            height: display.ascent + display.descent,
            ascent: display.ascent,
            descent: display.descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.good,
            penaltyAfter: MTBreakPenalty.good,
            groupId: nil,
            parentId: nil,
            originalAtom: overline,
            indexRange: overline.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true
        )
    }

    private func tokenizeTable(_ table: MTMathTable, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false, maxWidth: maxWidth)
        guard let display = typesetter.makeTable(table) else { return nil }

        return MTBreakableElement(
            content: .display(display),
            width: display.width,
            height: display.ascent + display.descent,
            ascent: display.ascent,
            descent: display.descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.moderate,
            penaltyAfter: MTBreakPenalty.moderate,
            groupId: nil,
            parentId: nil,
            originalAtom: table,
            indexRange: table.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true
        )
    }

    private func tokenizeInner(_ inner: MTInner, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        let typesetter = MTTypesetter(withFont: font, style: style, cramped: cramped, spaced: false)
        guard let display = typesetter.makeLeftRight(inner) else { return nil }

        return MTBreakableElement(
            content: .display(display),
            width: display.width,
            height: display.ascent + display.descent,
            ascent: display.ascent,
            descent: display.descent,
            isBreakBefore: true,
            isBreakAfter: true,
            penaltyBefore: MTBreakPenalty.good,
            penaltyAfter: MTBreakPenalty.good,
            groupId: nil,
            parentId: nil,
            originalAtom: inner,
            indexRange: inner.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: false
        )
    }

    private func tokenizeSpace(_ atom: MTMathAtom, prevAtom: MTMathAtom?, atomIndex: Int) -> MTBreakableElement? {
        // Space atoms typically don't participate in breaking
        // They are rendered as-is
        let width = widthCalculator.measureSpace(atom.type)

        return MTBreakableElement(
            content: .space(width),
            width: width,
            height: 0,
            ascent: 0,
            descent: 0,
            isBreakBefore: false,
            isBreakAfter: false,
            penaltyBefore: MTBreakPenalty.never,
            penaltyAfter: MTBreakPenalty.never,
            groupId: nil,
            parentId: nil,
            originalAtom: atom,
            indexRange: atom.indexRange,
            color: nil,
            backgroundColor: nil,
            indivisible: true
        )
    }
}
