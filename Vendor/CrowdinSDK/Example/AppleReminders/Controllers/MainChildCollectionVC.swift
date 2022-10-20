//
//  MainChildCollectionVC.swift
//  AppleReminders
//
//  Created by Josh R on 7/16/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit

final class MainChildCollectionVC: UIViewController, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    lazy var collectionViewDatasource = ReminderTypeDatasource()
    
    var didTapCell: ((ReminderType) -> Void)?
    
    let collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        cv.backgroundColor = .systemGroupedBackground
        cv.register(TypeCVCell.self, forCellWithReuseIdentifier: TypeCVCell.reuseIdentifier)
        return cv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = collectionViewDatasource
        collectionView.delegate = self
        
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0),
            collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 0),
            collectionView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 0),
            collectionView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        collectionView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tappedType = collectionViewDatasource.types[indexPath.row]
        //Action passed to MainVC
        didTapCell?(tappedType)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: collectionView.bounds.size.width * 0.48, height: collectionView.frame.height * 0.45)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.init(top: 4, left: 0, bottom: 0, right: 0)
    }
}
