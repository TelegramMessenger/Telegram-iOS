import Foundation
import UIKit
import TelegramCore

func spacingBetweenBlocks(upper: InstantPageBlock?, lower: InstantPageBlock?) -> CGFloat {
    if let upper = upper, let lower = lower {
        switch (upper, lower) {
            case (_, .cover), (_, .channelBanner), (.details, .details), (.relatedArticles, _), (_, .anchor):
                return 0.0
            case (.divider, _), (_, .divider):
                return 25.0
            case (_, .blockQuote), (.blockQuote, _), (_, .pullQuote), (.pullQuote, _):
                return 27.0
            case (.kicker, .title), (.cover, .title):
                return 16.0
            case (_, .title):
                return 20.0
            case (.title, .authorDate), (.subtitle, .authorDate):
                return 18.0
            case (_, .authorDate):
                return 20.0
            case (.title, .paragraph), (.authorDate, .paragraph):
                return 34.0
            case (.header, .paragraph), (.subheader, .paragraph):
                return 25.0
            case (.list, .paragraph):
                return 31.0
            case (.preformatted, .paragraph):
                return 19.0
            case (.paragraph, .paragraph):
                return 25.0
            case (_, .paragraph):
                return 20.0
            case (.title, .list), (.authorDate, .list):
                return 34.0
            case (.header, .list), (.subheader, .list):
                return 31.0
            case (.preformatted, .list):
                return 19.0
            case (_, .list):
                return 25.0
            case (.paragraph, .preformatted):
                return 19.0
            case (_, .preformatted):
                return 20.0
            case (_, .header), (_, .subheader):
                return 32.0
            default:
                return 20.0
        }
    } else if let lower = lower {
        switch lower {
            case .cover, .channelBanner, .details, .anchor:
                return 0.0
            default:
                return 25.0
        }
    } else {
        if let upper = upper, case .relatedArticles = upper {
            return 0.0
        } else {
            return 25.0
        }
    }
}
