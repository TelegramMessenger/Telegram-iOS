import NGCore
import NGToast

public func showLotteryBannerAsToast(jackpot: Money, onTap: @escaping () -> Void) {
    let banner = LotteryBannerView()
    banner.display(jackpot: jackpot)
    
    let toast = NGToast(topInsetFromSafeArea: 65)
    toast.duration = nil
    toast.setContentView(banner)
    
    banner.onTap = { [weak toast] in
        toast?.hide()
        onTap()
    }
    banner.onClose = { [weak toast] in
        toast?.hide()
    }
    
    toast.show()
}
