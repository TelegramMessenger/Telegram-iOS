#if canImport(UIKit)
/// Host-provided titles for the editor's custom edit-menu items.
@available(iOS 13.0, *)
public struct RichTextEditorMenuStrings: Equatable {
    public var format: String
    public var bold: String
    public var italic: String
    public var underline: String
    public var lookUp: String
    public var translate: String
    public var share: String

    public init(format: String, bold: String, italic: String, underline: String, lookUp: String, translate: String, share: String) {
        self.format = format
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.lookUp = lookUp
        self.translate = translate
        self.share = share
    }

    public static let `default` = RichTextEditorMenuStrings(
        format: "Format",
        bold: "Bold",
        italic: "Italic",
        underline: "Underline",
        lookUp: "Look Up",
        translate: "Translate",
        share: "Share"
    )
}
#endif
