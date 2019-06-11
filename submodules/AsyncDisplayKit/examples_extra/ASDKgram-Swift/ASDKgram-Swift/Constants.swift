//
//  Constants.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

struct Constants {
    struct Unsplash {
        struct URLS {
            static let Host = "https://api.unsplash.com/"
            static let PopularEndpoint = "photos?order_by=popular"
            static let SearchEndpoint = "photos/search?geo="    //latitude,longitude,radius<units>
            static let UserEndpoint = "photos?user_id="
            static let ConsumerKey = "&client_id=3b99a69cee09770a4a0bbb870b437dbda53efb22f6f6de63714b71c4df7c9642"
            static let ImagesPerPage = 30
        }
    }

	struct CellLayout {
		static let FontSize: CGFloat = 14
		static let HeaderHeight: CGFloat = 50
		static let UserImageHeight: CGFloat = 30
		static let HorizontalBuffer: CGFloat = 10
		static let VerticalBuffer: CGFloat = 5
		static let InsetForAvatar = UIEdgeInsets(top: HorizontalBuffer, left: 0, bottom: HorizontalBuffer, right: HorizontalBuffer)
		static let InsetForHeader = UIEdgeInsets(top: 0, left: HorizontalBuffer, bottom: 0, right: HorizontalBuffer)
		static let InsetForFooter = UIEdgeInsets(top: VerticalBuffer, left: HorizontalBuffer, bottom: VerticalBuffer, right: HorizontalBuffer)
	}
}
