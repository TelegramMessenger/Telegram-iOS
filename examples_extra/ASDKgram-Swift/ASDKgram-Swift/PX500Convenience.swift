//
//  PX500Convenience.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

func parsePopularPage(withURL: URL) -> Resource<PopularPageModel> {

	let parse = Resource<PopularPageModel>(url: withURL, parseJSON: { jsonData in

		guard let json = jsonData as? JSONDictionary, let photos = json["photos"] as? [JSONDictionary] else { return .failure(.errorParsingJSON)  }

		guard let model = PopularPageModel(dictionary: json, photosArray: photos.flatMap(PhotoModel.init)) else { return .failure(.errorParsingJSON) }

		return .success(model)
	})

	return parse
}
