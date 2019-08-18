import Foundation
import Emoji

@objc(AppDelegate)
public final class AppDelegate: NSObject {
	override init() {
		super.init()

		print("OK".isSingleEmoji)
	}
}
