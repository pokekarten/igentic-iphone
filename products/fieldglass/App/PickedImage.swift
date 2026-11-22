import CoreTransferable
import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

struct PickedImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            guard let size = try received.file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 24 * 1024 * 1024,
                  let source = CGImageSourceCreateWithURL(received.file as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400
                  ] as CFDictionary),
                  let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.94) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return PickedImage(data: data)
        }
    }
}
