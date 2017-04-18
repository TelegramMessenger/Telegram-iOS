import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Photos
import SwiftSignalKit

final class ChatMediaActionSheetRollItem: ActionSheetItem {
    private let assetSelected: (PHAsset) -> Void
    
    init(assetSelected: @escaping (PHAsset) -> Void) {
        self.assetSelected = assetSelected
    }
    
    func node() -> ActionSheetItemNode {
        return ChatMediaActionSheetRollItemNode(assetSelected: self.assetSelected)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ChatMediaActionSheetRollItemNode: ActionSheetItemNode, PHPhotoLibraryChangeObserver {
    private let listView: ListView
    private let label: UILabel
    private let button: HighlightTrackingButton
    
    private var assetCollection: PHAssetCollection?
    private var fetchResult: PHFetchResult<PHAsset>?
    
    private let assetSelected: (PHAsset) -> Void
    
    init(assetSelected: @escaping (PHAsset) -> Void) {
        self.assetSelected = assetSelected
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        
        self.label = UILabel()
        self.label.backgroundColor = nil
        self.label.isOpaque = false
        self.label.textColor = UIColor(0x007ee5)
        self.label.text = "Photo or Video"
        self.label.font = Font.regular(20.0)
        self.label.sizeToFit()
        
        self.button = HighlightTrackingButton()
        
        super.init()
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = ActionSheetItemNode.highlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = ActionSheetItemNode.defaultBackgroundColor
                    })
                }
            }
        }
        self.view.addSubview(self.button)
        
        self.view.addSubview(self.label)
        self.addSubnode(self.listView)
        
        PHPhotoLibrary.requestAuthorization({ _ in
            
        })
        
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        self.fetchResult = PHAsset.fetchAssets(with: .image, options: allPhotosOptions)
        
        var items: [ListViewItem] = []
        if let fetchResult = self.fetchResult {
            for i in 0 ..< fetchResult.count {
                let asset = fetchResult.object(at: i)
                items.append(ActionSheetRollImageItem(asset: asset, selected: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.assetSelected(asset)
                    }
                }))
            }
        }
        
        if !items.isEmpty {
            self.listView.transaction(deleteIndices: [], insertIndicesAndItems: (0 ..< items.count).map({ ListViewInsertItem(index: $0, previousIndex: nil, item: items[$0], directionHint: .Down) }), updateIndicesAndItems: [], options: [], updateOpaqueState: nil)
        }
        
        //PHPhotoLibrary.shared().register(self)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 157.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.button.frame = CGRect(origin: CGPoint(), size: bounds.size)
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 84.0, height: bounds.size.width)
        self.listView.position = CGPoint(x: bounds.size.width / 2.0, y: 84.0 / 2.0 + 8.0)
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: 84.0, height: bounds.size.width), insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), duration: 0.0, curve: .Default)
        
        let labelSize = self.label.bounds.size
        self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.size.width - labelSize.width) / 2.0), y: 84.0 + 16.0 + floorToScreenPixels((bounds.height - 84.0 - 16.0 - labelSize.height) / 2.0)), size: labelSize)
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Queue.concurrentDefaultQueue().async {
            //let collectionChanges = changeInstance.changeDetailsForFetchResult(self.fetchResult)
            //self.fetchResult = collectionChanges.fetchResultAfterChanges()
            
        }
    }
}
