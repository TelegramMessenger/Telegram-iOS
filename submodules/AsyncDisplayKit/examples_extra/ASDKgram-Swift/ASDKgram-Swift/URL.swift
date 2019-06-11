//
//  URL.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

extension URL {
	static func URLForFeedModelType(feedModelType: PhotoFeedModelType) -> URL {
		switch feedModelType {
		case .photoFeedModelTypePopular:
            return URL(string: assembleUnsplashURLString(endpoint: Constants.Unsplash.URLS.PopularEndpoint))!

		case .photoFeedModelTypeLocation:
			return URL(string: assembleUnsplashURLString(endpoint: Constants.Unsplash.URLS.SearchEndpoint))!

		case .photoFeedModelTypeUserPhotos:
			return URL(string: assembleUnsplashURLString(endpoint: Constants.Unsplash.URLS.UserEndpoint))!
		}
	}
    
    private static func assembleUnsplashURLString(endpoint: String) -> String {
        return Constants.Unsplash.URLS.Host + endpoint + Constants.Unsplash.URLS.ConsumerKey
    }
}
