import UIKit
import SnapKit
import NGExtensions
import NGLocalization
import NGTheme

public enum RoundedContainerViewType {
    case withFooter
    case withoutFooter
}

public class RoundedContainerView: UIView {
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var originalPosition: CGPoint?
    private var currentPositionTouched: CGPoint?

    public var onDismiss: (() -> Void)?
    public let footerView = UIView()
    
    let ngTheme: NGThemeColors
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
    
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = ngTheme.backgroundColor
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        if let panGestureRecognizer = panGestureRecognizer {
            addGestureRecognizer(panGestureRecognizer)
        }
//        roundCorners(corners: [.bottomLeft, .bottomRight], radius: 16.0)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func handleClose(completion: ((Bool) -> Void)?) {
        UIView.animate(withDuration: 0.2, animations: {
            self.frame.origin = CGPoint(
                x: self.frame.origin.x,
                y: -self.frame.size.height
            )
        }, completion: completion)
    }
    
    public func setupFooter(type: RoundedContainerViewType) {
        switch type {
        case .withFooter:
            footerView.backgroundColor = ngTheme.backgroundColor
            addSubview(footerView)
            footerView.snp.makeConstraints {
                $0.height.equalTo(38.0)
                $0.leading.trailing.bottom.equalToSuperview()
            }
            
            let secondSeparatorView = UIView()
            secondSeparatorView.backgroundColor = ngTheme.separatorColor
            footerView.addSubview(secondSeparatorView)
            secondSeparatorView.snp.makeConstraints {
                $0.height.equalTo(0.66)
                $0.top.equalToSuperview().inset(1.0)
                $0.leading.trailing.equalToSuperview().inset(16.0)
            }
            
            let swipeRectangleView = UIView()
            swipeRectangleView.layer.cornerRadius = 2
            swipeRectangleView.backgroundColor = ngTheme.subtitleColor
            footerView.addSubview(swipeRectangleView)
            swipeRectangleView.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalToSuperview().inset(17.0)
                $0.height.equalTo(4.0)
                $0.width.equalTo(36.0)
            }
        case .withoutFooter:
            break
        }
    }

    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }

    @objc func handleGesture(_ panGesture: UIPanGestureRecognizer) {
        let translation = panGesture.translation(in: self)

        if panGesture.state == .began {
            originalPosition = center
            currentPositionTouched = panGesture.location(in: self)
        } else if panGesture.state == .changed {
            frame.origin = CGPoint(
                x: frame.origin.x,
                y: (translation.y + frame.origin.y < frame.origin.y) ? translation.y : frame.origin.y
            )
        } else if panGesture.state == .ended {
            let velocity = panGesture.velocity(in: self)

            if velocity.y <= -1500 {
                UIView.animate(withDuration: 0.2, animations: {
                    self.frame.origin = CGPoint(
                        x: self.frame.origin.x,
                        y: -self.frame.size.height
                    )
                }, completion: { [weak self] (isCompleted) in
                    if isCompleted {
                        self?.onDismiss?()
                    }
                })
            } else {
                UIView.animate(withDuration: 0.2, animations: { [weak self] in
                    self?.center = self?.originalPosition ?? CGPoint.zero
                })
            }
        }
    }
}

