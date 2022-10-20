import UIKit
import SnapKit
import AVKit

struct OnboardingPageViewModel {
    let title: String
    let description: String
    let videoURL: URL
}

class OnboardingPageView: UIView {
    
    //  MARK: - UI Elements

    private let videoView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let playerLayer = AVPlayerLayer()
    
    //  MARK: - Logic
    
    private var playerLooperHolder: AnyObject?
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .ngSubtitle
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        
        playerLayer.videoGravity = .resizeAspectFill
        
        let descriptionContainer = UIView()
        descriptionContainer.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        videoView.layer.addSublayer(playerLayer)
        
        addSubview(videoView)
        addSubview(titleLabel)
        addSubview(descriptionContainer)
        
        descriptionContainer.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(80)
            make.height.equalTo(80).priority(1)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(descriptionLabel.snp.top).offset(-12)
            make.leading.trailing.equalToSuperview().inset(60)
        }
        
        videoView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(titleLabel.snp.top)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        playerLayer.frame = videoView.bounds
    }
    
    //  MARK: - Public Functions

    func display(_ item: OnboardingPageViewModel) {
        titleLabel.text = item.title
        descriptionLabel.text = item.description
        
        let asset = AVAsset(url: item.videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: playerItem)
        if #available(iOS 10.0, *) {
            let looper = AVPlayerLooper(player: player, templateItem: playerItem)
            self.playerLooperHolder = looper
        }

        self.playerLayer.player = player
    }
    
    func playVideo() {
        self.playerLayer.player?.play()
    }
    
    func pauseVideo() {
        self.playerLayer.player?.pause()
    }
}
