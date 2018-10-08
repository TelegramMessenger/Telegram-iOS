//
//  NetworkImageView.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

let imageCache = NSCache<NSString, UIImage>()

class NetworkImageView: UIImageView {

	var imageUrlString: String?

	func loadImageUsingUrlString(urlString: String) {

		imageUrlString = urlString

		let url = URL(string: urlString)

		image = nil

		if let imageFromCache = imageCache.object(forKey: urlString as NSString) {
			self.image = imageFromCache
			return
		}

		URLSession.shared.dataTask(with: url!, completionHandler: { (data, respones, error) in

			if error != nil {
				print(error!)
				return
			}

			DispatchQueue.main.async {
				let imageToCache = UIImage(data: data!)
				if self.imageUrlString == urlString {
					self.image = imageToCache
				}
				imageCache.setObject(imageToCache!, forKey: urlString as NSString)
			}
		}).resume()
	}
}
