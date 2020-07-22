//
//  Extensions.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 02.03.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import Photos

extension UIImage {
    func crop(rect: CGRect, maximumSize: CGSize?) -> UIImage {
        var rectTransform: CGAffineTransform
        switch self.imageOrientation {
        case .left:
            rectTransform = CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -size.height)
        case .right:
            rectTransform = CGAffineTransform(rotationAngle: -.pi / 2).translatedBy(x: -size.width, y: 0)
        case .down:
            rectTransform = CGAffineTransform(rotationAngle: -.pi).translatedBy(x: -size.width, y: -size.height)
        default:
            rectTransform = CGAffineTransform.identity
        }
        rectTransform = rectTransform.scaledBy(x: self.scale, y: self.scale)
        
        if let cropped = self.cgImage?.cropping(to: rect.applying(rectTransform)) {
            if let maximumSize = maximumSize, case let factor = min(maximumSize.width/rect.width, maximumSize.height/rect.height), factor < 1, let resized = cropped.resize(scale: factor) {
                return UIImage(cgImage: resized, scale: self.scale, orientation: self.imageOrientation).fixOrientation()
            } else {
                return UIImage(cgImage: cropped, scale: self.scale, orientation: self.imageOrientation).fixOrientation()
            }
        } else {
            return self.fixOrientation()
        }
    }
    
    func resize(maximumSize: CGSize?) -> UIImage {
        if let maximumSize = maximumSize {
            let imageSize = self.size
            if case let factor = min(maximumSize.width/imageSize.width, maximumSize.height/imageSize.height), factor < 1, let resized = self.cgImage?.resize(scale: factor) {
                return UIImage(cgImage: resized, scale: self.scale, orientation: self.imageOrientation).fixOrientation()
            } else {
                return self.fixOrientation()
            }
        } else {
            return self.fixOrientation()
        }
    }
    
    func fixOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}

extension CGImage {
    func resize(scale: CGFloat) -> CGImage? {
        let image = UIImage(cgImage: self)
        let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: image.size.width*scale, height: image.size.height*scale)))
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        UIGraphicsBeginImageContext(imageView.bounds.size)
        imageView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result?.cgImage
    }
}

extension Collection {
    var notEmpty: Bool {
        return self.isEmpty == false
    }
}

extension PHAsset {
    var isVideo: Bool {
        return self.mediaType == .video
    }
}


extension AVCaptureDevice.FlashMode {
    func next() -> Self {
        switch self {
        case .auto:
            return .on
        case .on:
            return .off
        case .off:
            return .auto
        @unknown default:
            return .auto
        }
    }
    
    var flashImage: UIImage? {
        switch self {
        case .auto:
            return NSKResourceProvider.flashAutoImage
        case .on:
            return NSKResourceProvider.flashOnImage
        case .off:
            return NSKResourceProvider.flashOffImage
        default:
            return nil
        }
    }
}

extension Collection {
    @inlinable func fetchValue<Value>(defaultValue: Value, block: (Element) throws -> Value?) rethrows -> Value {
        for elem in self {
            if let value = try block(elem) {
                return value
            }
        }
        return defaultValue
    }
}

extension FileManager {
    var documentDirectory: URL? {
        return self.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
