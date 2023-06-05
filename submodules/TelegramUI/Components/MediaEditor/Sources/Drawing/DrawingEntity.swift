import Foundation
import UIKit

public protocol DrawingEntity: AnyObject {
    var uuid: UUID { get }
    var isAnimated: Bool { get }
    var center: CGPoint { get }
    
    var isMedia: Bool { get }
    
    var lineWidth: CGFloat { get set }
    var color: DrawingColor { get set }
    
    var scale: CGFloat { get set }
    
    func duplicate() -> DrawingEntity
    
    var renderImage: UIImage? { get set }
    var renderSubEntities: [DrawingEntity]? { get set }
    
    func isEqual(to other: DrawingEntity) -> Bool
}
