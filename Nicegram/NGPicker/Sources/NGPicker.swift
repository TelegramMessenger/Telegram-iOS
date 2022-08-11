import UIKit
import SnapKit
import NGExtensions

public protocol PickerItem {
    var id: Int { get }
    var isSelected: Bool { get set }
}

open class NGPicker<Item: PickerItem, Cell: UICollectionViewCell>: UICollectionViewController {
    
    //  MARK: - Public Properties

    public var allowsMultipleSelection = false
    
    public var display: ((Item, Cell) -> ())?
    public var onSelect: ((Item) -> ())?
    
    //  MARK: - Logic
    
    private var items: [Item] = []
    
    //  MARK: - Lifecycle
    
    public init() {
        super.init(collectionViewLayout: NGPickerFlowLayout(fullyVisibleItemsInRow: 3, spacing: 12))
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        collectionView.register(Cell.self, forCellWithReuseIdentifier: "Cell")
    }
    
    //  MARK: - Public Functions
    
    public func display(items: [Item]) {
        self.items = items
        self.collectionView.reloadData()
    }

    public func selectItem(with id: Int, animated: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        
        if !allowsMultipleSelection {
            items.indices.forEach({ items[$0].isSelected = false })
        }
        items[index].isSelected = true

        let indexPath = IndexPath(row: index, section: 0)
        collectionView.reloadData()
        view.layoutIfNeeded()
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
    }
    
    //  MARK: - Data Source
    
    open override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    open override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? Cell else {
            return UICollectionViewCell()
        }
        
        let item = items[indexPath.row]
        display?(item, cell)
        
        return cell
    }
    
    open override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        onSelect?(item)
    }
}
