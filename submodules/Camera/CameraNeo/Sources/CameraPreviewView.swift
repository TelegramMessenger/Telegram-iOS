import Foundation
import UIKit
import AVFoundation
import SwiftSignalKit
import Camera

private extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeRight:
            return .landscapeRight
        case .landscapeLeft:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
}

final class CameraPreviewView: UIView, CameraSimplePreviewView {
    private let placeholderView = UIImageView()

    init(frame: CGRect, main: Bool, roundVideo: Bool) {
        super.init(frame: frame)

        if roundVideo {
            self.videoPreviewLayer.videoGravity = .resizeAspectFill
            self.placeholderView.contentMode = .scaleAspectFill
        } else {
            self.videoPreviewLayer.videoGravity = main ? .resizeAspectFill : .resizeAspect
            self.placeholderView.contentMode = main ? .scaleAspectFill : .scaleAspectFit
        }
        self.placeholderView.backgroundColor = .black
        self.addSubview(self.placeholderView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = self.layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("Unexpected preview layer type")
        }
        return layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.placeholderView.frame = self.bounds.insetBy(dx: -1.0, dy: -1.0)
        self.updateOrientation()
    }

    func updateOrientation() {
        guard self.videoPreviewLayer.connection?.isVideoOrientationSupported == true else {
            return
        }
        let interfaceOrientation = self.window?.windowScene?.interfaceOrientation ?? .portrait
        self.videoPreviewLayer.connection?.videoOrientation = interfaceOrientation.videoOrientation
        self.videoPreviewLayer.removeAllAnimations()
    }

    func setSession(_ session: AVCaptureSession, automaticallyConnect: Bool) {
        if automaticallyConnect {
            self.videoPreviewLayer.session = session
        } else {
            self.videoPreviewLayer.setSessionWithNoConnection(session)
        }
    }

    func invalidate() {
        self.videoPreviewLayer.session = nil
    }

    var captureOrientation: AVCaptureVideoOrientation {
        return self.videoPreviewLayer.connection?.videoOrientation ?? .portrait
    }

    var isEnabled: Bool = true {
        didSet {
            self.videoPreviewLayer.connection?.isEnabled = self.isEnabled
        }
    }

    @available(iOS 13.0, *)
    var isPreviewing: Signal<Bool, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            subscriber.putNext(self.videoPreviewLayer.isPreviewing)
            let observer = self.videoPreviewLayer.observe(\.isPreviewing, options: [.new]) { layer, _ in
                subscriber.putNext(layer.isPreviewing)
            }
            return ActionDisposable {
                observer.invalidate()
            }
        }
        |> distinctUntilChanged
    }

    func removePlaceholder(delay: Double) {
        UIView.animate(withDuration: 0.3, delay: delay) {
            self.placeholderView.alpha = 0.0
        }
    }

    func resetPlaceholder(front: Bool) {
        let fileName = front ? "frontCameraImage.jpg" : "backCameraImage.jpg"
        let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: fileUrl), let image = UIImage(data: data) {
            self.placeholderView.image = image
        } else {
            let imageName = front ? "Camera/SelfiePlaceholder" : "Camera/Placeholder"
            self.placeholderView.image = UIImage(named: imageName)
        }
        self.placeholderView.alpha = 1.0
    }

    func cameraPoint(for location: CGPoint) -> CGPoint {
        return self.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
    }
}
