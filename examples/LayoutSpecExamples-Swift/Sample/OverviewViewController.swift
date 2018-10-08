//
//  OverviewViewController.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import AsyncDisplayKit

class OverviewViewController: ASViewController<ASTableNode> {
  let tableNode = ASTableNode()
  let layoutExamples: [LayoutExampleNode.Type]

  init() {
    layoutExamples = [
      HeaderWithRightAndLeftItems.self,
      PhotoWithInsetTextOverlay.self,
      PhotoWithOutsetIconOverlay.self,
      FlexibleSeparatorSurroundingContent.self,
      CornerLayoutSample.self,
      UserProfileSample.self
    ]

    super.init(node: tableNode)

    self.title = "Layout Examples"
    self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    tableNode.delegate = self
    tableNode.dataSource = self
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let indexPath = tableNode.indexPathForSelectedRow {
      tableNode.deselectRow(at: indexPath, animated: true)
    }
  }

}

extension OverviewViewController: ASTableDataSource {
  func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
    return layoutExamples.count
  }

  func tableNode(_ tableNode: ASTableNode, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
    return OverviewCellNode(layoutExampleType: layoutExamples[indexPath.row])
  }
}

extension OverviewViewController: ASTableDelegate {
  func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
    let layoutExampleType = (tableNode.nodeForRow(at: indexPath) as! OverviewCellNode).layoutExampleType
    let detail = LayoutExampleViewController(layoutExampleType: layoutExampleType)
    self.navigationController?.pushViewController(detail, animated: true)
  }
}
