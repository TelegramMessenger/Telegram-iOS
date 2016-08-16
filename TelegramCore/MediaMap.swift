import Foundation
import SwiftSignalKit
import UIKit
import MapKit

private let roundCorners = { () -> UIImage in
    let diameter: CGFloat = 30.0
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}()

func telegramMapPreview(account: Account, map: TelegramMediaMap, displayDimensions: CGSize) -> Signal<UIImage, NoError> {
    let mapImage = Signal<UIImage, NoError> { subscriber in
        let latitude = map.latitude
        let region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(latitude, map.longitude), MKCoordinateSpanMake(0.003, 0.003))
        let imageSize = displayDimensions
        
        let options = MKMapSnapshotOptions()
        options.region = region
        options.mapType = .standard
        options.showsPointsOfInterest = false
        options.showsBuildings = true
        
        options.size = imageSize
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(completionHandler: { snapshot, error in
            Queue.concurrentBackgroundQueue().async {
                if let snapshot = snapshot {
                    subscriber.putNext(snapshot.image)
                }
                subscriber.putCompletion()
            }
        })
        
        return ActionDisposable {
            snapshotter.cancel()
        }
    }
    
    return mapImage |> mapToSignal { image -> Signal<UIImage, NoError> in
        UIGraphicsBeginImageContextWithOptions(displayDimensions, false, 0.0)
        
        image.draw(in: CGRect(origin: CGPoint(), size: displayDimensions), blendMode: .copy, alpha: 1.0)
        
        roundCorners.draw(in: CGRect(origin: CGPoint(), size: displayDimensions), blendMode: .destinationOut, alpha: 1.0)
        
        let processed = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return single(processed, NoError.self)
    }
}
