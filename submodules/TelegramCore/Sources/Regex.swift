import Foundation

public struct Regex {
    let pattern: String
    let options: NSRegularExpression.Options!
    
    private var matcher: NSRegularExpression {
        return try! NSRegularExpression(pattern: self.pattern, options: self.options)
    }
    
    public init(_ pattern: String) {
        self.pattern = pattern
        self.options = []
    }
    
    public func match(_ string: String, options: NSRegularExpression.MatchingOptions = []) -> Bool {
        return self.matcher.numberOfMatches(in: string, options: options, range: NSMakeRange(0, string.utf16.count)) != 0
    }
}

public protocol RegularExpressionMatchable {
    func match(_ regex: Regex) -> Bool
}

extension String: RegularExpressionMatchable {
    public func match(_ regex: Regex) -> Bool {
        return regex.match(self)
    }
}

public func ~=<T: RegularExpressionMatchable>(pattern: Regex, matchable: T) -> Bool {
    return matchable.match(pattern)
}
