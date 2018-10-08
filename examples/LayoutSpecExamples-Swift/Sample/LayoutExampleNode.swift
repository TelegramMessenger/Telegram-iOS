//
//  LayoutExampleNode.swift
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

import AsyncDisplayKit

class LayoutExampleNode: ASDisplayNode {
  override required init() {
    super.init()
    automaticallyManagesSubnodes = true
    backgroundColor = .white
  }

  class func title() -> String {
    assertionFailure("All layout example nodes must provide a title!")
    return ""
  }

  class func descriptionTitle() -> String? {
    return nil
  }
}

class HeaderWithRightAndLeftItems : LayoutExampleNode {
  let userNameNode     = ASTextNode()
  let postLocationNode = ASTextNode()
  let postTimeNode     = ASTextNode()

  required init() {
    super.init()

    userNameNode.attributedText = NSAttributedString.attributedString(string: "hannahmbanana", fontSize: 20, color: .darkBlueColor())
    userNameNode.maximumNumberOfLines = 1
    userNameNode.truncationMode = .byTruncatingTail

    postLocationNode.attributedText = NSAttributedString.attributedString(string: "Sunset Beach, San Fransisco, CA", fontSize: 20, color: .lightBlueColor())
    postLocationNode.maximumNumberOfLines = 1
    postLocationNode.truncationMode = .byTruncatingTail

    postTimeNode.attributedText = NSAttributedString.attributedString(string: "30m", fontSize: 20, color: .lightGray)
    postTimeNode.maximumNumberOfLines = 1
    postTimeNode.truncationMode = .byTruncatingTail
  }

  override class func title() -> String {
    return "Header with left and right justified text"
  }

  override class func descriptionTitle() -> String? {
    return "try rotating me!"
  }
}

class PhotoWithInsetTextOverlay : LayoutExampleNode {
  let photoNode = ASNetworkImageNode()
  let titleNode = ASTextNode()

  required init() {
    super.init()

    backgroundColor = .clear

    photoNode.url = URL(string: "http://texturegroup.org/static/images/layout-examples-photo-with-inset-text-overlay-photo.png")
    photoNode.willDisplayNodeContentWithRenderingContext = { context, drawParameters in
      let bounds = context.boundingBoxOfClipPath
      UIBezierPath(roundedRect: bounds, cornerRadius: 10).addClip()
    }

    titleNode.attributedText = NSAttributedString.attributedString(string: "family fall hikes", fontSize: 16, color: .white)
    titleNode.truncationAttributedText = NSAttributedString.attributedString(string: "...", fontSize: 16, color: .white)
    titleNode.maximumNumberOfLines = 2
    titleNode.truncationMode = .byTruncatingTail
  }

  override class func title() -> String {
    return "Photo with inset text overlay"
  }

  override class func descriptionTitle() -> String? {
    return "try rotating me!"
  }
}

class PhotoWithOutsetIconOverlay : LayoutExampleNode {
  let photoNode = ASNetworkImageNode()
  let iconNode  = ASNetworkImageNode()

  required init() {
    super.init()

    photoNode.url = URL(string: "http://texturegroup.org/static/images/layout-examples-photo-with-outset-icon-overlay-photo.png")

    iconNode.url = URL(string: "http://texturegroup.org/static/images/layout-examples-photo-with-outset-icon-overlay-icon.png")

    iconNode.imageModificationBlock = { image in
      let profileImageSize = CGSize(width: 60, height: 60)
      return image.makeCircularImage(size: profileImageSize, borderWidth: 10)
    }
  }

  override class func title() -> String {
    return "Photo with outset icon overlay"
  }

  override class func descriptionTitle() -> String? {
    return nil
  }
}

class FlexibleSeparatorSurroundingContent : LayoutExampleNode {
  let topSeparator    = ASImageNode()
  let bottomSeparator = ASImageNode()
  let textNode        = ASTextNode()

  required init() {
    super.init()

    topSeparator.image = UIImage.as_resizableRoundedImage(withCornerRadius: 1.0, cornerColor: .black, fill: .black)

    textNode.attributedText = NSAttributedString.attributedString(string: "this is a long text node", fontSize: 16, color: .black)

    bottomSeparator.image = UIImage.as_resizableRoundedImage(withCornerRadius: 1.0, cornerColor: .black, fill: .black)
  }

  override class func title() -> String {
    return "Top and bottom cell separator lines"
  }

  override class func descriptionTitle() -> String? {
    return "try rotating me!"
  }
}

class CornerLayoutSample : PhotoWithOutsetIconOverlay {
  let photoNode1 = ASImageNode()
  let photoNode2 = ASImageNode()
  let dotNode = ASImageNode()
  let badgeTextNode = ASTextNode()
  let badgeImageNode = ASImageNode()
  
