import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import Display

public struct OpenInAppIconResourceId {
    public let appStoreId: Int64
    
    public var uniqueId: String {
        return "app-icon-\(appStoreId)"
    }
    
    public var hashValue: Int {
        return self.appStoreId.hashValue
    }
}

public class OpenInAppIconResource {
    public let appStoreId: Int64
    public let store: String?
    
    public init(appStoreId: Int64, store: String?) {
        self.appStoreId = appStoreId
        self.store = store
    }
    
    public var id: EngineMediaResource.Id {
        return EngineMediaResource.Id(OpenInAppIconResourceId(appStoreId: self.appStoreId).uniqueId)
    }
}

public func fetchOpenInAppIconResource(engine: TelegramEngine, resource: OpenInAppIconResource) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
    return Signal { subscriber in
        let metaUrl: String
        if let store = resource.store {
            metaUrl = "https://itunes.apple.com/\(store)/lookup?id=\(resource.appStoreId)"
        } else {
            metaUrl = "https://itunes.apple.com/lookup?id=\(resource.appStoreId)"
        }
        
        let fetchDisposable = MetaDisposable()
        
        let disposable = fetchHttpResource(url: metaUrl).start(next: { result in
            if case let .dataPart(_, data, _, complete) = result, complete {
                guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                    subscriber.putError(.generic)
                    return
                }
                
                guard let results = dict["results"] as? [Any] else {
                    subscriber.putError(.generic)
                    return
                }
                
                guard let result = results.first as? [String: Any] else {
                    subscriber.putError(.generic)
                    return
                }
                
                guard let artworkUrl = result["artworkUrl100"] as? String else {
                    subscriber.putError(.generic)
                    return
                }
                
                if artworkUrl.isEmpty {
                    subscriber.putError(.generic)
                    return
                } else {
                    fetchDisposable.set(engine.resources.httpData(url: artworkUrl).start(next: { data in
                        let file = EngineTempBox.shared.tempFile(fileName: "image.jpg")
                        let _ = try? data.write(to: URL(fileURLWithPath: file.path))
                        subscriber.putNext(.moveTempFile(file: file))
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            fetchDisposable.dispose()
        }
    }
}

private func openInAppIconData(engine: TelegramEngine, appIcon: OpenInAppIconResource) -> Signal<Data?, NoError> {
    let appIconResource = engine.resources.custom(
        id: appIcon.id.stringRepresentation,
        fetch: EngineMediaResource.Fetch {
            return fetchOpenInAppIconResource(engine: engine, resource: appIcon)
        }
    )

    return appIconResource
    |> map { data -> Data? in
        if data.isComplete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [])
            return loadedData
        } else {
            return nil
        }
    }
}

public enum OpenInAppIcon {
    case resource(resource: OpenInAppIconResource)
    case image(image: UIImage)
}

private func drawOpenInAppIconBorder(into c: CGContext, arguments: TransformImageArguments) {
    c.setBlendMode(.normal)
    c.setStrokeColor(UIColor(rgb: 0xe5e5e5).cgColor)

    let lineWidth: CGFloat = arguments.drawingRect.size.width < 30.0 ? 1.0 - UIScreenPixel : 1.0
    c.setLineWidth(lineWidth)

    var radius: CGFloat = 0.0
    if case let .Corner(cornerRadius) = arguments.corners.topLeft, cornerRadius > CGFloat.ulpOfOne {
        radius = max(0, cornerRadius - 0.5)
    }

    let rect = arguments.drawingRect.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0)
    c.move(to: CGPoint(x: rect.minX, y: rect.midY))
    c.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.midX, y: rect.minY), radius: radius)
    c.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.midY), radius: radius)
    c.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.midX, y: rect.maxY), radius: radius)
    c.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.midY), radius: radius)
    c.closePath()
    c.strokePath()
}

public func openInAppIcon(engine: TelegramEngine, appIcon: OpenInAppIcon) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    switch appIcon {
        case let .resource(resource):
            return openInAppIconData(engine: engine, appIcon: resource) |> map { data in
                return { arguments in
                    let context = DrawingContext(size: arguments.drawingSize, clear: true)

                    var sourceImage: UIImage?
                    if let data = data, let image = UIImage(data: data) {
                        sourceImage = image
                    }

                    if let sourceImage = sourceImage, let cgImage = sourceImage.cgImage {
                        context.withFlippedContext { c in
                            c.draw(cgImage, in: CGRect(origin: CGPoint(), size: arguments.drawingRect.size))
                            drawOpenInAppIconBorder(into: c, arguments: arguments)
                        }
                    } else {
                        context.withFlippedContext { c in
                            drawOpenInAppIconBorder(into: c, arguments: arguments)
                        }
                    }

                    addCorners(context, arguments: arguments)

                    return context
                }
            }
        case let .image(image):
            return .single({ arguments in
                let context = DrawingContext(size: arguments.drawingSize, clear: true)

                context.withFlippedContext { c in
                    c.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: arguments.drawingSize))
                    drawOpenInAppIconBorder(into: c, arguments: arguments)
                }

                addCorners(context, arguments: arguments)

                return context
            })
    }
}
