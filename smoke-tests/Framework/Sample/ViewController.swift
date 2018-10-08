//
//  ViewController.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import UIKit
import AsyncDisplayKit

class ViewController: UIViewController, ASTableDataSource, ASTableDelegate {

  var tableNode: ASTableNode


  // MARK: UIViewController.

  override required init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    self.tableNode = ASTableNode()

    super.init(nibName: nil, bundle: nil)

    self.tableNode.dataSource = self
    self.tableNode.delegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("storyboards are incompatible with truth and beauty")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(self.tableNode.view)
  }

  override func viewWillLayoutSubviews() {
    self.tableNode.frame = self.view.bounds
  }


  // MARK: ASTableView data source and delegate.

  func tableNode(_ tableNode: ASTableNode, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
    let patter = NSString(format: "[%ld.%ld] says hello!", indexPath.section, indexPath.row)
    let node = ASTextCellNode()
    node.text = patter as String

    return node
  }

  func numberOfSections(in tableNode: ASTableNode) -> Int {
    return 1
  }

  func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
    return 20
  }

}
