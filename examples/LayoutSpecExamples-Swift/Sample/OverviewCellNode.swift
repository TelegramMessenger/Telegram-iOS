//
//  OverviewCellNode.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import AsyncDisplayKit

class OverviewCellNode: ASCellNode {

  let layoutExampleType: LayoutExampleNode.Type

  fileprivate let titleNode = ASTextNode()
  fileprivate let descriptionNode = ASTextNode()

  init(layoutExampleType le: LayoutExampleNode.Type) {
    layoutExampleType = le

    super.init()
    self.automaticallyManagesSubnodes = true

    titleNode.attributedText = NSAttributedString.attributedString(string: layoutExampleType.title(), fontSize: 16, color: .black)
    descriptionNode.attributedText = NSAttributedString.attributedString(string: layoutExampleType.descriptionTitle(), fontSize: 12, color: .lightGray)
  }

  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    let verticalStackSpec = ASStackLayoutSpec.vertical()
    verticalStackSpec.alignItems = .start
    verticalStackSpec.spacing = 5.0
    verticalStackSpec.children = [titleNode, descriptionNode]

    return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 10), child: verticalStackSpec)
  }

}
