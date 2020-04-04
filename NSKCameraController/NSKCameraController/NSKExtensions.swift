//
//  Extensions.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 02.03.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit

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
    
    func resize(maximumSize: CGSize) -> UIImage {
        let imageSize = self.size
        if case let factor = min(maximumSize.width/imageSize.width, maximumSize.height/imageSize.height), factor < 1, let resized = self.cgImage?.resize(scale: factor) {
            return UIImage(cgImage: resized, scale: self.scale, orientation: self.imageOrientation).fixOrientation()
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
