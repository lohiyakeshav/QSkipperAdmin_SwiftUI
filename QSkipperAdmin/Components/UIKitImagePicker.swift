import SwiftUI
import UIKit
import PhotosUI

struct UIKitImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: UIKitImagePicker
        
        init(_ parent: UIKitImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker
            parent.presentationMode.wrappedValue.dismiss()
            
            // Get the selected image
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        guard let self = self, let image = image as? UIImage else { return }
                        
                        // Process the image (resize if needed)
                        let processedImage = self.processImage(image)
                        self.parent.selectedImage = processedImage
                    }
                }
            }
        }
        
        // Process and resize image if needed
        private func processImage(_ image: UIImage) -> UIImage {
            // If the image is too large, resize it to a reasonable size
            let maxSize: CGFloat = 1200
            
            if max(image.size.width, image.size.height) > maxSize {
                let scale = maxSize / max(image.size.width, image.size.height)
                let newWidth = image.size.width * scale
                let newHeight = image.size.height * scale
                let newSize = CGSize(width: newWidth, height: newHeight)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
                
                return resizedImage
            }
            
            return image
        }
    }
} 