//
//  NSKVideoEditorHandler.swift
//  NSKCameraController
//
//  Created by User on 16.05.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import AVFoundation

class NSKVideoEditorHandler: NSObject {
    enum VideoResult {
        case cancelled
        case error(Error)
        case result(/*rawPreview*/UIImage, /*videoData*/Data)
    }
    let commitBlock: (VideoResult) -> Void
    private weak var videoEditorController: UIVideoEditorController?
    
    init(commitBlock: @escaping (VideoResult) -> Void) {
        self.commitBlock = commitBlock
        super.init()
    }
}
extension NSKVideoEditorHandler: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.titleView = UIView()
    }
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        self.videoEditorController = navigationController as? UIVideoEditorController
        
        if let rightBarButtonItem = viewController.navigationItem.rightBarButtonItem {
            rightBarButtonItem.target = self
            rightBarButtonItem.action = #selector(self.trimVideo(_:))
        }
    }
    
    @objc private func trimVideo(_ sender: UIBarButtonItem) {
        sender.isEnabled = false
        
        guard let videoEditorController = self.videoEditorController else {
            return
        }
        videoEditorController.delegate = nil
        
        guard let visibleViewController = videoEditorController.visibleViewController else {
            return
        }
        guard let movieScrubber = self.findSubview(view: visibleViewController.view, name: "UIMovieScrubber") else {
            return
        }
        
        guard let trimStart = movieScrubber.value(forKey: "_trimStartValue") as? NSNumber else {
            return
        }
        
        guard let trimEnd = movieScrubber.value(forKey: "_trimEndValue") as? NSNumber else {
            return
        }
        
        let activityIndicatorView = UIActivityIndicatorView(style: .white)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        videoEditorController.view.addSubview(activityIndicatorView)
        activityIndicatorView.centerYAnchor.constraint(equalTo: videoEditorController.view.centerYAnchor).isActive = true
        activityIndicatorView.centerXAnchor.constraint(equalTo: videoEditorController.view.centerXAnchor).isActive = true
        activityIndicatorView.startAnimating()
        
        let inputURL = URL(fileURLWithPath: videoEditorController.videoPath)
        
        let trimStartValue = trimStart.doubleValue
        let trimEndValue = trimEnd.doubleValue
        
        if trimStartValue == trimEndValue {
            self.generatePreview(time: .zero, asset: AVAsset(url: inputURL), completion: { (result) in
                do {
                    switch result {
                    case .success(let rawPreview):
                        let videoData = try Data(contentsOf: inputURL)
                        try FileManager.default.removeItem(at: inputURL)
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let sSelf = self else { return }
                            videoEditorController.dismiss(animated: true, completion: {
                                sSelf.commitBlock(.result(rawPreview, videoData))
                            })
                        }
                    case .failure(let error):
                        try FileManager.default.removeItem(at: inputURL)
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let sSelf = self else { return }
                            
                            sSelf.videoEditorController(videoEditorController, didFailWithError: error)
                        }
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        
                        sSelf.videoEditorController(videoEditorController, didFailWithError: error)
                    }
                }
            })
            
        } else {
            guard let trimSession = Self.trim(inputURL: inputURL, trimStartValue: trimStartValue, trimEndValue: trimEndValue) else {
                return
            }
            trimSession.exportAsynchronously {
                switch trimSession.status {
                case .completed:
                    self.generatePreview(time: trimSession.timeRange.start, asset: trimSession.asset,
                                         completion: { (result) in
                                            do {
                                                switch result {
                                                case .success(let rawPreview):
                                                    let videoData = try Data(contentsOf: trimSession.outputURL!)
                                                    try FileManager.default.removeItem(at: inputURL)
                                                    
                                                    DispatchQueue.main.async { [weak self] in
                                                        guard let sSelf = self else { return }
                                                        
                                                        videoEditorController.dismiss(animated: true) {
                                                            sSelf.commitBlock(.result(rawPreview, videoData))
                                                        }
                                                    }
                                                case .failure(let error):
                                                    try FileManager.default.removeItem(at: inputURL)
                                                    
                                                    DispatchQueue.main.async { [weak self] in
                                                        guard let sSelf = self else { return }
                                                        
                                                        sSelf.videoEditorController(videoEditorController, didFailWithError: error)
                                                    }
                                                }
                                            } catch {
                                                DispatchQueue.main.async { [weak self] in
                                                    guard let sSelf = self else { return }
                                                    
                                                    sSelf.videoEditorController(videoEditorController, didFailWithError: error)
                                                }
                                            }
                    })
                case .failed:
                    let error = trimSession.error ?? NSError(domain: NSKCameraControllerErrorDomain, code: -1,
                                                             userInfo: [NSLocalizedDescriptionKey: "Failed to export video."])
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        
                        sSelf.videoEditorController(videoEditorController, didFailWithError: error)
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func generatePreview(time: CMTime, asset: AVAsset, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)],
                                                      completionHandler: { (_, cgImage, _, _, error) in
                                                        if let cgImage = cgImage {
                                                            let rawPreview = UIImage(cgImage: cgImage)
                                                            completion(.success(rawPreview))
                                                        } else if let error = error {
                                                            completion(.failure(error))
                                                        }
        })
    }
    
    private func findSubview(view: UIView, name: String) -> UIView? {
        if NSStringFromClass(view.classForCoder) == name {
            return view
        } else {
            for subview in view.subviews {
                if let target = self.findSubview(view: subview, name: name) {
                    return target
                }
            }
        }
        return nil
    }
    
    private static func trim(inputURL: URL, trimStartValue: TimeInterval, trimEndValue: TimeInterval) -> AVAssetExportSession? {
        guard let session = AVAssetExportSession(asset: AVAsset(url: inputURL), presetName: AVAssetExportPresetPassthrough) else {
            return nil
        }
        
        let asset = session.asset
        let fullDuration = asset.duration
        let timescale = fullDuration.timescale
                    
        let start = CMTime(seconds: trimStartValue, preferredTimescale: timescale)
        let duration = CMTime(seconds: trimEndValue - trimStartValue, preferredTimescale: timescale)
        session.timeRange = CMTimeRangeMake(start: start, duration: duration)
        
        let mp4Url = inputURL.deletingLastPathComponent().appendingPathComponent("appercode-trim.mp4")
        do {
            try FileManager.default.removeItem(at: mp4Url)
        } catch {
            print(error)
        }
        
        session.outputURL = mp4Url
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        return session
    }
}

extension NSKVideoEditorHandler: UIVideoEditorControllerDelegate {
    public func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
        editor.delegate = nil
        editor.dismiss(animated: true) {
            self.commitBlock(.error(error))
        }
    }
    
    public func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        editor.delegate = nil
        editor.dismiss(animated: true) {
            self.commitBlock(.cancelled)
        }
    }
}
