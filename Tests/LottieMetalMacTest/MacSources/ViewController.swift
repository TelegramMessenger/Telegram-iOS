import Cocoa

@objc(ViewController)
class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.blue.cgColor
    }
}

