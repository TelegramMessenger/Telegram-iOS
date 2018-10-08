//
//  PhotoFeedTableNodeController.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import AsyncDisplayKit

class PhotoFeedTableNodeController: ASViewController<ASTableNode> {
    
    // MARK: Lifecycle
	
    private lazy var activityIndicatorView: UIActivityIndicatorView = {
        return UIActivityIndicatorView(activityIndicatorStyle: .gray)
    }()
	
	var photoFeedModel = PhotoFeedModel(photoFeedModelType: .photoFeedModelTypePopular)
	
	init() {
        super.init(node: ASTableNode())
		
        navigationItem.title = "ASDK"
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
    
    // MAKR: UIViewController
	
	override func viewDidLoad() {
		super.viewDidLoad()
        
		node.allowsSelection = false
		node.dataSource = self
		node.delegate = self
		node.leadingScreensForBatching = 2.5
        node.view.separatorStyle = .none
        
        navigationController?.hidesBarsOnSwipe = true
        
        node.view.addSubview(activityIndicatorView)
	}
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
      
        // Center the activity indicator view
        let bounds = node.bounds
        activityIndicatorView.frame.origin = CGPoint(
            x: (bounds.width - activityIndicatorView.frame.width) / 2.0,
            y: (bounds.height - activityIndicatorView.frame.height) / 2.0
        )
    }
	
	func fetchNewBatchWithContext(_ context: ASBatchContext?) {
		DispatchQueue.main.async {
			self.activityIndicatorView.startAnimating()
		}

		photoFeedModel.updateNewBatchOfPopularPhotos() { additions, connectionStatus in
			switch connectionStatus {
			case .connected:
				self.activityIndicatorView.stopAnimating()
				self.addRowsIntoTableNode(newPhotoCount: additions)
				context?.completeBatchFetching(true)
			case .noConnection:
				self.activityIndicatorView.stopAnimating()
                context?.completeBatchFetching(true)
			}
		}
	}
	
	func addRowsIntoTableNode(newPhotoCount newPhotos: Int) {
		let indexRange = (photoFeedModel.numberOfItems - newPhotos..<photoFeedModel.numberOfItems)
		let indexPaths = indexRange.map { IndexPath(row: $0, section: 0) }
		node.insertRows(at: indexPaths, with: .none)
	}
}

// MARK: ASTableDataSource / ASTableDelegate

extension PhotoFeedTableNodeController: ASTableDataSource, ASTableDelegate {
	func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
		return photoFeedModel.numberOfItems
	}
	
	func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        let photo = photoFeedModel.itemAtIndexPath(indexPath)
		let nodeBlock: ASCellNodeBlock = { _ in
			return PhotoTableNodeCell(photoModel: photo)
		}
		return nodeBlock
	}
	
	func shouldBatchFetchForCollectionNode(collectionNode: ASCollectionNode) -> Bool {
		return true
	}
	
	func tableNode(_ tableNode: ASTableNode, willBeginBatchFetchWith context: ASBatchContext) {
		fetchNewBatchWithContext(context)
	}
}
