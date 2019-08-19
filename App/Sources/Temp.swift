import Foundation
import Emoji

@objc(AppDelegate1)
public final class AppDelegate1: NSObject {
	override init() {
		super.init()

		print("OK".isSingleEmoji)
	}
}
