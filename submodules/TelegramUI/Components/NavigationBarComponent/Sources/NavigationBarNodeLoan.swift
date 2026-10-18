import Foundation
import UIKit
import AsyncDisplayKit

/// A screen's node (`NavigationBarComponent.Button.Content.node`) lent to glass drawn outside its bar (a navigation
/// transition's capsules), so that the glass shows whatever the node draws, as the bar does. A snapshot could not: a
/// node that draws only once it is on screen (Appearance → Chat Themes' animated switch) is blank while its bar hides
/// its capsules.
///
/// The node's home is the bar's button that hosts it. While the node is lent, its home lets it go and does not take it
/// back, even when the bar rebuilds that button; a borrowing button (`NavigationBarContentView.borrowsNodes`) hosts it.
/// Ending the loan puts the node back in its home at once, where the home laid it out. Main thread only.
public enum NavigationBarNodeLoan {
    private final class Entry {
        weak var node: ASDisplayNode?
        weak var home: NavigationButtonComponent.View?
        var isLent = false

        init(node: ASDisplayNode) {
            self.node = node
        }
    }

    private static var entries: [ObjectIdentifier: Entry] = [:]

    private static func entry(_ node: ASDisplayNode, create: Bool) -> Entry? {
        let key = ObjectIdentifier(node)
        if let entry = self.entries[key], entry.node === node {
            return entry
        }
        // A key reused by a new node after the old one went away.
        self.entries[key] = nil
        guard create else {
            return nil
        }
        let entry = Entry(node: node)
        self.entries[key] = entry
        return entry
    }

    /// Lends `node`: the next layout of a borrowing button for it moves it there.
    public static func lend(_ node: ASDisplayNode) {
        self.entry(node, create: true)?.isLent = true
    }

    /// Ends the loan of `node`: it goes back to its home now.
    public static func end(_ node: ASDisplayNode) {
        guard let entry = self.entry(node, create: false), entry.isLent else {
            return
        }
        entry.isLent = false
        let home = entry.home
        if home == nil {
            self.entries[ObjectIdentifier(node)] = nil
        }
        home?.reclaimHostedNode()
    }

    public static func isLent(_ node: ASDisplayNode) -> Bool {
        return self.entry(node, create: false)?.isLent ?? false
    }

    /// The button that hosts `node` in its bar (the last one to lay it out).
    static func setHome(_ home: NavigationButtonComponent.View, of node: ASDisplayNode) {
        self.entry(node, create: true)?.home = home
    }

    /// Whether `button` may take `node` as its home: it is the recorded home, or none is recorded. A button the bar
    /// has replaced (an in-place change hands the old one to the leaving items) is not.
    static func isHome(_ button: NavigationButtonComponent.View, of node: ASDisplayNode) -> Bool {
        guard let home = self.entry(node, create: false)?.home else {
            return true
        }
        return home === button
    }
}
