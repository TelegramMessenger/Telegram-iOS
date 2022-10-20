import UIKit
import SnapKit
import Lottie
import NGButton
import NGTheme

open class BottomButtonView: UIView {
    
    //  MARK: - UI Elements
    
    private let gradientView = GradientView()
    private let buttonWrapper = PlaceholderableView(wrappedView: CustomButton())
    private var button: CustomButton { buttonWrapper.wrappedView }
    
    //  MARK: - Public Properties

    public var gradientColors: [UIColor] {
        get { gradientView.colors }
        set { gradientView.colors = newValue }
    }
    
    public var buttonTouchUpInside: (() -> ())? {
        get { button.touchUpInside }
        set { button.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        super.init(frame: .zero)
        
        gradientColors = [ngTheme.backgroundColor.withAlphaComponent(0), ngTheme.backgroundColor]
        
        button.applyMainActionStyle()
        
        addSubview(gradientView)
        addSubview(buttonWrapper)
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        buttonWrapper.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(gradientView.snp.top).inset(38)
            make.bottom.equalToSuperview().inset(48).priority(999)
            make.bottom.lessThanOrEqualTo(safeArea.bottom)
            make.height.equalTo(54)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    public func display(buttonTitle: String) {
        button.display(title: buttonTitle, image: nil)
    }
    
    public func display(isLoading: Bool) {
        if isLoading {
            let loadingView = AnimationView(name: "NicegramLoader")
            loadingView.loopMode = .loop
            
            let loadingContainerView = UIView()
            
            loadingContainerView.addSubview(loadingView)
            
            loadingView.snp.makeConstraints { make in
                make.width.height.equalTo(50)
                make.center.equalToSuperview()
            }
            
            loadingView.play()
            buttonWrapper.showPlaceholder(loadingContainerView)
        } else {
            buttonWrapper.hidePlaceholder()
        }
    }
}
