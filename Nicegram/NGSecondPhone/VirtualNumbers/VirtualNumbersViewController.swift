import UIKit
import SnapKit
import NGButton
import NGExtensions
import NGCustomViews

protocol VirtualNumbersViewControllerInput {
    // func displaySmth(viewModel: SomeModel)
}

protocol VirtualNumbersViewControllerOutput {
    func onViewDidLoad()
    // func doSmth(request: RequestModel)
}

final class VirtualNumbersViewController: UIViewController, VirtualNumbersViewControllerInput {
    var output: VirtualNumbersViewControllerOutput!
    var router: VirtualNumbersRouterInput!

    private let scrollView = UIScrollView()
    private let containerView = UIView()

    private let walletView = AssistantWalletContainerView()
    private let numbersStackView = UIStackView()
    private let footerView = UIView()
    private let addNumberButton = NGButton()

    override func loadView() {
        super.loadView()
        view = UIView()
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(self.view.safeArea.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
            $0.height.equalToSuperview().priority(.low)
        }

        containerView.addSubview(numbersStackView)
        numbersStackView.spacing = 8.0
        numbersStackView.distribution = .fillEqually
        numbersStackView.axis = .vertical
        numbersStackView.alignment = .fill
        numbersStackView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(16.0)
            $0.leading.trailing.equalToSuperview().inset(8.0)
            $0.bottom.lessThanOrEqualToSuperview().inset(30.0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ngBackground
        output.onViewDidLoad()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
}

extension VirtualNumbersViewController: VirtualNumbersPresenterOutput {
    func display(numbers: [MyNumberItem]) {
        for number in numbers {
            let numberView = MyNumberView()
            numberView.display(numberItem: number)
            numberView.snp.makeConstraints {
                $0.height.equalTo(130.0)
            }
            self.numbersStackView.addArrangedSubview(numberView)
        }
    }
}
