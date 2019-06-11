//
//  PhotoTableViewCell.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit

class PhotoTableViewCell: UITableViewCell {
	
	var photoModel: PhotoModel? {
		didSet {
			if let model = photoModel {
				photoImageView.loadImageUsingUrlString(urlString: model.url)
				avatarImageView.loadImageUsingUrlString(urlString: model.user.profileImage)
                photoLikesLabel.attributedText = model.attributedStringLikes(withSize: Constants.CellLayout.FontSize)
                usernameLabel.attributedText = model.attributedStringForUserName(withSize: Constants.CellLayout.FontSize)
                timeIntervalLabel.attributedText = model.attributedStringForTimeSinceString(withSize: Constants.CellLayout.FontSize)
                photoDescriptionLabel.attributedText = model.attributedStringForDescription(withSize: Constants.CellLayout.FontSize)
				photoDescriptionLabel.sizeToFit()
				var rect = photoDescriptionLabel.frame
				let availableWidth = self.bounds.size.width - Constants.CellLayout.HorizontalBuffer * 2
                rect.size = model.attributedStringForDescription(withSize: Constants.CellLayout.FontSize).boundingRect(with: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).size
				photoDescriptionLabel.frame = rect
			}
		}
	}
	
	let photoImageView: NetworkImageView = {
		let imageView = NetworkImageView()
		imageView.contentMode = .scaleAspectFill
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()
	
	let avatarImageView: NetworkImageView = {
		let imageView = NetworkImageView()
		imageView.contentMode = .scaleAspectFill
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.layer.cornerRadius = Constants.CellLayout.UserImageHeight / 2
		imageView.clipsToBounds = true
		return imageView
	}()
	
	let usernameLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()
	
	let timeIntervalLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()
	
	let photoLikesLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()
	
	let photoDescriptionLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.numberOfLines = 3
		return label
	}()
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupViews()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func setupViews() {
		addSubview(photoImageView)
		addSubview(avatarImageView)
		addSubview(usernameLabel)
		addSubview(timeIntervalLabel)
		addSubview(photoLikesLabel)
		addSubview(photoDescriptionLabel)
		setupConstraints()
	}
	
	func setupConstraints() {
		
		NSLayoutConstraint.activate ([
			//photoImageView
			photoImageView.topAnchor.constraint(equalTo: topAnchor, constant: Constants.CellLayout.HeaderHeight),
			photoImageView.widthAnchor.constraint(equalTo: widthAnchor),
			photoImageView.heightAnchor.constraint(equalTo: photoImageView.widthAnchor),
			// avatarImageView
			avatarImageView.leftAnchor.constraint(equalTo: leftAnchor, constant: Constants.CellLayout.HorizontalBuffer),
			avatarImageView.topAnchor.constraint(equalTo: topAnchor, constant: Constants.CellLayout.HorizontalBuffer),
			avatarImageView.heightAnchor.constraint(equalToConstant: Constants.CellLayout.UserImageHeight),
			avatarImageView.widthAnchor.constraint(equalTo: avatarImageView.heightAnchor),
			// usernameLabel
			usernameLabel.leftAnchor.constraint(equalTo: avatarImageView.rightAnchor, constant: Constants.CellLayout.HorizontalBuffer),
			usernameLabel.rightAnchor.constraint(equalTo: timeIntervalLabel.leftAnchor, constant: -Constants.CellLayout.HorizontalBuffer),
			usernameLabel.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
			// timeIntervalLabel
			timeIntervalLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -Constants.CellLayout.HorizontalBuffer),
			timeIntervalLabel.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
			// photoLikesLabel
			photoLikesLabel.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: Constants.CellLayout.VerticalBuffer),
			photoLikesLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: Constants.CellLayout.HorizontalBuffer),
			// photoDescriptionLabel
			photoDescriptionLabel.topAnchor.constraint(equalTo: photoLikesLabel.bottomAnchor, constant: Constants.CellLayout.VerticalBuffer),
			photoDescriptionLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: Constants.CellLayout.HorizontalBuffer),
			photoDescriptionLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -Constants.CellLayout.HorizontalBuffer),
			photoDescriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.CellLayout.VerticalBuffer)
			])
	}
	
	class func height(for photo: PhotoModel, withWidth width: CGFloat) -> CGFloat {
		let photoHeight = width
		let font = UIFont.systemFont(ofSize: Constants.CellLayout.FontSize)
		let likesHeight = round(font.lineHeight)
        let descriptionAttrString = photo.attributedStringForDescription(withSize: Constants.CellLayout.FontSize)
		let availableWidth = width - Constants.CellLayout.HorizontalBuffer * 2
		let descriptionHeight = descriptionAttrString.boundingRect(with: CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).size.height
		
		return likesHeight + descriptionHeight + photoHeight + Constants.CellLayout.HeaderHeight + Constants.CellLayout.VerticalBuffer * 3
	}
}
