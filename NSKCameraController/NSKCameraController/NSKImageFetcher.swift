//
//  NSKImageFetcher.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import Photos


class NSKImageFetcher {
    private init() {}
    
    private static func fit(size: CGSize, maximumSize: CGSize) -> CGSize {
        if case let factor = min(maximumSize.width/size.width, maximumSize.height/size.height), factor < 1 {
            return CGSize(width: factor * size.width, height: factor * size.height)
            
        } else {
            return size
        }
    }
    
    private static func options(isSynchronous: Bool) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        options.normalizedCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        options.isSynchronous = isSynchronous
        
        return options
    }
    
    private static func targetSize(maximumSize: CGSize?, asset: PHAsset) -> CGSize {
        let assetSize = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
        let targetSize: CGSize
        
        if let maximumSize = maximumSize {
            targetSize = self.fit(size: assetSize, maximumSize: maximumSize)
        } else {
            targetSize = assetSize
        }
        return targetSize
    }
    
    static func fetchImage(maximumSize: CGSize?, asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = self.options(isSynchronous: false)
        let targetSize = self.targetSize(maximumSize: maximumSize, asset: asset)
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }
    static func fetchImages(maximumSize: CGSize?, assets: [PHAsset], completion: @escaping ([UIImage]) -> Void) {
        DispatchQueue.global().async {
            let options = self.options(isSynchronous: true)
            var result: [UIImage] = []
            
            for asset in assets {
                let targetSize = self.targetSize(maximumSize: maximumSize, asset: asset)
                
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                    if let image = image {
                        result.append(image)
                    }
                }
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}

