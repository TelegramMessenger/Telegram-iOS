//
//  CreateListVC.swift
//  AppleReminders
//
//  Created by Josh R on 2/2/20.
//  Copyright © 2020 Josh R. All rights reserved.
//

import UIKit
import SwiftUI
import RealmSwift

final class CreateListVC: UIViewController {
    
    let realm = MyRealm.getConfig()
    
    var selectedListColorString: String? {
        didSet {
            iconPreview.iconBackGround = CustomColors.systemColorsDict[selectedListColorString!]
        }
    }
    
    var selectedIcon: String?  //do not enable property observers.  Must switch on the iconType in didSelectItem
    var passedListToEdit: ReminderList?
    
    enum SectionLayoutKind: Int, CaseIterable {
        case color, icon  //this determines the order of the sections
    }
    
    var collectionView: UICollectionView! = nil
    var dataSource: UICollectionViewDiffableDataSource<SectionLayoutKind, CreateListModel>! = nil
    var createListModel = [CreateListModel]()
    
    lazy var cancelBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Cancel".localized, for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.sizeToFit()
        button.addTarget(self, action: #selector(cancelBtnTapped), for: .touchUpInside)
        
        return button
    }()
    
    @objc func cancelBtnTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    lazy var doneBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Done".localized, for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.sizeToFit()
        button.addTarget(self, action: #selector(dontBtnTapped), for: .touchUpInside)
        
        return button
    }()
    
    @objc func dontBtnTapped() {
        try! realm?.write {
            if let passedListToEdit = passedListToEdit {
                passedListToEdit.listColor = selectedListColorString ?? ""
                passedListToEdit.systemIconName = selectedIcon ?? "list.bullet"
                passedListToEdit.name = listNameTxt.text!  //Done button will be disabled if textField is blank
            } else {
                let newList = ReminderList()
                newList.listColor = selectedListColorString ?? ""
                newList.systemIconName = selectedIcon ?? "list.bullet"
                newList.name = listNameTxt.text!  //Done button will be disabled if textField is blank
                newList.sortIndex = ReminderList.assignMaxSortIndex()
                
                realm?.add(newList)
            }
        }
        
        //dismiss vc
        self.dismiss(animated: true, completion: nil)
    }
    
    lazy var vcTitleLbl: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        label.textColor = .label
        label.text = "Title".localized
        label.textAlignment = .center
        
