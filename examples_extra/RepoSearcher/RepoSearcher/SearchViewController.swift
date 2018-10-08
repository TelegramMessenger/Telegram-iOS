//
//  SearchViewController.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit
import AsyncDisplayKit
import IGListKit

class SearchToken: NSObject {}

final class SearchViewController: ASViewController<ASCollectionNode> {
    
    lazy var adapter: ListAdapter = {
        return ListAdapter(updater: ListAdapterUpdater(), viewController: self, workingRangeSize: 0)
    }()
    
    let words = ["first", "second", "third", "more", "hi", "others"]
    
    let searchToken = SearchToken()
    var filterString = ""
    
    init() {
        let flowLayout = UICollectionViewFlowLayout()
        super.init(node: ASCollectionNode(collectionViewLayout: flowLayout))
        adapter.setASDKCollectionNode(node)
        adapter.dataSource = self
        title = "Search"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SearchViewController: ListAdapterDataSource {
    func listAdapter(_ listAdapter: ListAdapter, sectionControllerFor object: Any) -> ListSectionController {
        if object is SearchToken {
            let section = SearchSectionController()
            section.delegate = self
            return section
        }
        return LabelSectionController()
    }
    
    func emptyView(for listAdapter: ListAdapter) -> UIView? {
        // emptyView dosent work in this secenario, there is always one section (searchbar) present in collection
        return nil
    }
    
    func objects(for listAdapter: ListAdapter) -> [ListDiffable] {
        guard filterString != "" else { return [searchToken] + words.map { $0 as ListDiffable } }
        return [searchToken] + words.filter { $0.lowercased().contains(filterString.lowercased()) }.map { $0 as ListDiffable }
    }
}

extension SearchViewController: SearchSectionControllerDelegate {
    func searchSectionController(_ sectionController: SearchSectionController, didChangeText text: String) {
        filterString = text
        adapter.performUpdates(animated: true, completion: nil)
    }
}
