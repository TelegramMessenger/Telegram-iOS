//
//  ParseResponse.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

func parsePopularPage(withURL: URL, page: Int) -> Resource<PopularPageModel> {
    let parse = Resource<PopularPageModel>(url: withURL, page: page) { metaData, jsonData in
        do {
            let photos = try JSONDecoder().decode([PhotoModel].self, from: jsonData)
            return .success(PopularPageModel(metaData: metaData, photos: photos))
        } catch {
            return .failure(.errorParsingJSON)
        }
	}

	return parse
}
