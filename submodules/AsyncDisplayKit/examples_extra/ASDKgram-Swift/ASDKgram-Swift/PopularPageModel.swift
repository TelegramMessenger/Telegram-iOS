//
//  PopularPageModel.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

struct PopularPageModel {
    let page: Int
    let totalPages: Int
    let totalNumberOfItems: Int
    let photos: [PhotoModel]
    
    init(metaData: ResponseMetadata, photos:[PhotoModel]) {
        self.page = metaData.currentPage
        self.totalPages = metaData.pagesTotal
        self.totalNumberOfItems = metaData.itemsTotal
        self.photos = photos
    }
}
