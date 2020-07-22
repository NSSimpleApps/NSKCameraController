//
//  WorkClass.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import Photos

public let NSKCameraControllerErrorDomain = "NSKCameraControllerErrorDomain"


public class NSKCameraController: UIViewController {
    public enum ResizingMode: Int {
        case free, saveAspectRatio
    }
    public enum Source {
        public enum MediaType: Int {
            case image, video, imageAndVideo
        }
        case camera(MediaType), photoLibrary(MediaType)
    }
    public enum NumberOfAttachments: Equatable {
        case single // одно фото
        case multiply(Int, String) // Int - максимальное число вложений, String - заголовок кнопки "Выбрать"
    }
    public enum ImagePickerResult {
        public enum Media {
            case image(UIImage)
            case video(UIImage, Data) // превью, данные видео
            public var image: UIImage {
                switch self {
                case .image(let image):
                    return image
                case .video(let image, _):
                    return image
                }
            }
        }
        case result(Media)
        case results([Media])
        case cancelled
        case error(Error)
    }
    public enum ConfirmationResult {
        case image(UIImage)
        case cancelled
    }
    public struct Limits: Equatable {
        public let minSize: CGSize
        public let maxSize: CGSize? // nil - нет ограничений
        
        public init(minSize: CGSize, maxSize: CGSize?) {
            let minWidth0 = abs(minSize.width)
            let minHeight0 = abs(minSize.height)
            
            if let maxSize = maxSize {
                let maxWidth0 = abs(maxSize.width)
                let maxHeight0 = abs(maxSize.height)
                
                let minWidth = min(maxWidth0, minWidth0)
                let maxWidth = max(maxWidth0, minWidth0)
                let minHeight = min(maxHeight0, minHeight0)
                let maxHeight = max(maxHeight0, minHeight0)
                
                self.minSize = CGSize(width: minWidth, height: minHeight)
                self.maxSize = CGSize(width: maxWidth, height: maxHeight)
            } else {
                self.minSize = CGSize(width: minWidth0, height: minHeight0)
                self.maxSize = nil
            }
        }
        public init() {
            self.minSize = CGSize(width: 60, height: 60)
            self.maxSize = nil
        }
    }
    
    public enum Options: Hashable {
        case isCroppingEnabled(Bool)
        case isResizingEnabled(Bool)
        case isConfirmationRequired(Bool)
        
        case limits(Limits)
        
        case resizingMode(ResizingMode)
        case numberOfAttachments(NumberOfAttachments)
        
        case accentColor(UIColor?)
        
        case videoMaximumDuration(TimeInterval)
        
        case tipString(String)
        
