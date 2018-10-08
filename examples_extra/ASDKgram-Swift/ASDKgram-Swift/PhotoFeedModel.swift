//
//  PhotoFeedModel.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

final class PhotoFeedModel {
    
    // MARK: Properties

	public private(set) var photoFeedModelType: PhotoFeedModelType
   
    private var orderedPhotos: OrderedDictionary<String, PhotoModel> = [:]
	private var currentPage: Int = 0
	private var totalPages: Int = 0
	private var totalItems: Int = 0
	private var fetchPageInProgress: Bool = false

    // MARK: Lifecycle

	init(photoFeedModelType: PhotoFeedModelType) {
        self.photoFeedModelType = photoFeedModelType
	}
    
    // MARK: API
    
    lazy var url: URL = {
        return URL.URLForFeedModelType(feedModelType: self.photoFeedModelType)
    }()

	var numberOfItems: Int {
        return orderedPhotos.count
	}
    
    func itemAtIndexPath(_ indexPath: IndexPath) -> PhotoModel {
        return orderedPhotos[indexPath.row].value
    }

	// return in completion handler the number of additions and the status of internet connection

	func updateNewBatchOfPopularPhotos(additionsAndConnectionStatusCompletion: @escaping (Int, InternetStatus) -> ()) {
        
        // For this example let's use the main thread as locking queue
        DispatchQueue.main.async {
            guard !self.fetchPageInProgress else {
                return
            }

            self.fetchPageInProgress = true
            self.fetchNextPageOfPopularPhotos(replaceData: false) { [unowned self] additions, error in
                self.fetchPageInProgress = false

                if let error = error {
                    switch error {
                    case .noInternetConnection:
                        additionsAndConnectionStatusCompletion(0, .noConnection)
                    default:
                        additionsAndConnectionStatusCompletion(0, .connected)
                    }
                } else {
                    additionsAndConnectionStatusCompletion(additions, .connected)
                }
            }
        }
	}

	private func fetchNextPageOfPopularPhotos(replaceData: Bool, numberOfAdditionsCompletion: @escaping (Int, NetworkingError?) -> ()) {
		if currentPage == totalPages, currentPage != 0 {
            numberOfAdditionsCompletion(0, .customError("No pages left to parse"))
            return
		}

		let pageToFetch = currentPage + 1
		WebService().load(resource: parsePopularPage(withURL: url, page: pageToFetch)) { [unowned self] result in
            // Callback will happen on main for now
			switch result {
				case .success(let itemsPage):
                    // Update current state
                    self.totalItems = itemsPage.totalNumberOfItems
                    self.totalPages = itemsPage.totalPages
                    self.currentPage = itemsPage.page

                    // Update photos
                    if replaceData {
                        self.orderedPhotos = []
                    }
                    var insertedItems = 0
                    for photo in itemsPage.photos {
                        if !self.orderedPhotos.containsKey(photo.photoID) {
                            // Append a new key-value pair by setting a value for an non-existent key
                            self.orderedPhotos[photo.photoID] = photo
                            insertedItems += 1
                        }
                    }

                    numberOfAdditionsCompletion(insertedItems, nil)
				case .failure(let fail):
                    print(fail)
                    numberOfAdditionsCompletion(0, fail)
			}
		}
	}
}

enum PhotoFeedModelType {
	case photoFeedModelTypePopular
	case photoFeedModelTypeLocation
	case photoFeedModelTypeUserPhotos
}

enum InternetStatus {
	case connected
	case noConnection
}
