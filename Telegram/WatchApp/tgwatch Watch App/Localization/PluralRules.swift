import Foundation

enum PluralForm {
    case zero
    case one
    case two
    case few
    case many
    case other
}

/// CLDR plural form of `n` for a language pack's `plural_code`.
///
/// A port of the iOS app's `numberPluralizationForm`
/// (submodules/NumberPluralizationForm), so the watch picks the same form
/// as the iPhone for the same language pack string.
func pluralForm(languageCode: String, _ n: Int) -> PluralForm {
    let code = languageCode.lowercased()
    let lc = code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? code
    let n = abs(n)
    let mod10 = n % 10
    let mod100 = n % 100

    switch lc {
    case "lt":
        if mod10 == 1 && !(11...19).contains(mod100) { return .one }
        if (2...9).contains(mod10) && !(11...19).contains(mod100) { return .few }
    case "lv":
        if n == 0 { return .zero }
        if mod10 == 1 && mod100 != 11 { return .one }
    case "cy":
        if n == 2 { return .two }
        if n == 3 { return .few }
        if n == 0 { return .zero }
        if n == 1 { return .one }
        if n == 6 { return .many }
    case "be", "ru", "uk":
        if mod10 == 1 && mod100 != 11 { return .one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
        if mod10 == 0 || (5...9).contains(mod10) || (11...14).contains(mod100) { return .many }
    case "bs", "hr", "sh", "sr":
        if mod10 == 1 && mod100 != 11 { return .one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
    case "ksh":
        if n == 0 { return .zero }
        if n == 1 { return .one }
    case "shi":
        if (2...10).contains(n) { return .few }
        if (0...1).contains(n) { return .one }
    case "he":
        if n == 2 { return .two }
        if n == 1 { return .one }
        if n != 0 && mod10 == 0 { return .many }
    case "cs", "sk":
        if n == 1 { return .one }
        if (2...4).contains(n) { return .few }
    case "br":
        if n != 0 && n % 1_000_000 == 0 { return .many }
        if mod10 == 1 && ![11, 71, 91].contains(mod100) { return .one }
        if mod10 == 2 && ![12, 72, 92].contains(mod100) { return .two }
        if ((3...4).contains(mod10) || mod10 == 9)
            && !(10...19).contains(mod100) && !(70...79).contains(mod100) && !(90...99).contains(mod100) {
            return .few
        }
    case "sl":
        if mod100 == 2 { return .two }
        if mod100 == 1 { return .one }
        if (3...4).contains(mod100) { return .few }
    case "lag":
        if n == 0 { return .zero }
        if n == 1 { return .one }
    case "pl":
        if n == 1 { return .one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
        if (0...1).contains(mod10) || (5...9).contains(mod10) || (12...14).contains(mod100) { return .many }
    case "gd":
        if n == 2 || n == 12 { return .two }
        if n == 1 || n == 11 { return .one }
        if (3...10).contains(n) || (13...19).contains(n) { return .few }
    case "gv":
        if (1...2).contains(mod10) || n % 20 == 0 { return .one }
    case "mk":
        if mod10 == 1 && n != 11 { return .one }
    case "mt":
        if n == 1 { return .one }
        if (11...19).contains(mod100) { return .many }
        if n == 0 || (2...10).contains(mod100) { return .few }
    case "mo", "ro":
        if n == 1 { return .one }
        if n == 0 || (1...19).contains(mod100) { return .few }
    case "ga":
        if n == 2 { return .two }
        if n == 1 { return .one }
        if (3...6).contains(n) { return .few }
        if (7...10).contains(n) { return .many }
    case "ff", "fr", "kab":
        if n == 0 || n == 1 { return .one }
    case "iu", "kw", "se", "naq", "sma", "smi", "smj", "smn", "sms":
        if n == 2 { return .two }
        if n == 1 { return .one }
    case "ak", "am", "bh", "hi", "ln", "mg", "ti", "tl", "wa", "fil", "guw", "nso":
        if n == 0 || n == 1 { return .one }
    case "tzm":
        if (0...1).contains(n) || (11...99).contains(n) { return .one }
    case "af", "bg", "bn", "ca", "da", "de", "dv", "ee", "el", "en", "eo", "es", "et", "eu", "fi",
         "fo", "fy", "gl", "gu", "ha", "is", "it", "kk", "kl", "ks", "ku", "ky", "lb", "lg", "ml",
         "mn", "mr", "nb", "nd", "ne", "nl", "nn", "no", "nr", "ny", "om", "or", "os", "pa", "ps",
         "pt", "rm", "sn", "so", "sq", "ss", "st", "sv", "sw", "ta", "te", "tk", "tn", "ts", "ur",
         "ve", "vo", "xh", "zu", "asa", "ast", "bem", "bez", "brx", "cgg", "chr", "ckb", "fur",
         "gsw", "haw", "jgo", "jmc", "kaj", "kcg", "kkj", "ksb", "mas", "mgo", "nah", "nnh", "nyn",
         "pap", "rof", "rwk", "saq", "seh", "ssy", "syr", "teo", "tig", "vun", "wae", "xog":
        if n == 1 { return .one }
    case "ar":
        if n == 2 { return .two }
        if n == 1 { return .one }
        if n == 0 { return .zero }
        if (3...10).contains(mod100) { return .few }
        if (11...99).contains(mod100) { return .many }
    default:
        break
    }
    return .other
}
