import SwiftUI
import PhotosUI
import UIKit

/// 系统相册选图，选完回调压缩后的 JPEG。头像与歌单封面共用。
struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(photoLibrary: .shared())
        cfg.filter = .images
        cfg.selectionLimit = 1
        let vc = PHPickerViewController(configuration: cfg)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first?.itemProvider,
                  item.canLoadObject(ofClass: UIImage.self) else { return }

            item.loadObject(ofClass: UIImage.self) { obj, _ in
                guard let img = obj as? UIImage,
                      let data = PhotoPicker.jpeg(img) else { return }
                DispatchQueue.main.async { parent.onPick(data) }
            }
        }
    }

    /// 压到 512 长边、0.82 质量
    static func jpeg(_ img: UIImage, maxSide: CGFloat = 512, quality: CGFloat = 0.82) -> Data? {
        let w = img.size.width, h = img.size.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, maxSide / max(w, h))
        let size = CGSize(width: w * scale, height: h * scale)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        return out.jpegData(compressionQuality: quality)
    }
}
