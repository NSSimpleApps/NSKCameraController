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
    
    private static func imageOptions(isSynchronous: Bool) -> PHImageRequestOptions {
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
    
    static func fetchImage(maximumSize: CGSize?, asset: PHAsset, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let options = self.imageOptions(isSynchronous: false)
        let targetSize = self.targetSize(maximumSize: maximumSize, asset: asset)
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            if let image = image {
                completion(.success(image))
            } else {
                let error = NSError(domain: NSKCameraControllerErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't pick an image."])
                completion(.failure(error))
            }
        }
    }
    
    /// перемещает видео в пользовательскую директорию для редактирования
    static func fetchVideoUrl(asset: PHAsset, shouldCheckEditing: Bool, completion: @escaping (Result<URL, Error>) -> Void) {
        self._fetchVideoUrl(asset: asset, shouldCheckEditing: shouldCheckEditing, completion: { (result) in
            DispatchQueue.main.async {
                completion(result)
            }
        })
    }
    
    private static func _fetchVideoUrl(asset: PHAsset, shouldCheckEditing: Bool, completion: @escaping (Result<URL, Error>) -> Void) {
        let videoOptions = PHVideoRequestOptions()
        videoOptions.isNetworkAccessAllowed = true
        videoOptions.deliveryMode = .mediumQualityFormat
        
        PHImageManager.default().requestExportSession(forVideo: asset, options: videoOptions, exportPreset: AVAssetExportPresetPassthrough,
                                                      resultHandler: { (session, _) in
                                                        if let session = session, let documentDirectory = FileManager.default.documentDirectory {
                                                            let outputURL = documentDirectory.appendingPathComponent("appercode-video\(Date()).mp4")
                                                            do {
                                                                try FileManager.default.removeItem(at: outputURL)
                                                            } catch {
                                                                print(error)
                                                            }
                                                            session.outputURL = outputURL
                                                            session.outputFileType = .mp4
                                                            session.shouldOptimizeForNetworkUse = true
                                                            session.exportAsynchronously {
                                                                switch session.status {
                                                                case .completed:
                                                                    if shouldCheckEditing {
                                                                        if UIVideoEditorController.canEditVideo(atPath: outputURL.path) {
                                                                            completion(.success(outputURL))
                                                                        } else {
                                                                            let error = NSError(domain: NSKCameraControllerErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't edit video."])
                                                                            completion(.failure(error))
                                                                        }
                                                                    } else {
                                                                        completion(.success(outputURL))
                                                                    }
                                                                case .failed:
                                                                    let commonError: Error
                                                                    if let error = session.error {
                                                                        commonError = error
                                                                    } else {
                                                                        commonError = NSError(domain: NSKCameraControllerErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't export video."])
                                                                    }
                                                                    completion(.failure(commonError))
                                                                default:
                                                                    break
                                                                }
                                                            }
                                                        } else {
                                                            let error = NSError(domain: NSKCameraControllerErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't request video."])
                                                            completion(.failure(error))
                                                        }
        })
    }
}

