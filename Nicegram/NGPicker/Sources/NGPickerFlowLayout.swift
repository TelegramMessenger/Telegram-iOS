import UIKit

open class NGPickerFlowLayout: UICollectionViewFlowLayout {
    
    //  MARK: - Public Properties
    
    public var fullyVisibleItemsInRow: Int
    public var spacing: CGFloat
    
    //  MARK: - Lifecycle
    
    init(fullyVisibleItemsInRow: Int, spacing: CGFloat) {
        self.fullyVisibleItemsInRow = fullyVisibleItemsInRow
        self.spacing = spacing
        
        super.init()
        
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func commonInit() {
        scrollDirection = .horizontal
    }
    
    open override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        
        let itemSize = calcItemSize(collectionView: collectionView, section: 0)
        
        self.itemSize = itemSize
        self.minimumLineSpacing = spacing
    }
    
    //  MARK: - Calculations
    
    open func calcItemSize(collectionView: UICollectionView, section: Int) -> CGSize {
        let width = calcItemWidth(collectionView: collectionView)
        let height = collectionView.frame.height
        return .init(width: width, height: height)
    }
    
    open func calcItemWidth(collectionView: UICollectionView) -> CGFloat {
        let fullWidth = collectionView.frame.width
        let availableWidth = fullWidth - spacing * CGFloat(fullyVisibleItemsInRow + 1)
        return (availableWidth / CGFloat(fullyVisibleItemsInRow + 1))
    }
    
}
