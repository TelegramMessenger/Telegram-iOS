import Combine
import UIKit

@available(iOS 13.0, *)
open class MVVMViewController<ViewModelType>: UIViewController where ViewModelType: ViewModel {
    
    //  MARK: - Public Properties
    
    public let viewModel: ViewModelType
    
    public var isViewOnScreen: Bool = false
    
    //  MARK: - Private Properties

    private let flowHolder: AnyObject
    private var viewStateSubscription: AnyCancellable?
    
    //  MARK: - Lifecycle
    
    public init(viewModel: ViewModelType, flowHolder: AnyObject) {
        self.viewModel = viewModel
        self.flowHolder = flowHolder
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        subscribeToViewStateChange()
        viewModel.viewWillAppear(animated)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.isViewOnScreen = true
        
        viewModel.viewDidAppear(animated)
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.viewWillDisappear(animated)
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.isViewOnScreen = false
        
        unsubscribeFromViewStateChange()
        
        viewModel.viewDidDisappear(animated)
    }
    
    //  MARK: - Public Functions

    open func updateState(_ state: ViewModelType.ViewState) {
        fatalError()
    }
    
    //  MARK: - Private Functions

    private func subscribeToViewStateChange() {
        self.viewStateSubscription = viewModel.statePublisher
            .sink { [weak self] state in
                self?.updateState(state)
            }
    }
    
    private func unsubscribeFromViewStateChange() {
        self.viewStateSubscription = nil
    }
}