  struct ImageSize {
    static let avatar = CGSize(width: 100, height: 100)
    static let icon = CGSize(width: 26, height: 26)
  }
  
  struct ImageColor {
    static let avatar = UIColor.lightGray
    static let icon = UIColor.red
  }
  
  required init() {
    super.init()
    
    let avatarImage = UIImage.draw(size: ImageSize.avatar, fillColor: ImageColor.avatar) { () -> UIBezierPath in
      return UIBezierPath(roundedRect: CGRect(origin: CGPoint.zero, size: ImageSize.avatar), cornerRadius: ImageSize.avatar.width / 20)
    }
    
    let iconImage = UIImage.draw(size: ImageSize.icon, fillColor: ImageColor.icon) { () -> UIBezierPath in
      return UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: ImageSize.icon))
    }
    
    photoNode1.image = avatarImage
    photoNode2.image = avatarImage
    dotNode.image = iconImage
    
    badgeTextNode.attributedText = NSAttributedString.attributedString(string: " 999+ ", fontSize: 20, color: .white)
    
    badgeImageNode.image = UIImage.as_resizableRoundedImage(withCornerRadius: 12, cornerColor: .clear, fill: .red)
  }
  
  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    photoNode.style.preferredSize = ImageSize.avatar
    iconNode.style.preferredSize = ImageSize.icon
    
    let badgeSpec = ASBackgroundLayoutSpec(child: badgeTextNode, background: badgeImageNode)
    let cornerSpec1 = ASCornerLayoutSpec(child: photoNode1, corner: dotNode, location: .topRight)
    let cornerSpec2 = ASCornerLayoutSpec(child: photoNode2, corner: badgeSpec, location: .topRight)
    let cornerSpec3 = ASCornerLayoutSpec(child: photoNode, corner: iconNode, location: .topRight)
    
    cornerSpec1.offset = CGPoint(x: -3, y: 3)

    let stackSpec = ASStackLayoutSpec.vertical()
    stackSpec.spacing = 40
    stackSpec.children = [cornerSpec1, cornerSpec2, cornerSpec3]
    
    return stackSpec
  }
  
  override class func title() -> String {
    return "Declarative way for Corner image Layout"
  }
  
  override class func descriptionTitle() -> String? {
    return nil
  }
}

class UserProfileSample : LayoutExampleNode {
  
  let badgeNode = ASImageNode()
  let avatarNode = ASImageNode()
  let usernameNode = ASTextNode()
  let subtitleNode = ASTextNode()
  
  struct ImageSize {
    static let avatar = CGSize(width: 44, height: 44)
    static let badge = CGSize(width: 15, height: 15)
  }
  
  struct ImageColor {
    static let avatar = UIColor.lightGray
    static let badge = UIColor.red
  }
  
  required init() {
    super.init()
    
    avatarNode.image = UIImage.draw(size: ImageSize.avatar, fillColor: ImageColor.avatar) { () -> UIBezierPath in
      return UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: ImageSize.avatar))
    }
    
    badgeNode.image = UIImage.draw(size: ImageSize.badge, fillColor: ImageColor.badge) { () -> UIBezierPath in
      return UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: ImageSize.badge))
    }
    
    makeSingleLine(for: usernameNode, with: "Hello world", fontSize: 17, textColor: .black)
    makeSingleLine(for: subtitleNode, with: "This is a long long subtitle, with a long long appended string.", fontSize: 14, textColor: .lightGray)
  }
  
  private func makeSingleLine(for node: ASTextNode, with text: String, fontSize: CGFloat, textColor: UIColor) {
    node.attributedText = NSAttributedString.attributedString(string: text, fontSize: fontSize, color: textColor)
    node.maximumNumberOfLines = 1
  }
  
  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    let avatarBox = ASCornerLayoutSpec(child: avatarNode, corner: badgeNode, location: .bottomRight)
    avatarBox.offset = CGPoint(x: -6, y: -6)
    
    let textBox = ASStackLayoutSpec.vertical()
    textBox.justifyContent = .spaceAround
    textBox.children = [usernameNode, subtitleNode]
    
    let profileBox = ASStackLayoutSpec.horizontal()
    profileBox.spacing = 10
    profileBox.children = [avatarBox, textBox]
    
    // Apply text truncation
    let elems: [ASLayoutElement] = [usernameNode, subtitleNode, textBox, profileBox]
    for elem in elems {
      elem.style.flexShrink = 1
    }
    
    let insetBox = ASInsetLayoutSpec(
      insets: UIEdgeInsets(top: 120, left: 20, bottom: CGFloat.infinity, right: 20),
      child: profileBox
    )
    
    return insetBox
  }
  
  override class func title() -> String {
    return "Common user profile layout."
  }
  
  override class func descriptionTitle() -> String? {
    return "For corner image layout and text truncation."
  }
  
}
