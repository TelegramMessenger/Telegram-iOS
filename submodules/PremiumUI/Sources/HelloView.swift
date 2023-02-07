import Foundation
import UIKit
import Display
import SwiftSignalKit

private let phrases = [
    "Вітаю",
    "你好",
    "Hello",
    "سلام",
    "Bonjour",
    "Guten tag",
    "שלום",
    "नमस्ते",
    "Ciao",
    "こんにちは",
    "Hei",
    "Olá",
    "Привет",
    "Zdravo",
    "Hola",
    "Привіт",
    "Salom",
    "Halo"
]

private var simultaneousDisplayCount = 13

private let referenceWidth: CGFloat = 1180
private let positions: [CGPoint] = [
    CGPoint(x: 315.0, y: 83.0),
    CGPoint(x: 676.0, y: 18.0),
    CGPoint(x: 880.0, y: 130.0),
    CGPoint(x: 90.0, y: 214.0),
    CGPoint(x: 550.0, y: 150.0),
    CGPoint(x: 1130.0, y: 220.0),
    CGPoint(x: 220.0, y: 440.0),
    CGPoint(x: 1080.0, y: 350.0),
    CGPoint(x: 85.0, y: 630.0),
    CGPoint(x: 1180.0, y: 550.0),
    CGPoint(x: 150.0, y: 810.0),
    CGPoint(x: 1010.0, y: 770.0),
    CGPoint(x: 40.0, y: 1000.0),
    CGPoint(x: 1130.0, y: 1000.0)
]

final class HelloView: UIView, PhoneDemoDecorationView {
    private var activePhrases = Set<Int>()
    private var activePositions = Set<Int>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupAnimations() {
        guard self.activePhrases.isEmpty else {
            return
        }
        var ids: [Int] = []
        for i in 0 ..< phrases.count {
            ids.append(i)
        }
        ids.shuffle()
        
        let phraseIds = Array(self.availablePhraseIds()).shuffled()
        let positionIds = Array(self.availablePositionIds()).shuffled()
        
        for i in 0 ..< simultaneousDisplayCount {
            let delay: Double = Double.random(in: 0.0 ..< 0.8)
            Queue.mainQueue().after(delay) {
                self.spawnPhrase(phraseIds[i], positionIndex: positionIds[i])
            }
        }
    }
    
    func availablePhraseIds() -> Set<Int> {
        var ids = Set<Int>()
        for i in 0 ..< phrases.count {
            ids.insert(i)
        }
        for id in self.activePhrases {
            ids.remove(id)
        }
        return ids
    }
    
    func availablePositionIds() -> Set<Int> {
        var ids = Set<Int>()
        for i in 0 ..< positions.count {
            ids.insert(i)
        }
        for id in self.activePositions {
            ids.remove(id)
        }
        return ids
    }
    
    func spawnNextPhrase() {
        let phraseIds = Array(self.availablePhraseIds()).shuffled()
        let positionIds = Array(self.availablePositionIds()).shuffled()
        if let phrase = phraseIds.first, let position = positionIds.first {
            self.spawnPhrase(phrase, positionIndex: position)
        }
    }
    
    func spawnPhrase(_ index: Int, positionIndex: Int) {
        let view = UILabel()
        view.alpha = 0.0
        view.text = phrases[index]
        view.font = Font.with(size: 24.0, design: .round, weight: .semibold, traits: [])
        view.textColor = UIColor(rgb: 0xffffff, alpha: CGFloat.random(in: 0.4 ... 0.6))
        view.layer.compositingFilter = "softLightBlendMode"
        view.sizeToFit()
        view.center = self.positionForIndex(positionIndex)
        
        self.activePhrases.insert(index)
        self.activePositions.insert(positionIndex)
        
        let duration: Double = Double.random(in: 1.75...2.25)
        view.layer.animateKeyframes(values: [0.0, 1.0, 0.0] as [NSNumber], duration: duration, keyPath: "opacity", removeOnCompletion: false, completion: { [weak view, weak self] _ in
            if let self {
                self.activePhrases.remove(index)
                self.activePositions.remove(positionIndex)
                view?.removeFromSuperview()
                self.spawnNextPhrase()
            }
        })
        view.layer.animateScale(from: CGFloat.random(in: 0.4 ..< 0.6), to: CGFloat.random(in: 0.9 ..< 1.2), duration: duration, removeOnCompletion: false)
        
        self.addSubview(view)
    }
    
    func positionForIndex(_ index: Int) -> CGPoint {
        var position = positions[index]
        let spread: CGPoint = CGPoint(x: 30.0, y: 5.0)
        position.x = (self.frame.width - self.frame.height) / 2.0 + position.x / referenceWidth * self.frame.height + CGFloat.random(in: -spread.x ... spread.x)
        position.y = position.y / referenceWidth * self.frame.height + CGFloat.random(in: -spread.y ... spread.y)
        return position
    }
    
    func setVisible(_ visible: Bool) {
        self.setupAnimations()
    }
    
    func resetAnimation() {
        
    }
}