        case maxNumberOfVideos(Int)
        
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .isCroppingEnabled:
                hasher.combine("isCroppingEnabled")
            case .isResizingEnabled:
                hasher.combine("isResizingEnabled")
            case .isConfirmationRequired:
                hasher.combine("isConfirmationRequired")
            case .limits:
                hasher.combine("limits")
            case .resizingMode:
                hasher.combine("resizingMode")
            case .numberOfAttachments:
                hasher.combine("numberOfAttachments")
            case .accentColor:
                hasher.combine("accentColor")
            case .videoMaximumDuration:
                hasher.combine("videoMaximumDuration")
            case .tipString:
                hasher.combine("tipString")
            case .maxNumberOfVideos:
                hasher.combine("numberOfVideos")
            }
        }
    }
    public let options: Set<Options>
    public let source: Source
    public let commitBlock: (NSKCameraController, ImagePickerResult) -> Void
    
    private var videoEditorHandler: NSKVideoEditorHandler?
    
    public init(source: Source, options: Set<Options>, commitBlock: @escaping (NSKCameraController, ImagePickerResult) -> Void) {
        self.source = source
        self.options = options
        self.commitBlock = commitBlock
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        
        switch self.source {
        case .photoLibrary(let mediaType):
            let (maximumNumberOfAttachments, selectButtonTitle) = self.options.fetchValue(defaultValue: (1, nil),
                                                                                     block: { (opt) -> (Int, String?)? in
                                                                                        switch opt {
                                                                                        case .numberOfAttachments(let numberOfAttachments):
                                                                                            switch numberOfAttachments {
                                                                                            case .single:
                                                                                                return (1, nil)
                                                                                            case .multiply(let value, let title):
                                                                                                return (value, title)
                                                                                            }
                                                                                        default:
                                                                                            return nil
                                                                                        }
            })
            
            let accentColor = self.options.fetchValue(defaultValue: nil, block: { (opt) -> UIColor? in
                switch opt {
                case .accentColor(let color):
                    return color
                default:
                    return nil
                }
            })
            let maxNumberOfVideos = self.options.fetchValue(defaultValue: 5, block: { (opt) -> Int? in
                switch opt {
                case .maxNumberOfVideos(let maxNumberOfVideos):
                    return maxNumberOfVideos
                default:
                    return nil
                }
            })
            
            let photoLibraryController = NSKPhotoLibraryController(mediaType: mediaType,
                                                                   maximumNumberOfAttachments: maximumNumberOfAttachments, selectButtonTitle: selectButtonTitle,
                                                                   accentColor: accentColor, maxNumberOfVideos: maxNumberOfVideos,
                                                                   commitBlock: { conroller, result in
                                                                    guard let nc = conroller.navigationController else { return }
                                                                    guard let imagePickerController = nc.parent as? Self else { return }
                                                                    
                                                                    nc.view.removeFromSuperview()
                                                                    nc.removeFromParent()
                                                                    
                                                                    let activityIndicatorView = UIActivityIndicatorView(style: .white)
                                                                    activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
                                                                    imagePickerController.view.addSubview(activityIndicatorView)
                                                                    activityIndicatorView.centerYAnchor.constraint(equalTo: imagePickerController.view.centerYAnchor).isActive = true
                                                                    activityIndicatorView.centerXAnchor.constraint(equalTo: imagePickerController.view.centerXAnchor).isActive = true
                                                                    activityIndicatorView.startAnimating()
                                                                    
                                                                    imagePickerController.handle(mediaResult: result)
            })
            let navigationController = UINavigationController(rootViewController: photoLibraryController)
            navigationController.navigationBar.barTintColor = .black
            navigationController.navigationBar.barStyle = .black
            
            let photoLibraryView = navigationController.view!
            self.view.addSubview(photoLibraryView)
            photoLibraryView.translatesAutoresizingMaskIntoConstraints = false
            
            photoLibraryView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
            photoLibraryView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
            photoLibraryView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
            photoLibraryView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
            
            self.addChild(navigationController)
            navigationController.didMove(toParent: self)
            
        case .camera(let mediaType):
            let captureType: NSKVideoCaptureController.CaptureType
            switch mediaType {
            case .image, .imageAndVideo:
                captureType = .image
            case .video:
                let tip = self.options.fetchValue(defaultValue: "?") { (opt) -> String? in
                    switch opt {
                    case .tipString(let tipString):
                        return tipString
                    default:
                        return nil
                    }
                }
                captureType = .video(tip)
            }
            let videoCaptureController = NSKVideoCaptureController(captureType: captureType, isCroppingEnabled: self.isCroppingEnabled,
                commitBlock: { (captureController, result) in
                guard let cameraController = captureController.parent as? Self else {
                    return
                }
                switch result {
                case .cancelled:
                    captureController.view.removeFromSuperview()
                    captureController.removeFromParent()
                    cameraController.commitBlock(cameraController, .cancelled)
                case .error(let error):
                    cameraController.commitBlock(cameraController, .error(error))
                case .image(let image):
                    let maximumSize = cameraController.maximumSize
                    let minimumSize = cameraController.minimumSize
                    if cameraController.isConfirmationRequired {
                        captureController.view.removeFromSuperview()
                        captureController.removeFromParent()
                        cameraController.initConfirmationDialog(image: image, minimumSize: minimumSize, maximumSize: maximumSize,
                                                                commitBlock: { (imagePickerController, confirmationResult) in
                                                                    switch confirmationResult {
                                                                    case .cancelled:
                                                                        imagePickerController.commitBlock(imagePickerController, .cancelled)
                                                                    case .image(let image):
                                                                        imagePickerController.commitBlock(imagePickerController, .result(.image(image)))
                                                                    }
                        })
                    } else {
                        let resizedImage = image.resize(maximumSize: maximumSize)
                        cameraController.commitBlock(cameraController, .result(.image(resizedImage)))
                    }
                case .video(let capture):
                    let url = capture.url
                    
                    captureController.view.removeFromSuperview()
                    captureController.removeFromParent()
                    
                    cameraController.initVideoEditor(path: url.path, commitBlock: { (cameraController, videoResult) in
                        switch videoResult {
                        case .cancelled:
                            cameraController.commitBlock(cameraController, .cancelled)
                        case .error(let error):
                            cameraController.commitBlock(cameraController, .error(error))
                        case .result(let rawPreview, let videoData):
                            let maximumSize = cameraController.maximumSize
                            let minimumSize = cameraController.minimumSize
                            
                            if cameraController.isConfirmationRequired {
                                cameraController.initConfirmationDialog(image: rawPreview, minimumSize: minimumSize, maximumSize: maximumSize,
                                                                        commitBlock: { (cameraController, confirmationResult) in
                                                                            switch confirmationResult {
                                                                            case .cancelled:
                                                                                cameraController.commitBlock(cameraController, .cancelled)
                                                                            case .image(let preview):
                                                                                cameraController.commitBlock(cameraController, .result(.video(preview, videoData)))
                                                                            }
                                })
                            } else {
                                cameraController.commitBlock(cameraController, .result(.video(rawPreview.resize(maximumSize: maximumSize), videoData)))
                            }
                        }
                    })
                }
            })
            let videoCapture = videoCaptureController.view!
            self.view.addSubview(videoCapture)
            videoCapture.translatesAutoresizingMaskIntoConstraints = false
            
            videoCapture.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
            videoCapture.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
            videoCapture.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
            videoCapture.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
            
            self.addChild(videoCaptureController)
            videoCaptureController.didMove(toParent: self)
        }
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func handle(mediaResult: NSKPhotoLibraryController.MediaResult) {
        switch mediaResult {
        case .cancelled:
            self.commitBlock(self, .cancelled)
        default:
            let isConfirmationRequired = self.isConfirmationRequired
            let maximumSize = self.maximumSize
            let minimumSize = self.minimumSize
            
            switch mediaResult {
            case .asset(let asset):
                if asset.isVideo {
                    NSKImageFetcher.fetchVideoUrl(asset: asset, shouldCheckEditing: true,
                                                  completion: { [weak self] (result) in
                                                    guard let sSelf = self else { return }
                                                    
                                                    switch result {
                                                    case .success(let url):
                                                        sSelf.initVideoEditor(path: url.path, commitBlock: { (cameraController, videoResult) in
                                                            switch videoResult {
                                                            case .cancelled:
                                                                cameraController.commitBlock(cameraController, .cancelled)
                                                            case .error(let error):
                                                                cameraController.commitBlock(cameraController, .error(error))
                                                            case .result(let rawPreview, let videoData):
                                                                if isConfirmationRequired {
                                                                    cameraController.initConfirmationDialog(image: rawPreview, minimumSize: minimumSize, maximumSize: maximumSize,
                                                                                                            commitBlock: { (cameraController, confirmationResult) in
                                                                                                                switch confirmationResult {
                                                                                                                case .cancelled:
                                                                                                                    cameraController.commitBlock(cameraController, .cancelled)
                                                                                                                case .image(let resizedImage):
                                                                                                                    cameraController.commitBlock(cameraController, .result(.video(resizedImage, videoData)))
                                                                                                                }
                                                                    })
                                                                } else {
                                                                    let preview = rawPreview.resize(maximumSize: maximumSize)
                                                                    cameraController.commitBlock(cameraController, .result(.video(preview, videoData)))
                                                                }
                                                            }
                                                        })
                                                    case .failure(let error):
                                                        sSelf.commitBlock(sSelf, .error(error))
                                                    }
                    })
                } else {
                    NSKImageFetcher.fetchImage(maximumSize: isConfirmationRequired ? nil : maximumSize, asset: asset,
                                               completion: { [weak self] (result) in
                                                guard let sSelf = self else { return }
                                                
                                                switch result {
                                                case .success(let image):
                                                    if isConfirmationRequired {
                                                        sSelf.initConfirmationDialog(image: image, minimumSize: minimumSize, maximumSize: maximumSize,
                                                                                     commitBlock: { (cameraController, confirmationResult) in
                                                                                        switch confirmationResult {
                                                                                        case .cancelled:
                                                                                            cameraController.commitBlock(cameraController, .cancelled)
                                                                                        case .image(let resized):
                                                                                            cameraController.commitBlock(cameraController, .result(.image(resized)))
                                                                                        }
                                                        })
                                                    } else {
                                                        sSelf.commitBlock(sSelf, .result(.image(image)))
                                                    }
                                                case .failure(let error):
                                                    sSelf.commitBlock(sSelf, .error(error))
                                                }
                    })
                }
            case .assets(let assets):
                self.handleConfirmation(with: assets, initialResults: [], isConfirmationRequired: isConfirmationRequired, maximumSize: maximumSize, minimumSize: minimumSize)
            default:
                return
            }
        }
    }
    
    private func initVideoEditor(path: String, commitBlock: @escaping (NSKCameraController, NSKVideoEditorHandler.VideoResult) -> Void) {
        let videoMaximumDuration = self.options.fetchValue(defaultValue: 20) { (opt) -> TimeInterval? in
            switch opt {
            case .videoMaximumDuration(let value):
                return value
            default:
                return nil
            }
        }
        
        let videoEditorHandler = NSKVideoEditorHandler(commitBlock: { [weak self] (result) in
            guard let sSelf = self else { return }
            
            commitBlock(sSelf, result)
        })
        self.videoEditorHandler = videoEditorHandler
        
        let videoEditorController = UIVideoEditorController()
        videoEditorController.videoMaximumDuration = videoMaximumDuration
        videoEditorController.modalPresentationStyle = .fullScreen
        videoEditorController.videoPath = path
        videoEditorController.delegate = videoEditorHandler
        self.present(videoEditorController, animated: true, completion: nil)
    }
    
    private func _handleConfirmation(with asset: PHAsset, isConfirmationRequired: Bool, maximumSize: CGSize?, minimumSize: CGSize,
                                     completion: @escaping (NSKCameraController, ImagePickerResult.Media) -> Void) {
        if asset.isVideo {
            NSKImageFetcher.fetchVideoUrl(asset: asset, shouldCheckEditing: true,
                                          completion: { [weak self] (result) in
                                            guard let sSelf = self else { return }
                                            
                                            switch result {
                                            case .success(let url):
                                                sSelf.initVideoEditor(path: url.path, commitBlock: { (cameraController, videoResult) in
                                                    switch videoResult {
                                                    case .cancelled:
                                                        cameraController.commitBlock(cameraController, .cancelled)
                                                    case .error(let error):
                                                        cameraController.commitBlock(cameraController, .error(error))
                                                    case .result(let rawPreview, let videoData):
                                                        if isConfirmationRequired {
                                                            cameraController.initConfirmationDialog(image: rawPreview, minimumSize: minimumSize, maximumSize: maximumSize,
                                                                                                    commitBlock: { (cameraController, confirmationResult) in
                                                                                                        switch confirmationResult {
                                                                                                        case .cancelled:
                                                                                                            cameraController.commitBlock(cameraController, .cancelled)
                                                                                                        case .image(let resizedPreview):
                                                                                                            completion(cameraController, .video(resizedPreview, videoData))
                                                                                                        }
                                                            })
                                                        } else {
                                                            completion(cameraController, .video(rawPreview.resize(maximumSize: maximumSize), videoData))
                                                        }
                                                    }
                                                })
                                            case .failure(let error):
                                                sSelf.commitBlock(sSelf, .error(error))
                                            }
            })
        } else {
            NSKImageFetcher.fetchImage(maximumSize: isConfirmationRequired ? nil : maximumSize, asset: asset, completion: { [weak self] (result) in
                guard let sSelf = self else { return }
                
                switch result {
                case .success(let preview):
                    if isConfirmationRequired {
                        sSelf.initConfirmationDialog(image: preview, minimumSize: minimumSize, maximumSize: maximumSize,
                                                     commitBlock: { (cameraController, confirmationResult) in
                                                        switch confirmationResult {
                                                        case .cancelled:
                                                            cameraController.commitBlock(cameraController, .cancelled)
                                                        case .image(let resizedImage):
                                                            completion(cameraController, .image(resizedImage))
                                                        }
                        })
                    } else {
                        completion(sSelf, .image(preview))
                    }
                case .failure(let error):
                    sSelf.commitBlock(sSelf, .error(error))
                }
            })
        }
    }
    
    private func handleConfirmation(with assets: [PHAsset], initialResults: [ImagePickerResult.Media], isConfirmationRequired: Bool, maximumSize: CGSize?, minimumSize: CGSize) {
        if let asset = assets.first {
            self._handleConfirmation(with: asset, isConfirmationRequired: isConfirmationRequired, maximumSize: maximumSize, minimumSize: minimumSize,
                                     completion: { (cameraController, media) in
                                        cameraController.handleConfirmation(with: Array(assets.dropFirst()), initialResults: initialResults + [media],
                                                                            isConfirmationRequired: isConfirmationRequired,
                                                                            maximumSize: maximumSize, minimumSize: minimumSize)
            })
        } else {
            self.commitBlock(self, .results(initialResults))
        }
    }
    
    private func initConfirmationDialog(image: UIImage, minimumSize: CGSize, maximumSize: CGSize?, commitBlock: @escaping (NSKCameraController, ConfirmationResult) -> Void) {
        let resizingModeValue = self.options.fetchValue(defaultValue: .free, block: { (opt) -> ResizingMode? in
            switch opt {
            case .resizingMode(let resizingMode):
                return resizingMode
            default:
                return nil
            }
        })
        
        let isResizingEnabled = self.options.fetchValue(defaultValue: false,
                                                        block: { (opt) -> Bool? in
                                                            switch opt {
                                                            case .isResizingEnabled(let value):
                                                                return value
                                                            default:
                                                                return nil
                                                            }
        })
        
        let сonfirmationController = NSKConfirmationController(image: image, isCroppingEnabled: self.isCroppingEnabled, isResizingEnabled: isResizingEnabled,
                                                               resizingMode: resizingModeValue,
                                                               minSize: minimumSize, maxSize: maximumSize,
                                                               commitBlock: { сonfirmationController, image in
                                                                guard let cameraController = сonfirmationController.parent as? Self else {
                                                                    return
                                                                }
                                                                сonfirmationController.view.removeFromSuperview()
                                                                сonfirmationController.removeFromParent()
                                                                
                                                                if let image = image {
                                                                    commitBlock(cameraController, .image(image))
                                                                } else {
                                                                    commitBlock(cameraController, .cancelled)
                                                                }
        })
        
        let сonfirmationView = сonfirmationController.view!
        self.view.addSubview(сonfirmationView)
        сonfirmationView.translatesAutoresizingMaskIntoConstraints = false
        
        сonfirmationView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        сonfirmationView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        сonfirmationView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        сonfirmationView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        
        self.addChild(сonfirmationController)
        сonfirmationController.didMove(toParent: self)
    }
    
    private func initConfirmationDialog(initialImages: [UIImage], resultedImages: [UIImage],
                                        minimumSize: CGSize, maximumSize: CGSize?,
                                        completion: @escaping (NSKCameraController, [UIImage]?) -> Void) {
        if let initialImage = initialImages.first {
            self.initConfirmationDialog(image: initialImage, minimumSize: minimumSize, maximumSize: maximumSize, commitBlock: { (imagePickerController, result) in
                switch result {
                case .image(let image):
                    imagePickerController.initConfirmationDialog(initialImages: Array(initialImages.dropFirst()), resultedImages: resultedImages + [image],
                                                                 minimumSize: minimumSize, maximumSize: maximumSize, completion: completion)
                case .cancelled:
                    completion(imagePickerController, nil)
                }
            })
        } else {
            completion(self, resultedImages)
        }
    }
    
    public var isConfirmationRequired: Bool {
        return self.options.fetchValue(defaultValue: false,
                                       block: { (opt) -> Bool? in
                                        switch opt {
                                        case .isConfirmationRequired(let isRequired):
                                            return isRequired
                                        default:
                                            return nil
                                        }
        })
    }
    
    public var minimumSize: CGSize {
        return self.options.fetchValue(defaultValue: .zero, block: { (opt) -> CGSize? in
            switch opt {
            case .limits(let limits):
                return limits.minSize
            default:
                return nil
            }
        })
    }
    public var maximumSize: CGSize? {
        return self.options.fetchValue(defaultValue: nil, block: { (opt) -> CGSize? in
            switch opt {
            case .limits(let limits):
                return limits.maxSize
            default:
                return nil
            }
        })
    }
    
    public var isCroppingEnabled: Bool {
        return self.options.fetchValue(defaultValue: false, block: { (opt) -> Bool? in
            switch opt {
            case .isCroppingEnabled(let value):
                return value
            default:
                return nil
            }
        })
    }
}
