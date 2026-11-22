import SwiftUI
import UIKit

/// Full-screen sheet content for viewing a downloaded photo. Aspect-fits the image into
/// the screen with a black background. Standard sheet dismiss (swipe-down / Digital Crown).
///
/// Assumes `photo.localPath != nil` (the tap that presents this sheet is gated on
/// download completion).
struct PhotoViewerView: View {
    let photo: PhotoVisual

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let path = photo.localPath, let img = UIImage(contentsOfFile: path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else if let data = photo.minithumbnail, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .blur(radius: 4)
            } else {
                Color.gray.opacity(0.3)
            }
        }
    }
}
