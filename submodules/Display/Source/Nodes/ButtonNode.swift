import Foundation
import UIKit
import AsyncDisplayKit

open class ASButtonNode: ASControlNode {
    public let titleNode: ImmediateTextNode
    public let highlightedTitleNode: ImmediateTextNode
    public let disabledTitleNode: ImmediateTextNode
    public let imageNode: ASImageNode
    public let highlightedImageNode: ASImageNode
    public let selectedImageNode: ASImageNode
    public let highlightedSelectedImageNode: ASImageNode
    public let disabledImageNode: ASImageNode
    public let backgroundImageNode: ASImageNode
    public let highlightedBackgroundImageNode: ASImageNode
    
    public var contentEdgeInsets: UIEdgeInsets = UIEdgeInsets() {
        didSet {
            if self.contentEdgeInsets != oldValue {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
        }
    }
    
    public var contentHorizontalAlignment: ASHorizontalAlignment = .middle {
        didSet {
            if self.contentHorizontalAlignment != oldValue {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
        }
    }
    
    public var laysOutHorizontally: Bool = true {
        didSet {
            if self.laysOutHorizontally != oldValue {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
        }
    }
    
    public var contentSpacing: CGFloat = 0.0 {
        didSet {
            if self.contentSpacing != oldValue {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
        }
    }
    
    private var calculatedTitleSize: CGSize = CGSize()
    private var calculatedHighlightedTitleSize: CGSize = CGSize()
    private var calculatedDisabledTitleSize: CGSize = CGSize()
    
    override public init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.highlightedTitleNode = ImmediateTextNode()
        self.highlightedTitleNode.isUserInteractionEnabled = false
        self.highlightedTitleNode.displaysAsynchronously = false
        
        self.disabledTitleNode = ImmediateTextNode()
        self.disabledTitleNode.isUserInteractionEnabled = false
        self.disabledTitleNode.displaysAsynchronously = false
        
        self.imageNode = ASImageNode()
        self.imageNode.isUserInteractionEnabled = false
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        
        self.selectedImageNode = ASImageNode()
        self.selectedImageNode.isUserInteractionEnabled = false
        self.selectedImageNode.displaysAsynchronously = false
        self.selectedImageNode.displayWithoutProcessing = true
        
        self.highlightedImageNode = ASImageNode()
        self.highlightedImageNode.isUserInteractionEnabled = false
        self.highlightedImageNode.displaysAsynchronously = false
        self.highlightedImageNode.displayWithoutProcessing = true
        
        self.highlightedSelectedImageNode = ASImageNode()
        self.highlightedSelectedImageNode.isUserInteractionEnabled = false
        self.highlightedSelectedImageNode.displaysAsynchronously = false
        self.highlightedSelectedImageNode.displayWithoutProcessing = true
        
        self.disabledImageNode = ASImageNode()
        self.disabledImageNode.isUserInteractionEnabled = false
        self.disabledImageNode.displaysAsynchronously = false
        self.disabledImageNode.displayWithoutProcessing = true
        
        self.backgroundImageNode = ASImageNode()
        self.backgroundImageNode.isUserInteractionEnabled = false
        self.backgroundImageNode.displaysAsynchronously = false
        self.backgroundImageNode.displayWithoutProcessing = true
        
        self.highlightedBackgroundImageNode = ASImageNode()
        self.highlightedBackgroundImageNode.isUserInteractionEnabled = false
        self.highlightedBackgroundImageNode.displaysAsynchronously = false
        self.highlightedBackgroundImageNode.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.backgroundImageNode)
        self.addSubnode(self.highlightedBackgroundImageNode)
        self.highlightedBackgroundImageNode.isHidden = true
        self.addSubnode(self.titleNode)
        self.addSubnode(self.highlightedTitleNode)
        self.highlightedTitleNode.isHidden = true
        self.addSubnode(self.disabledTitleNode)
        self.disabledTitleNode.isHidden = true
        self.addSubnode(self.imageNode)
        self.addSubnode(self.selectedImageNode)
        self.selectedImageNode.isHidden = true
        self.addSubnode(self.highlightedImageNode)
        self.highlightedImageNode.isHidden = true
        self.addSubnode(self.highlightedSelectedImageNode)
        self.highlightedSelectedImageNode.isHidden = true
        self.addSubnode(self.disabledImageNode)
        self.disabledImageNode.isHidden = true
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let horizontalInsets = self.contentEdgeInsets.left + self.contentEdgeInsets.right
        let verticalInsets = self.contentEdgeInsets.top + self.contentEdgeInsets.bottom
        
        let imageSize = self.imageNode.image?.size ?? CGSize()
        
        let widthForTitle: CGFloat
        if self.laysOutHorizontally {
            widthForTitle = max(1.0, constrainedSize.width - horizontalInsets - imageSize.width - (imageSize.width.isZero ? 0.0 : self.contentSpacing))
        } else {
            widthForTitle = max(1.0, constrainedSize.width - horizontalInsets)
        }
        
        let normalTitleSize = self.titleNode.updateLayout(CGSize(width: widthForTitle, height: max(1.0, constrainedSize.height - verticalInsets)))
        self.calculatedTitleSize = normalTitleSize
        let highlightedTitleSize = self.highlightedTitleNode.updateLayout(CGSize(width: widthForTitle, height: max(1.0, constrainedSize.height - verticalInsets)))
        self.calculatedHighlightedTitleSize = highlightedTitleSize
        self.calculatedDisabledTitleSize = self.disabledTitleNode.updateLayout(CGSize(width: widthForTitle, height: max(1.0, constrainedSize.height - verticalInsets)))
        
        let titleSize = CGSize(width: max(normalTitleSize.width, highlightedTitleSize.width), height: max(normalTitleSize.height, highlightedTitleSize.height))
        
        var contentSize: CGSize
        if self.laysOutHorizontally {
            contentSize = CGSize(width: titleSize.width + imageSize.width, height: max(titleSize.height, imageSize.height))
            if !titleSize.width.isZero && !imageSize.width.isZero {
                contentSize.width += self.contentSpacing
            }
        } else {
            contentSize = CGSize(width: max(titleSize.width, imageSize.width), height: titleSize.height + imageSize.height)
            if !titleSize.width.isZero && !imageSize.width.isZero {
                contentSize.height += self.contentSpacing
            }
        }
        
        return CGSize(width: min(constrainedSize.width, contentSize.width + self.contentEdgeInsets.left + self.contentEdgeInsets.right), height: min(constrainedSize.height, contentSize.height + self.contentEdgeInsets.top + self.contentEdgeInsets.bottom))
    }
    
    open func setAttributedTitle(_ title: NSAttributedString, for state: UIControl.State) {
        if state == [] {
            if let attributedText = self.titleNode.attributedText {
                if !attributedText.isEqual(to: title) {
                    self.invalidateCalculatedLayout()
                    self.setNeedsLayout()
                }
            } else {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
            self.titleNode.attributedText = title
            
            if let attributedText = self.highlightedTitleNode.attributedText {
                if !attributedText.isEqual(to: title) {
                    self.invalidateCalculatedLayout()
                    self.setNeedsLayout()
                }
            } else {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
            self.highlightedTitleNode.attributedText = title
        } else if state == .highlighted || state == .selected {
            if let attributedText = self.highlightedTitleNode.attributedText {
                if !attributedText.isEqual(to: title) {
                    self.invalidateCalculatedLayout()
                    self.setNeedsLayout()
                }
            } else {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
            self.highlightedTitleNode.attributedText = title
        } else if state == .disabled {
            if let attributedText = self.disabledTitleNode.attributedText {
                if !attributedText.isEqual(to: title) {
                    self.invalidateCalculatedLayout()
                    self.setNeedsLayout()
                }
            } else {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
            self.disabledTitleNode.attributedText = title
        } else {
            if let attributedText = self.titleNode.attributedText {
                if !attributedText.isEqual(to: title) {
                    self.invalidateCalculatedLayout()
                    self.setNeedsLayout()
                }
            } else {
                self.invalidateCalculatedLayout()
                self.setNeedsLayout()
            }
            self.titleNode.attributedText = title
        }
    }
    
    open func attributedTitle(for state: UIControl.State) -> NSAttributedString? {
        if state == .highlighted || state == .selected {
            return self.highlightedTitleNode.attributedText
        } else if state == .disabled {
            return self.disabledTitleNode.attributedText
        } else {
            return self.titleNode.attributedText
        }
    }
    
    open func setTitle(_ title: String, with font: UIFont, with color: UIColor, for state: UIControl.State) {
        self.setAttributedTitle(NSAttributedString(string: title, font: font, textColor: color), for: state)
    }
    
    open func setImage(_ image: UIImage?, for state: UIControl.State) {
        if image?.size != self.imageNode.image?.size {
            self.invalidateCalculatedLayout()
            self.setNeedsLayout()
        }
        if state == .disabled {
            self.disabledImageNode.image = image
        } else if state == [] {
            self.imageNode.image = image
        } else if state == .highlighted {
            self.highlightedImageNode.image = image
        } else if state == .selected {
            self.selectedImageNode.image = image
        } else if state == [.selected, .highlighted] {
            self.highlightedSelectedImageNode.image = image
        } else {
            self.imageNode.image = image
        }
    }
    
    open func setBackgroundImage(_ image: UIImage?, for state: UIControl.State) {
        if state == [] {
            self.backgroundImageNode.image = image
            self.highlightedBackgroundImageNode.image = image
        } else if state == .highlighted || state == .selected || state == [.selected, .highlighted] {
            self.highlightedBackgroundImageNode.image = image
        } else {
            self.backgroundImageNode.image = image
        }
    }
    
    open func image(for state: UIControl.State) -> UIImage? {
        switch state {
        case .disabled:
            return self.disabledImageNode.image ?? self.imageNode.image
        default:
            return self.imageNode.image
        }
    }
    
    open func backgroundImage(for state: UIControl.State) -> UIImage? {
        return self.backgroundImageNode.image
    }
    
    override open var isSelected: Bool {
        didSet {
            if self.isSelected != oldValue {
                if self.isSelected {
                    if self.selectedImageNode.image != nil {
                        self.selectedImageNode.isHidden = false
                        self.imageNode.isHidden = true
                    } else {
                        self.selectedImageNode.isHidden = true
                        self.imageNode.isHidden = false
                    }
                } else {
                    self.selectedImageNode.isHidden = true
                    self.imageNode.isHidden = false
                }
            }
        }
    }
    
    override open var isHighlighted: Bool {
        didSet {
            if self.isHighlighted != oldValue && !self.isImplicitlyDisabled {
                let isHighlighted = self.isHighlighted
                if isHighlighted {
                    if self.highlightedTitleNode.attributedText != nil {
                        self.highlightedTitleNode.isHidden = false
                        self.titleNode.isHidden = true
                    } else {
                        self.highlightedTitleNode.isHidden = true
                        self.titleNode.isHidden = false
                    }
                    if self.highlightedBackgroundImageNode.image != nil {
                        self.highlightedBackgroundImageNode.isHidden = false
                        self.backgroundImageNode.isHidden = true
                    } else {
                        self.highlightedBackgroundImageNode.isHidden = true
                        self.backgroundImageNode.isHidden = false
                    }
                    if self.isSelected && self.highlightedSelectedImageNode.image != nil {
                        self.highlightedSelectedImageNode.isHidden = false
                        self.highlightedImageNode.isHidden = true
                        self.selectedImageNode.isHidden = true
                        self.imageNode.isHidden = true
                    } else if self.highlightedImageNode.image != nil {
                        self.highlightedSelectedImageNode.isHidden = true
                        self.highlightedImageNode.isHidden = false
                        self.imageNode.isHidden = true
                    } else {
                        self.highlightedSelectedImageNode.isHidden = true
                        self.highlightedImageNode.isHidden = true
                        self.imageNode.isHidden = false
                    }
                } else {
                    self.highlightedTitleNode.isHidden = true
                    self.titleNode.isHidden = false
                    
                    self.highlightedBackgroundImageNode.isHidden = true
                    self.backgroundImageNode.isHidden = false
                    
                    self.highlightedSelectedImageNode.isHidden = true
                    self.highlightedImageNode.isHidden = true
                    if self.isSelected && self.selectedImageNode.image != nil {
                        self.selectedImageNode.isHidden = false
                        self.imageNode.isHidden = true
                    } else {
                        self.selectedImageNode.isHidden = true
                        self.imageNode.isHidden = false
                    }
                }
            }
        }
    }
    
    open var isImplicitlyDisabled: Bool = false {
        didSet {
            if self.isImplicitlyDisabled != oldValue {
                self.updateIsEnabled()
            }
        }
    }
    
    override open var isEnabled: Bool {
        didSet {
            if self.isEnabled != oldValue {
                self.updateIsEnabled()
            }
        }
    }
    
    private func updateIsEnabled() {
        let isEnabled = self.isEnabled && !self.isImplicitlyDisabled
        
        if isEnabled || self.disabledTitleNode.attributedText == nil {
            self.titleNode.isHidden = false
            self.disabledTitleNode.isHidden = true
        } else {
            self.titleNode.isHidden = true
            self.disabledTitleNode.isHidden = false
        }
        
        if isEnabled || self.disabledImageNode.image == nil {
            self.imageNode.isHidden = false
            self.disabledImageNode.isHidden = true
        } else {
            self.imageNode.isHidden = true
            self.disabledImageNode.isHidden = false
        }
    }
    
    override open func layout() {
        let size = self.bounds.size
        
        let contentRect = CGRect(origin: CGPoint(x: self.contentEdgeInsets.left, y: self.contentEdgeInsets.top), size: CGSize(width: size.width - self.contentEdgeInsets.left - self.contentEdgeInsets.right, height: size.height - self.contentEdgeInsets.top - self.contentEdgeInsets.bottom))
        
        let imageSize = self.imageNode.image?.size ?? CGSize()
        
        let titleOrigin: CGPoint
        let highlightedTitleOrigin: CGPoint
        let disabledTitleOrigin: CGPoint
        let imageOrigin: CGPoint
        
        if self.laysOutHorizontally {
            switch self.contentHorizontalAlignment {
            case .left:
                titleOrigin = CGPoint(x: contentRect.minX, y: contentRect.minY + floor((contentRect.height - self.calculatedTitleSize.height) / 2.0))
                highlightedTitleOrigin = CGPoint(x: contentRect.minX, y: contentRect.minY + floor((contentRect.height - self.calculatedHighlightedTitleSize.height) / 2.0))
                disabledTitleOrigin = CGPoint(x: contentRect.minX, y: contentRect.minY + floor((contentRect.height - self.calculatedDisabledTitleSize.height) / 2.0))
                imageOrigin = CGPoint(x: titleOrigin.x + self.calculatedTitleSize.width + self.contentSpacing, y: contentRect.minY + floor((contentRect.height - imageSize.height) / 2.0))
            case .right:
                titleOrigin = CGPoint(x: contentRect.maxX - self.calculatedTitleSize.width, y: contentRect.minY + floor((contentRect.height - self.calculatedTitleSize.height) / 2.0))
                highlightedTitleOrigin = CGPoint(x: contentRect.maxX - self.calculatedHighlightedTitleSize.width, y: contentRect.minY + floor((contentRect.height - self.calculatedHighlightedTitleSize.height) / 2.0))
                disabledTitleOrigin = CGPoint(x: contentRect.maxX - self.calculatedDisabledTitleSize.width, y: contentRect.minY + floor((contentRect.height - self.calculatedDisabledTitleSize.height) / 2.0))
                imageOrigin = CGPoint(x: titleOrigin.x - self.contentSpacing - imageSize.width, y: contentRect.minY + floor((contentRect.height - imageSize.height) / 2.0))
            default:
                titleOrigin = CGPoint(x: contentRect.minX + floor((contentRect.width - self.calculatedTitleSize.width) / 2.0), y: contentRect.minY + floor((contentRect.height - self.calculatedTitleSize.height) / 2.0))
                highlightedTitleOrigin = CGPoint(x: contentRect.minX + floor((contentRect.width - self.calculatedHighlightedTitleSize.width) / 2.0), y: contentRect.minY + floor((contentRect.height - self.calculatedHighlightedTitleSize.height) / 2.0))
                disabledTitleOrigin = CGPoint(x: floor((contentRect.width - self.calculatedDisabledTitleSize.width) / 2.0), y: contentRect.minY + floor((contentRect.height - self.calculatedDisabledTitleSize.height) / 2.0))
                imageOrigin = CGPoint(x: floor((contentRect.width - imageSize.width) / 2.0), y: contentRect.minY + floor((contentRect.height - imageSize.height) / 2.0))
            }
        } else {
            var contentHeight: CGFloat = self.calculatedTitleSize.height
            if !imageSize.height.isZero {
                contentHeight += self.contentSpacing + imageSize.height
            }
            let contentY = contentRect.minY + floor((contentRect.height - contentHeight) / 2.0)
            titleOrigin = CGPoint(x: contentRect.minX + floor((contentRect.width - self.calculatedTitleSize.width) / 2.0), y: contentY + contentHeight - self.calculatedTitleSize.height)
            highlightedTitleOrigin = CGPoint(x: contentRect.minX + floor((contentRect.width - self.calculatedHighlightedTitleSize.width) / 2.0), y: contentY + contentHeight - self.calculatedHighlightedTitleSize.height)
            disabledTitleOrigin = CGPoint(x: contentRect.minX + floor((contentRect.width - self.calculatedDisabledTitleSize.width) / 2.0), y: contentY + contentHeight - self.calculatedDisabledTitleSize.height)
            imageOrigin = CGPoint(x: floor((contentRect.width - imageSize.width) / 2.0), y: contentY)
        }
        
        self.titleNode.frame = CGRect(origin: titleOrigin, size: self.calculatedTitleSize)
        self.highlightedTitleNode.frame = CGRect(origin: highlightedTitleOrigin, size: self.calculatedHighlightedTitleSize)
        self.disabledTitleNode.frame = CGRect(origin: disabledTitleOrigin, size: self.calculatedDisabledTitleSize)
        self.imageNode.frame = CGRect(origin: imageOrigin, size: imageSize)
        self.selectedImageNode.frame = CGRect(origin: imageOrigin, size: imageSize)
        self.highlightedImageNode.frame =  CGRect(origin: imageOrigin, size: imageSize)
        self.highlightedSelectedImageNode.frame =  CGRect(origin: imageOrigin, size: imageSize)
        self.disabledImageNode.frame = CGRect(origin: imageOrigin, size: imageSize)
        
        self.backgroundImageNode.frame = CGRect(origin: CGPoint(), size: size)
        self.highlightedBackgroundImageNode.frame = CGRect(origin: CGPoint(), size: size)
    }
}
