import SwiftUI
import UIKit

// MARK: - CameraCapture

@MainActor
@Observable
final class CameraCapture {

    // MARK: - State

    private(set) var capturedImage: UIImage?
    private(set) var error: CameraCaptureError?
    var isPresented = false

    // MARK: - Configuration

    var sourceType: UIImagePickerController.SourceType = .camera

    static let maxDimension: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.8

    // MARK: - Actions

    func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            error = .cameraUnavailable
            return
        }
        sourceType = .camera
        error = nil
        isPresented = true
    }

    func presentPhotoLibrary() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            error = .photoLibraryUnavailable
            return
        }
        sourceType = .photoLibrary
        error = nil
        isPresented = true
    }

    func reset() {
        capturedImage = nil
        error = nil
    }

    // MARK: - Image Processing

    func processImage(_ image: UIImage) {
        capturedImage = Self.resizeIfNeeded(image, maxDimension: Self.maxDimension)
    }

    func makeImageContent() -> ImageContent? {
        guard let image = capturedImage else { return nil }
        guard let data = image.jpegData(compressionQuality: Self.jpegQuality) else { return nil }
        return ImageContent(
            data: data,
            mimeType: "image/jpeg",
            width: Int(image.size.width),
            height: Int(image.size.height)
        )
    }

    func compressedJPEGData() -> Data? {
        capturedImage?.jpegData(compressionQuality: Self.jpegQuality)
    }

    // MARK: - Resize

    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)

        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - ImagePickerRepresentable

struct ImagePickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: @MainActor (UIImage) -> Void
    let onCancelled: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancelled: onCancelled)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: @MainActor (UIImage) -> Void
        let onCancelled: @MainActor () -> Void

        init(
            onImagePicked: @escaping @MainActor (UIImage) -> Void,
            onCancelled: @escaping @MainActor () -> Void
        ) {
            self.onImagePicked = onImagePicked
            self.onCancelled = onCancelled
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                Task { @MainActor in
                    onImagePicked(image)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            Task { @MainActor in
                onCancelled()
            }
        }
    }
}

// MARK: - CameraCaptureError

enum CameraCaptureError: LocalizedError, Hashable {
    case cameraUnavailable
    case photoLibraryUnavailable
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "Camera is not available on this device."
        case .photoLibraryUnavailable:
            "Photo library is not available."
        case .compressionFailed:
            "Failed to compress image."
        }
    }
}
