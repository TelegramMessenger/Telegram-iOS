import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import SwiftSignalKit

final class MentionChatInputContextPanelNode: ChatInputContextPanelNode, UITableViewDelegate, UITableViewDataSource {
    private let tableView: UITableView
    private let tableBackgroundView: UIView
    
    private var account: Account?
    private var results: [Peer] = []
    
    private let disposable = MetaDisposable()
    
    override init() {
        self.tableView = UITableView(frame: CGRect(), style: .plain)
        self.tableBackgroundView = UIView()
        self.tableBackgroundView.backgroundColor = UIColor.white
        
        super.init()
        
        self.clipsToBounds = true
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.rowHeight = 42.0
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.backgroundColor = nil
        self.tableView.isOpaque = false
        self.tableView.separatorInset = UIEdgeInsets(top: 0.0, left: 61.0, bottom: 0.0, right: 0.0)
        
        self.view.addSubview(self.tableBackgroundView)
        self.view.addSubview(self.tableView)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func setup(account: Account, peerId: PeerId, query: String) {
        self.account = account
        let signal = peerParticipants(account: account, id: peerId)
            |> deliverOnMainQueue
        
        self.disposable.set(signal.start(next: { [weak self] peers in
            if let strongSelf = self {
                strongSelf.results = peers
                strongSelf.tableView.reloadData()
                strongSelf.updateTable(animated: true)
            }
        }))
    }
    
    private func updateTable(animated: Bool = false) {
        let itemsHeight = CGFloat(self.results.count) * self.tableView.rowHeight
        let minimalDisplayedItemsHeight = floor(self.tableView.rowHeight * 3.5)
        let topInset = max(0.0, self.bounds.size.height - min(itemsHeight, minimalDisplayedItemsHeight))
        
        if animated {
            self.layer.animateBounds(from: self.layer.bounds.offsetBy(dx: 0.0, dy: -self.layer.bounds.size.height), to: self.layer.bounds, duration: 0.45, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        self.tableView.contentInset = UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0)
        self.tableView.contentOffset = CGPoint(x: 0.0, y: -topInset)
        self.tableView.setNeedsLayout()
    }
    
    override func updateFrames(transition: ContainedViewLayoutTransition) {
        self.tableView.frame = self.bounds
        self.updateTable()
    }
    
    override func animateIn() {
        self.layer.animateBounds(from: self.layer.bounds.offsetBy(dx: 0.0, dy: -self.layer.bounds.size.height), to: self.layer.bounds, duration: 0.45, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        self.layer.animateBounds(from: self.layer.bounds, to: self.layer.bounds.offsetBy(dx: 0.0, dy: -self.layer.bounds.size.height), duration: 0.25, timingFunction: kCAMediaTimingFunctionEaseOut, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.results.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = (tableView.dequeueReusableCell(withIdentifier: "C") as? MentionsTableCell) ?? MentionsTableCell()
        if let account = self.account {
            cell.setupPeer(account: account, peer: self.results[indexPath.row])
        }
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.tableBackgroundView.frame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, -self.tableView.contentOffset.y)), size: self.bounds.size)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let addressName = self.results[indexPath.row].addressName {
            let string = "@" + addressName + " "
            self.interfaceInteraction?.updateTextInputState(ChatTextInputState(inputText: string, selectionRange: string.characters.count ..< string.characters.count))
        }
    }
}
