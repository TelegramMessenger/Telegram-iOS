import NGLoadingIndicator
import UIKit

public class LoadingView: UIView {
    
    //  MARK: - Public Properties

    public var isLoading: Bool = false {
        didSet {
            if isLoading, !isLoadingAnimationInFlight {
                loadingInicator.startAnimating(on: containerView)
                isLoadingAnimationInFlight = true
            } else if !isLoading, isLoadingAnimationInFlight {
                loadingInicator.stopAnimating()
                isLoadingAnimationInFlight = false
            }
        }
    }
    
    //  MARK: - Logic
    
    private let loadingInicator = NGLoadingIndicator()
    private var isLoadingAnimationInFlight: Bool = false
    private weak var containerView: UIView?
    
    //  MARK: - Lifecycle
    
    public init(containerView: UIView?) {
        self.containerView = containerView
        
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