        return label
    }()
    
    lazy var iconPreview: CreateListIconPreviewView = {
        let imgView = CreateListIconPreviewView()
        imgView.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        imgView.iconImgView.image = UIImage(systemName: "list.bullet")
        
        return imgView
    }()
    
    lazy var listNameTxt: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = UIColor.systemGray5
        textField.textColor = .label
        textField.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        textField.placeholder = "Enter List Name Here".localized
        textField.textAlignment = .center
        textField.layer.cornerRadius = 12
        textField.delegate = self
        textField.addTarget(self, action: #selector(listTxtDidChange), for: .editingChanged)
        
        return textField
    }()
    
    @objc func listTxtDidChange() {
        setDoneBtnState()
    }
    
    private func setDoneBtnState() {
        if listNameTxt.text == "" {
            doneBtn.isEnabled = false
            doneBtn.setTitleColor(.systemGray, for: .disabled)
        } else {
            doneBtn.isEnabled = true
            doneBtn.setTitleColor(.systemBlue, for: .normal)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addViewsToVC(views: cancelBtn, vcTitleLbl, doneBtn, iconPreview, listNameTxt)
        
        selectedListColorString = CustomColors.defaultListColor
        loadEditingList()
        createListModel = SampleData.generateCreateListModel()
        
        configureHierarchy()
        configureDataSource()
        self.collectionView?.backgroundColor = .systemBackground
        
        setViewConstraints()
        setDoneBtnState()
        
        self.view.backgroundColor = .systemBackground
    }
    
    private func loadEditingList() {
        guard let passedListToEdit = passedListToEdit else { return }
        
        selectedListColorString = passedListToEdit.listColor
        selectedIcon = passedListToEdit.systemIconName
        iconPreview.iconImgView.image = passedListToEdit.getListIcon
        listNameTxt.text = passedListToEdit.name
        vcTitleLbl.text = "Name & Appearance".localized
    }
    
    func configureHierarchy() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.register(CreateListIconCVCell.self, forCellWithReuseIdentifier: CreateListIconCVCell.identifier)
        view.addSubview(collectionView)
        collectionView.delegate = self
        
        collectionView.allowsMultipleSelection = true
    }
    
    func createLayout() -> UICollectionViewLayout {
        //        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(60), heightDimension: .absolute(60))
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth((1/6)), heightDimension: .fractionalWidth((1/6)))  //yes, I am intentionally using .fractionalWidth on the heightDimension
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        //MARK: ContentInsets - set for cell spacing
        item.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(0.15))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 0, bottom: 0, trailing: 5)
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
    
    func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SectionLayoutKind, CreateListModel>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: CreateListModel) -> UICollectionViewCell? in
            
            let section = SectionLayoutKind(rawValue: indexPath.section)!
            
            if section == .color {
                if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CreateListIconCVCell.identifier, for: indexPath) as? CreateListIconCVCell {
                    
                    let iconColor = CustomColors.systemColorsDict[identifier.colorHEX]
                    cell.iconImgViewBackgroundColor = iconColor!
                    
                    return cell
                }
            } else if section == .icon {
                if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CreateListIconCVCell.identifier, for: indexPath) as? CreateListIconCVCell {
                    
                    switch identifier.iconType {
                    case .system:
                        cell.iconImgView.image = UIImage(systemName: identifier.iconName ?? "list.bullet")
                    case .custom:
                        cell.iconImgView.image = UIImage(named: identifier.iconName ?? "")
                    default:
                        cell.iconImgView.image = UIImage(named: identifier.iconName ?? "")
                    }
                    
                    
                    cell.iconImgViewBackgroundColor = .systemGray5
                    return cell
                }
            }
            
            return UICollectionViewCell()
        }
        dataSource.apply(snapshotForCurrentState(), animatingDifferences: false)
    }
    
    func snapshotForCurrentState() -> NSDiffableDataSourceSnapshot<SectionLayoutKind, CreateListModel> {
        var snapshot = NSDiffableDataSourceSnapshot<SectionLayoutKind, CreateListModel>()
        
        //Add sections
        SectionLayoutKind.allCases.forEach {
            snapshot.appendSections([$0])
        }
        
        snapshot.appendItems(createListModel.filter({ $0.cellType == .color }), toSection: .color)
        snapshot.appendItems(createListModel.filter({ $0.cellType == .icon }), toSection: .icon)
        
        return snapshot
    }
    
    
    func updateUI() {
        let snapshot = snapshotForCurrentState()
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func addViewsToVC(views: UIView...) {
        views.forEach({ self.view.addSubview($0) })
    }
    
    private func setViewConstraints() {
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        vcTitleLbl.translatesAutoresizingMaskIntoConstraints = false
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        iconPreview.translatesAutoresizingMaskIntoConstraints = false
        listNameTxt.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        cancelBtn.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10).isActive = true
        cancelBtn.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 15).isActive = true
        cancelBtn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        cancelBtn.widthAnchor.constraint(equalToConstant: cancelBtn.intrinsicContentSize.width).isActive = true
        
        vcTitleLbl.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10).isActive = true
        vcTitleLbl.leadingAnchor.constraint(equalTo: cancelBtn.trailingAnchor, constant: 2).isActive = true
        vcTitleLbl.trailingAnchor.constraint(equalTo: doneBtn.leadingAnchor,constant: -2).isActive = true
        vcTitleLbl.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        doneBtn.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10).isActive = true
        doneBtn.trailingAnchor.constraint(equalTo: self.view.trailingAnchor,constant: -15).isActive = true
        doneBtn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        doneBtn.widthAnchor.constraint(equalToConstant: doneBtn.intrinsicContentSize.width).isActive = true
        
        iconPreview.topAnchor.constraint(equalTo: vcTitleLbl.bottomAnchor, constant: 50).isActive = true
        iconPreview.heightAnchor.constraint(equalToConstant: 100).isActive = true
        iconPreview.widthAnchor.constraint(equalToConstant: 100).isActive = true
        iconPreview.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        
        listNameTxt.topAnchor.constraint(equalTo: iconPreview.bottomAnchor, constant: 20).isActive = true
        listNameTxt.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 20).isActive = true
        listNameTxt.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor,constant: -20).isActive = true
        listNameTxt.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        collectionView.topAnchor.constraint(equalTo: listNameTxt.bottomAnchor, constant: 10).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor,constant: 0).isActive = true
    }
    
    
}


extension CreateListVC: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        collectionView.indexPathsForSelectedItems?.filter({ $0.section == indexPath.section }).forEach({ collectionView.deselectItem(at: $0, animated: false) })
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let tappedListModel = dataSource?.itemIdentifier(for: indexPath) else { return }
        
        let section = SectionLayoutKind(rawValue: indexPath.section)!
        
        switch section {
        case .color:
            selectedListColorString = tappedListModel.colorHEX
        case .icon:
            //Set icon preview
            selectedIcon = tappedListModel.iconName
            switch tappedListModel.iconType {
            case .system:
                iconPreview.iconImgView.image = UIImage(systemName: tappedListModel.iconName ?? "list.bullet")
            case .custom:
                iconPreview.iconImgView.image = UIImage(named: tappedListModel.iconName ?? "list.bullet")
            case .none:
                break
            }
        }
    }
    
}

extension CreateListVC: UITextFieldDelegate {}



//MARK: SwiftUI's live preview
fileprivate typealias ThisViewController = CreateListVC //update to this file's VC
fileprivate struct IntegratedController: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<IntegratedController>) -> ThisViewController {
        return ThisViewController()
    }
    
    func updateUIViewController(_ uiViewController: ThisViewController, context: UIViewControllerRepresentableContext<IntegratedController>) {
    }
}

fileprivate struct CustomContentView: View {
    var body: some View {
        IntegratedController().edgesIgnoringSafeArea(.bottom)
        
        //IF Navigation title is needed for the preview, used the following:
        //        NavigationView {
        //            IntegratedController().edgesIgnoringSafeArea(.all)
        //                .navigationBarTitle(Text("Navigation Title Text"), displayMode: .inline)  //inline sets a small navigation bar height
        //        }
    }
}

struct CreateListVC_ContentView_Previews: PreviewProvider {
    static var previews: some View {
        CustomContentView()  //if preview isn't changing, change this struct to the struct conforming to View
    }
}
