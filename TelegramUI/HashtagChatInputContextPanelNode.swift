import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display

final class HashtagChatInputContextPanelNode: ChatInputContextPanelNode, UITableViewDelegate, UITableViewDataSource {
    private let tableView: UITableView
    private let tableBackgroundView: UIView
    
    private var results: [String] = []
    
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
        
        self.view.addSubview(self.tableBackgroundView)
        self.view.addSubview(self.tableView)
        
        self.results = (0 ..< 50).map { "#tag \($0)" }
    }
    
    func setup(account: Account, peerId: PeerId, query: String) {
    }
    
    private func updateTable() {
        let itemsHeight = CGFloat(self.results.count) * self.tableView.rowHeight
        let minimalDisplayedItemsHeight = floor(self.tableView.rowHeight * 3.5)
        let topInset = max(0.0, self.bounds.size.height - min(itemsHeight, minimalDisplayedItemsHeight))
        
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
        var cell = (tableView.dequeueReusableCell(withIdentifier: "C") as? HashtagsTableCell) ?? HashtagsTableCell()
        cell.textLabel?.text = self.results[indexPath.row]
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.tableBackgroundView.frame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, -self.tableView.contentOffset.y)), size: self.bounds.size)
    }
}
