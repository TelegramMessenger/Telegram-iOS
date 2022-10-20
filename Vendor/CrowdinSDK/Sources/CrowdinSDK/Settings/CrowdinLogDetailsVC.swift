//
//  CrowdinLogDetailsVC.swift
//  CrowdinSDK
//
//  Created by Nazar Yavornytskyy on 2/16/21.
//

import UIKit

final class CrowdinLogDetailsVC: UIViewController {
    
    @IBOutlet private weak var textView: UITextView!
    
    private var details: NSAttributedString?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepare()
    }
    
    // MARK: - Public
    
    func setup(with details: NSAttributedString?) {
        self.details = details
    }
    
    // MARK: - Private
    
    private func prepare() {
        textView.attributedText = details
    }
}
