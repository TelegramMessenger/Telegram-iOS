import UIKit
import SnapKit
import NGExtensions
import NGTheme

extension MyEsimCell: ReuseIdentifiable {}

class MyEsimCell: UITableViewCell {
    
    //  MARK: - UI Elements

    private let myEsimView = MyEsimView()
    
    //  MARK: - Public Properties
    
    var ngTheme: NGThemeColors? {
        get { myEsimView.ngTheme }
        set { myEsimView.ngTheme = newValue }
    }
    
    var onTap: (() ->())? {
        get { myEsimView.onTap }
        set { myEsimView.onTap = newValue }
    }

    var onTopUpTap: (() ->())? {
        get { myEsimView.onTopUpTap }
        set { myEsimView.onTopUpTap = newValue }
    }
    
    var onFaqTap: (() -> ())? {
        get { myEsimView.onFaqTap }
        set { myEsimView.onFaqTap = newValue }
    }
    
    var onCopyPhoneTap: (() -> ())? {
        get { myEsimView.onCopyPhoneTap }
        set { myEsimView.onCopyPhoneTap = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle  = .none
        backgroundColor = .clear
        
        contentView.addSubview(myEsimView)
        myEsimView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(item: MyEsimViewModel) {
        myEsimView.display(item: item)
    }
}
