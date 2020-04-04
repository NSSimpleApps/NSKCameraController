//
//  WorkClass.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit

public let NSKCameraControllerErrorDomain = "NSKCameraControllerErrorDomain"

public class NSKCameraController: UIViewController {
    public enum ResizingMode: Int {
        case free, saveAspectRatio
    }
    public enum Source: Int {
        case camera, photoLibrary
    }
    public enum NumberOfPhotos: Equatable {
        case single // одно фото
        case multiply(Int, String) // Int - максимальное число фото, String - заголовок кнопки "Выбрать"
    }
    public enum ImagePickerResult {
        case image(UIImage)
        case images([UIImage])
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
        case numberOfPhotos(NumberOfPhotos)
        
        case accentColor(UIColor?)
        
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
            case .numberOfPhotos:
                hasher.combine("numberOfPhotos")
            case .accentColor:
                hasher.combine("accentColor")
            }
        }
    }
    public let options: Set<Options>
    public let source: Source
    public let commitBlock: (NSKCameraController, ImagePickerResult) -> Void
    
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
        case .photoLibrary:
            let maximumNumberOfPhotos: Int
            let selectButtonTitle: String?
            if let option = self.options.first(where: { (opt) -> Bool in
                switch opt {
                case .numberOfPhotos:
                    return true
                default:
                    return false
                }
            }) {
                switch option {
                case .numberOfPhotos(let numberOfPhotos):
                    switch numberOfPhotos {
                    case .single:
                        maximumNumberOfPhotos = 1
                        selectButtonTitle = nil
                    case .multiply(let value, let title):
                        maximumNumberOfPhotos = value
                        selectButtonTitle = title
                    }
                default:
                    maximumNumberOfPhotos = 1
                    selectButtonTitle = nil
                }
            } else {
                maximumNumberOfPhotos = 1
                selectButtonTitle = nil
            }
            
            let accentColor: UIColor?
            if let option = self.options.first(where: { (opt) -> Bool in
                switch opt {
                case .accentColor:
                    return true
                default:
                    return false
                }
            }) {
                switch option {
                case .accentColor(let color):
                    accentColor = color
                default:
                    accentColor = nil
                }
            } else {
                accentColor = nil
            }
            
            let photoLibraryController = NSKPhotoLibraryController(maximumNumberOfPhotos: maximumNumberOfPhotos,
                                                                   selectButtonTitle: selectButtonTitle,
                                                                   accentColor: accentColor,
                                                                   commitBlock: { conroller, result in
                                                                    guard let nc = conroller.navigationController else { return }
                                                                    guard let imagePickerController = nc.parent as? NSKCameraController else { return }
                                                                    
                                                                    nc.view.removeFromSuperview()
                                                                    nc.removeFromParent()
                                                                    
                                                                    switch result {
                                                                    case .cancelled:
                                                                        imagePickerController.commitBlock(imagePickerController, .cancelled)
                                                                    default:
                                                                        let isConfirmationRequired = imagePickerController.isConfirmationRequired
                                                                        let maximumSize = imagePickerController.maximumSize
                                                                        let minimumSize = imagePickerController.minimumSize
                                                                        switch result {
                                                                        case .asset(let asset):
                                                                            NSKImageFetcher.fetchImage(maximumSize: nil, asset: asset,
                                                                                                       completion: { [weak imagePickerController] (image) in
                                                                                                        guard let imagePickerController = imagePickerController else { return }
                                                                                                        if let image = image {
                                                                                                            if isConfirmationRequired {
                                                                                                                imagePickerController.initConfirmationDialog(image: image, minimumSize: minimumSize, maximumSize: maximumSize, commitBlock: { imagePickerController, imagePickerResult in
                                                                                                                    switch imagePickerResult {
                                                                                                                    case .image(let image):
                                                                                                                        imagePickerController.commitBlock(imagePickerController, .image(image))
                                                                                                                    case .cancelled:
                                                                                                                        imagePickerController.commitBlock(imagePickerController, .cancelled)
                                                                                                                    }
                                                                                                                })
                                                                                                            } else {
                                                                                                                if let maximumSize = maximumSize {
                                                                                                                    let resizedImage = image.resize(maximumSize: maximumSize)
                                                                                                                    imagePickerController.commitBlock(imagePickerController, .image(resizedImage))
                                                                                                                } else {
                                                                                                                    imagePickerController.commitBlock(imagePickerController, .image(image))
                                                                                                                }
                                                                                                            }
                                                                                                        } else {
                                                                                                            imagePickerController.commitBlock(imagePickerController, .error(NSError(domain: NSKCameraControllerErrorDomain, code: -1, userInfo: nil)))
                                                                                                        }
                                                                            })
                                                                        case .assets(let assets):
                                                                            NSKImageFetcher.fetchImages(maximumSize: nil, assets: assets, completion: { [weak imagePickerController] (images) in
                                                                                guard let imagePickerController = imagePickerController else { return }
                                                                                
                                                                                if isConfirmationRequired, images.isEmpty == false {
                                                                                    imagePickerController.initConfirmationDialog(initialImages: images, resultedImages: [], minimumSize: minimumSize, maximumSize: maximumSize, completion: { (imagePickerController, resultedImages) in
                                                                                        if let resultedImages = resultedImages {
                                                                                            imagePickerController.commitBlock(imagePickerController, .images(resultedImages))
                                                                                        } else {
                                                                                            imagePickerController.commitBlock(imagePickerController, .cancelled)
                                                                                        }
                                                                                    })
                                                                                } else {
                                                                                    let imagesValue: [UIImage]
                                                                                    if let maximumSize = maximumSize {
                                                                                        imagesValue = images.map { (image) -> UIImage in
                                                                                            image.resize(maximumSize: maximumSize)
                                                                                        }
                                                                                    } else {
                                                                                        imagesValue = images
                                                                                    }
                                                                                    imagePickerController.commitBlock(imagePickerController, .images(imagesValue))
                                                                                }
                                                                            })
                                                                        default:
                                                                            return
                                                                        }
                                                                    }
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
            
        case .camera:
            let videoCaptureController = NSKVideoCaptureController(commitBlock: { (captureController, result) in
                guard let cameraController = captureController.parent as? NSKCameraController else {
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
                                                                commitBlock: { (imagePickerController, confimationResult) in
                                                                    switch confimationResult {
                                                                    case .cancelled:
                                                                        imagePickerController.commitBlock(imagePickerController, .cancelled)
                                                                    case .image(let image):
                                                                        imagePickerController.commitBlock(imagePickerController, .image(image))
                                                                    }
                        })
                    } else {
                        if let maximumSize = maximumSize {
                            let resizedImage = image.resize(maximumSize: maximumSize)
                            cameraController.commitBlock(cameraController, .image(resizedImage))
                        } else {
                            cameraController.commitBlock(cameraController, .image(image))
                        }
                    }
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
    
    private func initChildImagePickerScreen(source: Source) {
        
    }
    
    private func initConfirmationDialog(image: UIImage, minimumSize: CGSize, maximumSize: CGSize?, commitBlock: @escaping (NSKCameraController, ConfirmationResult) -> Void) {
        let resizingModeValue: ResizingMode
        if let resizingMode = self.options.first(where: { (option) -> Bool in
            switch option {
            case .resizingMode:
                return true
            default:
                return false
            }
        }) {
            switch resizingMode {
            case .resizingMode(let resizingMode):
                resizingModeValue = resizingMode
            default:
                resizingModeValue = .free
            }
        } else {
            resizingModeValue = .free
        }
        let сonfirmationController = NSKConfirmationController(image: image, isCroppingEnabled: true, isResizingEnabled: true,
                                                               resizingMode: resizingModeValue,
                                                               minSize: minimumSize, maxSize: maximumSize,
                                                               commitBlock: { сonfirmationController, image in
                                                                guard let cameraController = сonfirmationController.parent as? NSKCameraController else {
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
        let isConfirmationRequired: Bool
        if let option = self.options.first(where: { (opt) -> Bool in
            switch opt {
            case .isConfirmationRequired:
                return true
            default:
                return false
            }
        }) {
            switch option {
            case .isConfirmationRequired(let isRequired):
                isConfirmationRequired = isRequired
            default:
                isConfirmationRequired = false
            }
        } else {
            isConfirmationRequired = false
        }
        return isConfirmationRequired
    }
    
    public var minimumSize: CGSize {
        let minimumSizeValue: CGSize
        if let limits = self.options.first(where: { (opt) -> Bool in
            switch opt {
            case .limits:
                return true
            default:
                return false
            }
        }) {
            switch limits {
            case .limits(let limits):
                minimumSizeValue = limits.minSize
            default:
                minimumSizeValue = .zero
            }
        } else {
            minimumSizeValue = .zero
        }
        return minimumSizeValue
    }
    public var maximumSize: CGSize? {
        let maximumSizeValue: CGSize?
        if let limits = self.options.first(where: { (opt) -> Bool in
            switch opt {
            case .limits:
                return true
            default:
                return false
            }
        }) {
            switch limits {
            case .limits(let limits):
                maximumSizeValue = limits.maxSize
            default:
                maximumSizeValue = nil
            }
        } else {
            maximumSizeValue = nil
        }
        return maximumSizeValue
    }
}

