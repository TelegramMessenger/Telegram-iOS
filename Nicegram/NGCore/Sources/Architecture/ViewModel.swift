import Combine
import Foundation

@available(iOS 13.0, *)
public protocol ViewModel: AnyObject {
    associatedtype ViewState
    
    var statePublisher: AnyPublisher<ViewState, Never> { get }
    
    func viewDidLoad()
    func viewWillAppear(_ animated: Bool)
    func viewDidAppear(_ animated: Bool)
    func viewWillDisappear(_ animated: Bool)
    func viewDidDisappear(_ animated: Bool)
}

@available(iOS 13.0, *)
open class BaseViewModel<ViewStateType, InputType, HandlersType>: ViewModel where ViewStateType: ViewState {
    
    @Published private var viewState = ViewStateType()
    public var statePublisher: AnyPublisher<ViewStateType, Never> {
        $viewState.eraseToAnyPublisher()
    }
    
    //  MARK: - Logic
    
    public let input: InputType
    public let handlers: HandlersType
    
    public var cancellables = Set<AnyCancellable>()
    
    //  MARK: - View Lifecycle
    
    public init(input: InputType, handlers: HandlersType) {
        self.input = input
        self.handlers = handlers
    }
    
    open func viewDidLoad() {
        
    }
    
    open func viewWillAppear(_ animated: Bool) {
        
    }
    
    open func viewDidAppear(_ animated: Bool) {
        
    }
    
    open func viewWillDisappear(_ animated: Bool) {
        
    }
    
    open func viewDidDisappear(_ animated: Bool) {
        
    }
    
    //  MARK: - Public Functions

    public func updateViewState(_ block: @escaping (inout ViewStateType) -> Void) {
        DispatchQueue.main.async {
            var state = self.viewState
            block(&state)
            self.viewState = state
        }
    }
}
