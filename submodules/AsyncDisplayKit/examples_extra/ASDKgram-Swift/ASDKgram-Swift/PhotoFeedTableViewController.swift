//
//  PhotoFeedTableViewController.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

class PhotoFeedTableViewController: UITableViewController {
	
	var activityIndicator: UIActivityIndicatorView!
	var photoFeed = PhotoFeedModel(photoFeedModelType: .photoFeedModelTypePopular)
	
	init() {
        super.init(nibName: nil, bundle: nil)
        
		navigationItem.title = "UIKit"
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
        
        navigationController?.hidesBarsOnSwipe = true
		setupActivityIndicator()
		configureTableView()
		fetchNewBatch()
	}
    
	func fetchNewBatch() {
		activityIndicator.startAnimating()
		photoFeed.updateNewBatchOfPopularPhotos() { additions, connectionStatus in
			switch connectionStatus {
			case .connected:
				self.activityIndicator.stopAnimating()
				self.addRowsIntoTableView(newPhotoCount: additions)
			case .noConnection:
				self.activityIndicator.stopAnimating()
				break
			}
		}
	}
	
	// Helper functions
	func setupActivityIndicator() {
		let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
		self.activityIndicator = activityIndicator
        self.tableView.addSubview(activityIndicator)

		NSLayoutConstraint.activate([
			activityIndicator.centerXAnchor.constraint(equalTo: self.tableView.centerXAnchor),
			activityIndicator.centerYAnchor.constraint(equalTo: self.tableView.centerYAnchor)
        ])
	}
	
	func configureTableView() {
		tableView.register(PhotoTableViewCell.self, forCellReuseIdentifier: "photoCell")
		tableView.allowsSelection = false
		tableView.rowHeight = UITableViewAutomaticDimension
		tableView.separatorStyle = .none
	}
}

extension PhotoFeedTableViewController {
	
	func addRowsIntoTableView(newPhotoCount newPhotos: Int) {
		
		let indexRange = (photoFeed.numberOfItems - newPhotos..<photoFeed.numberOfItems)
		let indexPaths = indexRange.map { IndexPath(row: $0, section: 0) }
		tableView.insertRows(at: indexPaths, with: .none)
	}
	
	// TableView Data Source
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return photoFeed.numberOfItems
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "photoCell", for: indexPath) as? PhotoTableViewCell else { fatalError("Wrong cell type") }
        cell.photoModel = photoFeed.itemAtIndexPath(indexPath)
		return cell
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return PhotoTableViewCell.height(
            for: photoFeed.itemAtIndexPath(indexPath),
            withWidth: self.view.frame.size.width
        )
	}
	
	override func scrollViewDidScroll(_ scrollView: UIScrollView) {
		let currentOffSetY = scrollView.contentOffset.y
		let contentHeight = scrollView.contentSize.height
		let screenHeight = UIScreen.main.bounds.height
		let screenfullsBeforeBottom = (contentHeight - currentOffSetY) / screenHeight
		if screenfullsBeforeBottom < 2.5 {
			self.fetchNewBatch()
		}
	}
}
