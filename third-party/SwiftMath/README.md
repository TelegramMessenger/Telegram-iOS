# SwiftMath

`SwiftMath` provides a full Swift implementation of [iosMath](https://travis-ci.org/kostub/iosMath) 
for displaying beautifully rendered math equations in iOS and MacOS applications. It typesets formulae written 
using LaTeX in a `UILabel` equivalent class. It uses the same typesetting rules as LaTeX and
so the equations are rendered exactly as LaTeX would render them.

Please also check out [SwiftMathDemo](https://github.com/mgriebling/SwiftMathDemo.git) for examples of how to use `SwiftMath`
from SwiftUI.  

`SwiftMath` is similar to [MathJax](https://www.mathjax.org) or
[KaTeX](https://github.com/Khan/KaTeX) for the web but for native iOS or MacOS
applications without having to use a `UIWebView` and Javascript. More
importantly, it is significantly faster than using a `UIWebView`.

`SwiftMath` is a Swift translation of the latest `iosMath` v0.9.5 release but includes bug fixes
and enhancements like a new \lbar (lambda bar) character and cyrillic alphabet support.
The original `iosMath` test suites have also been translated to Swift and run without errors.
Note: Error test conditions are ignored to avoid tagging everything with silly `throw`s.
Please let me know of any bugs or bug fixes that you find. 

`SwiftMath` prepackages everything needed for direct access via the Swift Package Manager.

## Examples
Here are screenshots of some formulae that were rendered with this library:

```LaTeX
x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}
```

![Quadratic Formula](img/quadratic-light.png#gh-light-mode-only) 
![Quadratic Formula](img/quadratic-dark.png#gh-dark-mode-only) 

```LaTeX
f(x) = \int\limits_{-\infty}^\infty\!\hat f(\xi)\,e^{2 \pi i \xi x}\,\mathrm{d}\xi
```

![Calculus](img/calculus-light.png#gh-light-mode-only) 
![Calculus](img/calculus-dark.png#gh-dark-mode-only) 

```LaTeX
\frac{1}{n}\sum_{i=1}^{n}x_i \geq \sqrt[n]{\prod_{i=1}^{n}x_i}
```

![AM-GM](img/amgm-light.png#gh-light-mode-only) 
![AM-GM](img/amgm-dark.png#gh-dark-mode-only) 

```LaTex
\frac{1}{\left(\sqrt{\phi \sqrt{5}}-\phi\\right) e^{\frac25 \pi}}
= 1+\frac{e^{-2\pi}} {1 +\frac{e^{-4\pi}} {1+\frac{e^{-6\pi}} {1+\frac{e^{-8\pi}} {1+\cdots} } } }
```

![Ramanujan Identity](img/ramanujan-light.png#gh-light-mode-only) 
![Ramanujan Identity](img/ramanujan-dark.png#gh-dark-mode-only) 

More examples are included in [EXAMPLES](EXAMPLES.md)

## Fonts
Here are previews of the included fonts:

![](img/FontsPreview.png#gh-dark-mode-only) 
![](img/FontsPreviewLight.png#gh-light-mode-only) 
 
## Requirements
`SwiftMath` works on iOS 11+ or MacOS 12+. It depends
on the following Apple frameworks:

* Foundation.framework
* CoreGraphics.framework
* QuartzCore.framework
* CoreText.framework

Additionally for iOS it requires:
* UIKit.framework

Additionally for MacOS it requires:
* AppKit.framework

## Installation

### Swift Package

`SwiftMath` is available from [SwiftMath](https://github.com/mgriebling/SwiftMath.git). 
To use it in your code, just add the https://github.com/mgriebling/SwiftMath.git path to
XCode's package manager.

## Usage

The library provides a class `MTMathUILabel` which is a `UIView` that
supports rendering math equations. To display an equation simply create
an `MTMathUILabel` as follows:

```swift

import SwiftMath

let label = MTMathUILabel()
label.latex = "x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}"

```
Adding `MTMathUILabel` as a sub-view of your `UIView` will render the
quadratic formula example shown above.

The following code creates a SwiftUI component called `MathView` encapsulating the MTMathUILabel:

```swift
import SwiftUI
import SwiftMath

struct MathView: UIViewRepresentable {
    var equation: String
    var font: MathFont = .latinModernFont
    var textAlignment: MTTextAlignment = .center
    var fontSize: CGFloat = 30
    var labelMode: MTMathUILabelMode = .text
    var insets: MTEdgeInsets = MTEdgeInsets()

    func makeUIView(context: Context) -> MTMathUILabel {
        let view = MTMathUILabel()
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: MTMathUILabel, context: Context) {
        view.latex = equation
        let font = MTFontManager().font(withName: font.rawValue, size: fontSize)
        font?.fallbackFont = UIFont.systemFont(ofSize: fontSize)
        view.font = font
        view.textAlignment = textAlignment
        view.labelMode = labelMode
        view.textColor = MTColor(Color.primary)
        view.contentInsets = insets
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MTMathUILabel, context: Context) -> CGSize? {
        // Enable line wrapping by passing proposed width to the label
        if let width = proposal.width, width.isFinite, width > 0 {
            uiView.preferredMaxLayoutWidth = width
            let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return size
        }
        return nil
    }
}
```

For code that works with SwiftUI running natively under MacOS use the following:

```swift
import SwiftUI
import SwiftMath

struct MathView: NSViewRepresentable {
    var equation: String
    var font: MathFont = .latinModernFont
    var textAlignment: MTTextAlignment = .center
    var fontSize: CGFloat = 30
    var labelMode: MTMathUILabelMode = .text
    var insets: MTEdgeInsets = MTEdgeInsets()

    func makeNSView(context: Context) -> MTMathUILabel {
        let view = MTMathUILabel()
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    func updateNSView(_ view: MTMathUILabel, context: Context) {
        view.latex = equation
        let font = MTFontManager().font(withName: font.rawValue, size: fontSize)
        font?.fallbackFont = NSFont.systemFont(ofSize: fontSize)
        view.font = font
        view.textAlignment = textAlignment
        view.labelMode = labelMode
        view.textColor = MTColor(Color.primary)
        view.contentInsets = insets
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MTMathUILabel, context: Context) -> CGSize? {
        // Enable line wrapping by passing proposed width to the label
        if let width = proposal.width, width.isFinite, width > 0 {
            nsView.preferredMaxLayoutWidth = width
            let size = nsView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return size
        }
        return nil
    }
}
```

### Automatic Line Wrapping

`SwiftMath` supports automatic line wrapping (multiline display) for mathematical content. The implementation uses **interatom line breaking** which breaks equations at atom boundaries (between mathematical elements) rather than within them, preserving the semantic structure of the mathematics.

#### Using Line Wrapping with UIKit/AppKit

For direct `MTMathUILabel` usage, set the `preferredMaxLayoutWidth` property:

```swift
let label = MTMathUILabel()
label.latex = "\\text{Calculer le discriminant }\\Delta=b^{2}-4ac\\text{ avec }a=1\\text{, }b=-1\\text{, }c=-5"
label.font = MTFontManager.fontManager.defaultFont

// Enable line wrapping by setting a maximum width
label.preferredMaxLayoutWidth = 235
```

You can also use `sizeThatFits` to calculate the size with a width constraint:

```swift
let constrainedSize = label.sizeThatFits(CGSize(width: 235, height: .greatestFiniteMagnitude))
```

#### Using Line Wrapping with SwiftUI

The `MathView` examples above include `sizeThatFits()` which automatically enables line wrapping when SwiftUI proposes a width constraint. No additional configuration is needed:

```swift
VStack(alignment: .leading, spacing: 8) {
    MathView(
        equation: "\\text{Calculer le discriminant }\\Delta=b^{2}-4ac\\text{ avec }a=1\\text{, }b=-1\\text{, }c=-5",
        fontSize: 17,
        labelMode: .text
    )
}
.frame(maxWidth: 235)  // The equation will break across multiple lines
```

#### Line Wrapping Behavior and Capabilities

SwiftMath implements **two complementary line breaking mechanisms**:

##### 1. Interatom Line Breaking (Primary)
Breaks equations **between atoms** (mathematical elements) when content exceeds the width constraint. This is the preferred method as it maintains semantic integrity.

##### 2. Universal Line Breaking (Fallback)
For very long text within single atoms, breaks at Unicode word boundaries using Core Text with number protection (prevents splitting numbers like "3.14").

See `MULTILINE_IMPLEMENTATION_NOTES.md` for implementation details and recent changes.

#### Fully Supported Cases

These atom types work perfectly with interatom line breaking:

**✅ Variables and ordinary text:**
```swift
label.latex = "a b c d e f g h i j k l m n o p"
label.preferredMaxLayoutWidth = 150
// Breaks between individual variables at natural boundaries
```

**✅ Binary operators (+, -, ×, ÷):**
```swift
label.latex = "a+b+c+d+e+f+g+h"
label.preferredMaxLayoutWidth = 100
// Breaks cleanly: "a+b+c+d+"
//                 "e+f+g+h"
```

**✅ Relations (=, <, >, ≤, ≥, etc.):**
```swift
label.latex = "a=1, b=2, c=3, d=4, e=5"
label.preferredMaxLayoutWidth = 120
// Breaks after commas and operators
```

**✅ Mixed text and simple math:**
```swift
label.latex = "\\text{Calculer }\\Delta=b^{2}-4ac\\text{ avec }a=1\\text{, }b=-1"
label.preferredMaxLayoutWidth = 200
// Breaks between text and math atoms naturally
```

**✅ Punctuation (commas, periods):**
```swift
label.latex = "\\text{First, second, third, fourth, fifth}"
label.preferredMaxLayoutWidth = 150
// Breaks at commas and spaces
```

**✅ Brackets and parentheses (simple):**
```swift
label.latex = "(a+b)+(c+d)+(e+f)"
label.preferredMaxLayoutWidth = 120
// Breaks between parenthesized groups
```

**✅ Greek letters and symbols:**
```swift
label.latex = "\\alpha+\\beta+\\gamma+\\delta+\\epsilon+\\zeta"
label.preferredMaxLayoutWidth = 150
// Breaks between Greek letters
```

**✅ Fractions (NEW!):**
```swift
label.latex = "a+\\frac{1}{2}+b+\\frac{3}{4}+c"
label.preferredMaxLayoutWidth = 150
// Fractions stay inline if they fit, break to new line only when needed
// Example: "a + ½ + b" stays on one line if it fits
```

**✅ Radicals/Square roots (NEW!):**
```swift
label.latex = "x+\\sqrt{2}+y+\\sqrt{3}+z"
label.preferredMaxLayoutWidth = 150
// Radicals stay inline if they fit, break to new line only when needed
// Example: "x + √2 + y" stays on one line if it fits
```

**✅ Mixed fractions and radicals (NEW!):**
```swift
label.latex = "a+\\frac{1}{2}+\\sqrt{3}+b"
label.preferredMaxLayoutWidth = 200
// Breaks between complex mathematical elements
```

#### Limited Support Cases

These cases work but with some constraints:

**✅ Large operators (NEW!):**
```swift
label.latex = "a + \\sum_{i=1}^{n} x_i + \\int_{0}^{1} f(x)dx + b"
label.preferredMaxLayoutWidth = 200
// Large operators stay inline when they fit!
// Includes height checking for operators with limits
```

**✅ Delimited expressions (NEW!):**
```swift
label.latex = "(a+b) + \\left(\\frac{c}{d}\\right) + e"
label.preferredMaxLayoutWidth = 200
// Delimiters stay inline when they fit!
// Inner content respects width constraints and wraps naturally
```

**✅ Colored expressions (NEW!):**
```swift
label.latex = "a + \\color{red}{b + c + d} + e"
label.preferredMaxLayoutWidth = 200
// Colored sections stay inline when they fit!
// Inner content respects width constraints and wraps properly
```

**✅ Matrices/tables (NEW!):**
```swift
label.latex = "A = \\begin{pmatrix} 1 & 2 \\end{pmatrix} + B"
label.preferredMaxLayoutWidth = 200
// Small matrices stay inline when they fit!
```

**✅ Atoms with superscripts/subscripts (IMPROVED!):**
```swift
label.latex = "a^{2}+b^{2}+c^{2}+d^{2}+e^{2}"
label.preferredMaxLayoutWidth = 150
// Now works with width-based breaking!
// Scripted atoms participate in smart line breaking decisions
```

**✅ Math accents:**
```swift
label.latex = "\\hat{x} + \\tilde{y} + \\bar{z} + \\vec{w}"
label.preferredMaxLayoutWidth = 150
// Common accents (\hat, \tilde, \bar, \vec) work well
// Vector arrows (\overrightarrow, etc.) supported with stretching
```

**⚠️ Very long single text atoms:**
```swift
label.latex = "\\text{This is an extremely long piece of text within a single text command}"
label.preferredMaxLayoutWidth = 200
// Uses Unicode word boundary breaking with Core Text
// Protects numbers from being split (e.g., "3.14" stays together)
```
**Note**: Breaks within the text atom rather than between atoms, which is expected behavior for very long continuous text.

#### Best Practices

**DO:**
- Use interatom breaking for simple equations with operators and relations
- Use for mixed text and math where you want natural breaks
- Use for long sequences of variables, numbers, and operators
- Set appropriate `preferredMaxLayoutWidth` based on your layout needs

**DON'T:**
- Expect natural breaking in expressions with large operators (∑, ∫, etc. - not yet optimized)
- Expect natural breaking in expressions with \left...\right delimiters (not yet optimized)
- Use extremely narrow widths (less than ~80pt) which may cause poor breaks

#### Examples

**Excellent use case (discriminant formula):**
```swift
label.latex = "\\text{Calculer le discriminant }\\Delta=b^{2}-4ac\\text{ avec }a=1\\text{, }b=-1\\text{, }c=-5"
label.preferredMaxLayoutWidth = 235
// ✅ Breaks naturally at good points between atoms
```

**Good use case (simple arithmetic):**
```swift
label.latex = "5+10+15+20+25+30+35+40+45+50"
label.preferredMaxLayoutWidth = 150
// ✅ Breaks between operators cleanly
```

**Excellent use case (fractions inline - NEW!):**
```swift
label.latex = "a+\\frac{1}{2}+b+\\frac{3}{4}+c"
label.preferredMaxLayoutWidth = 200
// ✅ Fractions stay inline when they fit!
// Breaks: "a + ½ + b" on line 1, "+ ¾ + c" on line 2
```

**Excellent use case (radicals inline - NEW!):**
```swift
label.latex = "x+\\sqrt{2}+y+\\sqrt{3}+z"
label.preferredMaxLayoutWidth = 150
// ✅ Radicals stay inline when they fit!
// Example: "x + √2 + y" on line 1, "+ √3 + z" on line 2
```

**Alternative for complex expressions:**
```swift
// Instead of trying to break this:
label.latex = "x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}"
// Consider it as a single display equation without width constraint
label.preferredMaxLayoutWidth = 0  // No breaking
```

#### Technical Details

- **Line spacing**: Dynamic line height based on actual content (tall fractions get more space, regular content stays compact)
- **Breaking algorithm**: Greedy with look-ahead and break quality scoring - prefers breaking after operators over other positions
- **Width calculation**: Includes inter-element spacing according to TeX spacing rules
- **Number protection**: Numbers in patterns like "3.14", "1,000", etc. are kept intact
- **Supports locales**: English, French, Swiss number formats
- **Advanced features**: Tokenization infrastructure with phase-based processing (preprocessing → tokenization → line fitting → display generation)

For complete implementation details including recent improvements (dynamic line height, break quality scoring, early exit optimization), see [MULTILINE_IMPLEMENTATION_NOTES.md](MULTILINE_IMPLEMENTATION_NOTES.md).

### Included Features
This is a list of formula types that the library currently supports:

* Simple algebraic equations
* Fractions and continued fractions (including `\frac`, `\dfrac`, `\tfrac`, `\cfrac`)
* Exponents and subscripts
* Trigonometric formulae (including inverse hyperbolic: `\arcsinh`, `\arccosh`, etc.)
* Square roots and n-th roots
* Calculus symbols - limits, derivatives, integrals (including `\iint`, `\iiint`, `\iiiint`)
* Big operators (e.g. product, sum)
* Big delimiters (using `\left` and `\right`)
* Manual delimiter sizing (`\big`, `\Big`, `\bigg`, `\Bigg` and variants)
* Greek alphabet
* Bold Greek symbols (`\boldsymbol`)
* Combinatorics (`\binom`, `\choose` etc.)
* Geometry symbols (e.g. angle, congruence etc.)
* Ratios, proportions, percentages
* Math spacing
* Overline and underline
* Math accents (including `\hat`, `\tilde`, `\bar`, `\vec`, `\dot`, `\ddot`, etc.)
* Vector arrows (`\vec`, `\overrightarrow`, `\overleftarrow`, `\overleftrightarrow` with automatic stretching)
* Wide accents (`\widehat`, `\widetilde`)
* Operator names (`\operatorname{name}`)
* Matrices (including `\smallmatrix` and starred variants like `pmatrix*` with alignment)
* Multi-line subscripts and limits (`\substack`)
* Equation alignment
* Change bold, roman, caligraphic and other font styles (`\bf`, `\text`, etc.)
* Style commands (`\displaystyle`, `\textstyle`)
* Custom operators (`\operatorname`, `\operatorname*`)
* Dirac notation (`\bra`, `\ket`, `\braket`)
* Most commonly used math symbols
* Colors for both text and background
* **Inline and display math mode delimiters** (see below)
* **Automatic line wrapping** (see Automatic Line Wrapping section)

### LaTeX Math Delimiters

`SwiftMath` now supports all standard LaTeX math delimiters for both inline and display modes. The parser automatically detects and handles these delimiters:

#### Inline Math (Text Style)
Use these delimiters for inline math within text, which renders more compactly:

```swift
// Dollar signs (TeX style)
label.latex = "$E = mc^2$"

// Parentheses (LaTeX style)
label.latex = "\\(\\sum_{i=1}^{n} x_i\\)"

// Cases environment in inline mode
label.latex = "\\(\\begin{cases} x + y = 5 \\\\ 2x - y = 1 \\end{cases}\\)"
```

#### Display Math (Display Style)
Use these delimiters for standalone equations with larger operators and limits:

```swift
// Double dollar signs (TeX style)
label.latex = "$$\\int_{0}^{\\infty} e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$"

// Square brackets (LaTeX style)
label.latex = "\\[\\sum_{k=1}^{n} k^2 = \\frac{n(n+1)(2n+1)}{6}\\]"

// Equation environment
label.latex = "\\begin{equation} x^2 + y^2 = z^2 \\end{equation}"

// Cases environment in display mode
label.latex = "\\begin{cases} x + y = 5 \\\\ 2x - y = 1 \\end{cases}"
```

**Note:** The difference between inline and display modes:
- **Inline mode** (`$...$` or `\(...\)`) renders compactly, suitable for math within text
- **Display mode** (`$$...$$`, `\[...\]`, or environments) renders with larger operators and limits positioned above/below

All delimiters are automatically stripped during parsing, and the math mode is set appropriately. No additional configuration is needed!

#### Backward Compatibility
Equations without explicit delimiters continue to work as before, defaulting to display mode:

```swift
label.latex = "x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}"  // Works as always
```

#### Programmatic API
For advanced use cases where you need to parse LaTeX and determine the detected style programmatically, use the `buildWithStyle` method:

```swift
// Parse LaTeX and get both the math list and detected style
let (mathList, style) = MTMathListBuilder.buildWithStyle(fromString: "\\[x^2 + y^2 = z^2\\]")

// style will be .display for \[...\] or $$...$$
// style will be .text for \(...\) or $...$

// Create a display with the detected style
if let mathList = mathList {
    let display = MTTypesetter.createLineForMathList(mathList, font: myFont, style: style)
    // Use the display for rendering
}
```

This is particularly useful when building custom renderers or when you need to respect the user's choice of delimiter style.

Note: SwiftMath only supports the commands in LaTeX's math mode. There is
also no language support for other than west European langugages and some
Cyrillic characters. There would be two ways to support more languages:

1) Find a math font compatible with `SwiftMath` that contains all the glyphs
for that language.
2) Add support to `SwiftMath` for standard Unicode fonts that contain all
langauge glyphs.

Of these two, the first is much easier.  However, if you want a challenge,
try to tackle the second option.

### Example

The [SwiftMathDemo](https://github.com/mgriebling/SwiftMathDemo) is a SwiftUI version
of the Objective-C demo included in `iosMath` that uses `SwiftMath` as a Swift package dependency.

### Advanced configuration

`MTMathUILabel` supports some advanced configuration options:

##### Math mode

You can change the mode of the `MTMathUILabel` between Display Mode
(equivalent to `$$` or `\[` in LaTeX) and Text Mode (equivalent to `$`
or `\(` in LaTeX). The default style is Display. To switch to Text
simply:

```swift
label.labelMode = .text
```

##### Text Alignment
The default alignment of the equations is left. This can be changed to
center or right as follows:

```swift
label.textAlignment = .center
```

##### Font size
The default font-size is 30pt. You can change it as follows:

```swift
label.fontSize = 25
```
##### Font
The default font is *Latin Modern Math*. This can be changed as:

```swift
label.font = MTFontManager.fontmanager.termesFont(withSize:20)
```

This project has 12 fonts bundled with it, but you can use any OTF math
font. A python script is included that generates the `.plist` files 
required for an `.otf` font to work with `SwiftMath`.  If you generate
(and test) any other fonts please contribute them back to this project for
others to benefit.



Note: The `KpMath-Light`, `KpMath-Sans`, `Asana` fonts currently incorrectly
render very large radicals. It appears that the font files do
not properly define the offsets required to typeset these glyphs.  If
anyone can fix this, it would be greatly appreciated.

##### Text Color
The default color of the rendered equation is black. You can change
it to any other color as follows:

```swift
label.textColor = .red
```

It is also possible to set different colors for different parts of the
equation. Just access the `displayList` field and set the `textColor`
of the underlying displays of which you want to change the color. 

##### Fallback Font for Unicode Text
By default, math fonts only support a limited set of characters (Latin, Greek, common math symbols).
To display other Unicode characters like Chinese, Japanese, Korean, emoji, or other scripts in `\text{}`
commands, you can configure a fallback font:

```swift
let mathFont = MTFontManager().font(withName: MathFont.latinModernFont.rawValue, size: 30)

// Set a fallback font for unsupported characters (defaults to nil)
#if os(iOS) || os(visionOS)
let systemFont = UIFont.systemFont(ofSize: 30)
mathFont?.fallbackFont = CTFontCreateWithName(systemFont.fontName as CFString, 30, nil)
#elseif os(macOS)
let systemFont = NSFont.systemFont(ofSize: 30)
mathFont?.fallbackFont = CTFontCreateWithName(systemFont.fontName as CFString, 30, nil)
#endif

label.font = mathFont
label.latex = "\\text{Hello 世界 🌍}"  // English, Chinese, and emoji
```

When the main math font doesn't contain a glyph for a character, the fallback font will be used automatically.
This is particularly useful for:
- Chinese text: `\text{中文}`
- Japanese text: `\text{日本語}`
- Korean text: `\text{한국어}`
- Emoji: `\text{Math is fun! 🎉📐}`
- Mixed scripts: `\text{Equation: 方程式}`

**Note**: The fallback font only applies to characters within `\text{}` commands, not regular math mode.

##### Custom Commands
You can define your own commands that are not already predefined. This is
similar to macros is LaTeX. To define your own command use:

```swift
MTMathAtomFactory.addLatexSymbol("lcm", value: MTMathAtomFactory.operator(withName: "lcm", limits: false))
```

This creates an `\lcm` command that can be used in the LaTeX.

##### Content Insets
The `MTMathUILabel` has `contentInsets` for finer control of placement of the
equation in relation to the view.

If you need to set it you can do as follows:

```swift
label.contentInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 20)
```

##### Error handling

If the LaTeX text given to `MTMathUILabel` is
invalid or if it contains commands that aren't currently supported then
an error message will be displayed instead of the label.

This error can be programmatically retrieved as `label.error`. If you
prefer not to display anything then set:

```swift
label.displayErrorInline = true
```

## Future Enhancements

Note this is not a complete implementation of LaTeX math mode. There are
some pieces that are missing and may be included in future updates:

* `\middle` delimiter for use between `\left` and `\right`
* Some fine spacing commands (`\:`, `\;`, `\!` - note that `\,` works)

For a complete list of features and their implementation status, see [MISSING_FEATURES.md](MISSING_FEATURES.md).

## License

`SwiftMath` is available under the MIT license. See the [LICENSE](./LICENSE)
file for more info.

### Fonts
This distribution contains the following fonts. These fonts are
licensed as follows:
* Latin Modern Math: 
    [GUST Font License](GUST-FONT-LICENSE.txt)
* Tex Gyre Termes:
    [GUST Font License](GUST-FONT-LICENSE.txt)
* [XITS Math](https://github.com/khaledhosny/xits-math):
    [Open Font License](OFL.txt)
* [KpMath Light/KpMath Sans](http://scripts.sil.org/OFL):
    [SIL Open Font License](OFL.txt)
