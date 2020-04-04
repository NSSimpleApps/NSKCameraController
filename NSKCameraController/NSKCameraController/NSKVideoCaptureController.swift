//
//  NSKVideoCaptureController.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 02.03.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import AVFoundation


private var kInterfaceOrientation: Int8 = 0

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

class NSKVideoCameraManager: NSObject {
    private var captureSession: AVCaptureSession?
    private var backCameraInput: AVCaptureDeviceInput?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var flashMode: AVCaptureDevice.FlashMode? // если nil - то недоступен в данный момент
    private var imageCapture: ((Result<UIImage, Error>) -> Void)?
    
    private let queue = DispatchQueue(label: "NSKVideoCameraManager")
    
    struct Configuration {
        let hasFrontCamera: Bool
        let flashMode: AVCaptureDevice.FlashMode? // nil means flash is not available at this moment
    }
    
    enum ConfigurationResult {
        case denied
        case success(Configuration)
    }
    
    func prepare(completionHandler: @escaping (Result<ConfigurationResult, Error>) -> Void) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            
            sSelf.captureSession = nil
            sSelf.backCameraInput = nil
            sSelf.frontCameraInput = nil
            sSelf.photoOutput = nil
            sSelf.flashMode = nil
            sSelf.imageCapture = nil
            
            let mediaType = AVMediaType.video
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)
            switch authorizationStatus {
            case .denied:
                DispatchQueue.main.async {
                    completionHandler(.success(.denied))
                }
            case .authorized:
                do {
                    let сonfiguration = try sSelf.prepareCaptureSession()
                    DispatchQueue.main.async {
                        completionHandler(.success(.success(сonfiguration)))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completionHandler(.failure(error))
                    }
                }
            default:
                AVCaptureDevice.requestAccess(for: mediaType,
                                              completionHandler: { [weak sSelf] (granted) in
                                                guard let ssSelf = sSelf else { return }
                                                if granted {
                                                    ssSelf.queue.async { [weak ssSelf] in
                                                        guard let sssSelf = ssSelf else { return }
                                                        do {
                                                            let сonfiguration = try sssSelf.prepareCaptureSession()
                                                            DispatchQueue.main.async {
                                                                completionHandler(.success(.success(сonfiguration)))
                                                            }
                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                completionHandler(.failure(error))
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    DispatchQueue.main.async {
                                                        completionHandler(.success(.denied))
                                                    }
                                                }
                })
            }
        }
    }
    private func prepareCaptureSession() throws -> Configuration {
        let captureSession = AVCaptureSession()
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        let devices = session.devices
        
        let hasFrontCamera: Bool
        if let frontCamera = devices.first(where: { (camera) -> Bool in
            camera.position == .front
        }) {
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            hasFrontCamera = true
        } else {
            hasFrontCamera = false
        }
        captureSession.beginConfiguration()
        
        if let backCamera = devices.first(where: { (camera) -> Bool in
            camera.position == .back
        }) {
            try backCamera.lockForConfiguration()
            backCamera.focusMode = .continuousAutoFocus
            backCamera.unlockForConfiguration()
            
            if backCamera.hasFlash && backCamera.isFlashAvailable {
                self.flashMode = .auto
            }
            
            let backCameraInput = try AVCaptureDeviceInput(device: backCamera)
            self.backCameraInput = backCameraInput
            if captureSession.canAddInput(backCameraInput) {
                captureSession.addInput(backCameraInput)
            }
        }
        
        let photoOutput = AVCapturePhotoOutput()
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        captureSession.commitConfiguration()
        
        self.photoOutput = photoOutput
        self.captureSession = captureSession
        return Configuration(hasFrontCamera: hasFrontCamera, flashMode: self.flashMode)
    }
    
    func createPreview(completion: @escaping (AVCaptureVideoPreviewLayer?) -> Void) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            
            if let captureSession = sSelf.captureSession {
                let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                
                DispatchQueue.main.async {
                    completion(previewLayer)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func startRunning() {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            
            if let captureSession = sSelf.captureSession, captureSession.isRunning == false {
                captureSession.startRunning()
            }
        }
    }
    
    func switchToNextFlashMode(completion: @escaping (AVCaptureDevice.FlashMode?) -> Void) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            
            if let captureSession = sSelf.captureSession, let backCameraInput = sSelf.backCameraInput {
                if captureSession.inputs.contains(backCameraInput) {
                    if let flashMode = sSelf.flashMode {
                        let newValue = flashMode.next()
                        sSelf.flashMode = newValue
                        DispatchQueue.main.async {
                            completion(newValue)
                        }
                        return
                    }
                }
            }
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    func swapCamera(completion: @escaping (/*isFlashAvailable*/Bool) -> Void) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            
            if let captureSession = sSelf.captureSession {
                captureSession.beginConfiguration()
                
                let isFlashAvailable: Bool
                if let backCameraInput = sSelf.backCameraInput, captureSession.inputs.contains(backCameraInput) {
                    captureSession.removeInput(backCameraInput)
                    
                    if let frontCameraInput = sSelf.frontCameraInput, captureSession.canAddInput(frontCameraInput) {
                        captureSession.addInput(frontCameraInput)
                        isFlashAvailable = frontCameraInput.device.isFlashAvailable
                    } else {
                        isFlashAvailable = false
                    }
                } else if let frontCameraInput = sSelf.frontCameraInput, captureSession.inputs.contains(frontCameraInput) {
                    captureSession.removeInput(frontCameraInput)
                    
                    if let backCameraInput = sSelf.backCameraInput, captureSession.canAddInput(backCameraInput) {
                        captureSession.addInput(backCameraInput)
                        isFlashAvailable = backCameraInput.device.isFlashAvailable
                    } else {
                        isFlashAvailable = false
                    }
                } else {
                    isFlashAvailable = false
                }
                captureSession.commitConfiguration()
                
                DispatchQueue.main.async {
                    completion(isFlashAvailable)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    func captureImage(initialOrientation: UIInterfaceOrientation, completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            
            if let captureSession = sSelf.captureSession, let photoOutput = sSelf.photoOutput {
                sSelf.imageCapture = completion
                let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])
                if #available(iOS 11.0, *) {
                    photoSettings.metadata[kCGImagePropertyOrientation as String] = initialOrientation.rawValue
                } else {
                    objc_setAssociatedObject(photoOutput, &kInterfaceOrientation, NSNumber(value: initialOrientation.rawValue), .OBJC_ASSOCIATION_COPY)
                }
                if #available(iOS 12.0, *) {
                    photoSettings.isAutoRedEyeReductionEnabled = true
                }
                if let firstAvailablePreviewPhotoPixelFormatTypes = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: firstAvailablePreviewPhotoPixelFormatTypes]
                }
                
                if let backCameraInput = sSelf.backCameraInput, captureSession.inputs.contains(backCameraInput), let flashMode = sSelf.flashMode {
                    photoSettings.flashMode = flashMode
                }
                photoOutput.capturePhoto(with: photoSettings, delegate: sSelf)
            }
        }
    }
    
    func updateZoom(with velocity: CGFloat) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            guard let captureSession = sSelf.captureSession else { return }
            
            if let backCameraInput = sSelf.backCameraInput, captureSession.inputs.contains(backCameraInput) {
                sSelf.updateZoom(with: velocity, device: backCameraInput.device)
            } else if let frontCameraInput = sSelf.frontCameraInput, captureSession.inputs.contains(frontCameraInput) {
                sSelf.updateZoom(with: velocity, device: frontCameraInput.device)
            }
        }
    }
    private func updateZoom(with velocity: CGFloat, device: AVCaptureDevice) {
        let velocityFactor: CGFloat = 8.0
        let desiredZoomFactor = device.videoZoomFactor + atan2(velocity, velocityFactor)
        let newScaleFactor = min(max(desiredZoomFactor, 1.0), device.activeFormat.videoMaxZoomFactor)
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newScaleFactor
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func focus(on point: CGPoint, previewLayer: AVCaptureVideoPreviewLayer, completion: @escaping (Bool) -> Void) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            
            if let captureSession = sSelf.captureSession {
                let device: AVCaptureDevice
                if let backCameraInput = sSelf.backCameraInput, captureSession.inputs.contains(backCameraInput) {
                    device = backCameraInput.device
                } else if let frontCameraInput = sSelf.frontCameraInput, captureSession.inputs.contains(frontCameraInput) {
                    device = frontCameraInput.device
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    do {
                        try device.lockForConfiguration()
                        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
                        device.focusPointOfInterest = focusPoint
                        device.focusMode = .continuousAutoFocus

                        device.exposurePointOfInterest = focusPoint
                        device.exposureMode = .continuousAutoExposure

                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    } catch {
                        print(error)
                        DispatchQueue.main.async {
                            completion(false)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}

extension NSKVideoCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            self.queue.async { [weak self] in
                guard let sSelf = self else { return }
                
                if let imageCapture = sSelf.imageCapture {
                    sSelf.imageCapture = nil
                    DispatchQueue.main.async {
                        imageCapture(.failure(error))
                    }
                }
            }
        } else {
            if let photoSampleBuffer = photoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer),
                let dataProvider = CGDataProvider(data: dataImage as CFData), let cgImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
                let interfaceOrientation: UIInterfaceOrientation
                if let value = objc_getAssociatedObject(output, &kInterfaceOrientation) as? NSNumber,
                    let orientation = UIInterfaceOrientation(rawValue: value.intValue) {
                    interfaceOrientation = orientation
                } else {
                    interfaceOrientation = .unknown
                }
                let image = Self.image(from: cgImage, interfaceOrientation: interfaceOrientation)
                
                self.queue.async { [weak self] in
                    guard let sSelf = self else { return }
                    
                    if let imageCapture = sSelf.imageCapture {
                        sSelf.imageCapture = nil
                        
                        DispatchQueue.main.async {
                            imageCapture(.success(image))
                        }
                    }
                }
            } else {
                let error = NSError(domain: NSKCameraControllerErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture image."])
                self.queue.async { [weak self] in
                    guard let sSelf = self else { return }
                    
                    if let imageCapture = sSelf.imageCapture {
                        sSelf.imageCapture = nil
                        
                        DispatchQueue.main.async {
                            imageCapture(.failure(error))
                        }
                    }
                }
            }
        }
    }
    
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            self.queue.async { [weak self] in
                guard let sSelf = self else { return }
                
                if let imageCapture = sSelf.imageCapture {
                    sSelf.imageCapture = nil
                    
                    DispatchQueue.main.async {
                        imageCapture(.failure(error))
                    }
                }
            }
        } else if let cgImage = photo.cgImageRepresentation()?.takeUnretainedValue() {
            let interfaceOrientation: UIInterfaceOrientation
            if let i = photo.metadata[kCGImagePropertyOrientation as String] as? Int, let interfaceOrientationValue = UIInterfaceOrientation(rawValue: i) {
                interfaceOrientation = interfaceOrientationValue
            } else {
                interfaceOrientation = .portrait
            }
            let image = Self.image(from: cgImage, interfaceOrientation: interfaceOrientation)
            self.queue.async { [weak self] in
                guard let sSelf = self else { return }
                
                if let imageCapture = sSelf.imageCapture {
                    sSelf.imageCapture = nil
                    
                    DispatchQueue.main.async {
                        imageCapture(.success(image))
                    }
                }
            }
        }
    }
    
    private static func image(from cgImage: CGImage, interfaceOrientation: UIInterfaceOrientation) -> UIImage {
        let imageOrientation: UIImage.Orientation
        switch interfaceOrientation {
        case .portrait:
            imageOrientation = .right
        case .landscapeLeft:
            imageOrientation = .down
        case .landscapeRight:
            imageOrientation = .up
        default:
            imageOrientation = .up
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: imageOrientation)
    }
}

class NSKVideoCaptureController: UIViewController {
    enum VideoCaptureResult {
        case cancelled
        case image(UIImage)
        case error(Error)
    }
    let commitBlock: (NSKVideoCaptureController, VideoCaptureResult) -> Void
    
    private let cameraController = NSKVideoCameraManager()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var shouldInvalidatePreviewLayerPosition = true
    
    private var flashButtonTag: Int { return -1001 }
    
    init(commitBlock: @escaping (NSKVideoCaptureController, VideoCaptureResult) -> Void) {
        self.commitBlock = commitBlock
        
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        
        let activityIndicatorView = UIActivityIndicatorView(style: .white)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(activityIndicatorView)
        activityIndicatorView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        activityIndicatorView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        activityIndicatorView.startAnimating()
        
        self.cameraController.prepare { [weak self] (result) in
            guard let sSelf = self else { return }
            activityIndicatorView.removeFromSuperview()
            
            switch result {
            case .failure(let error):
                sSelf.commitBlock(sSelf, .error(error))
            case .success(let configurationResult):
                switch configurationResult {
                case .denied:
                    let view = sSelf.view!
                    let openSettingsView = NSKOpenSettingsView.createOpenSettingsView(target: sSelf, action: #selector(sSelf.openSettingsAction(_:)))
                    openSettingsView.translatesAutoresizingMaskIntoConstraints = false
                    view.addSubview(openSettingsView)
                    openSettingsView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
                    openSettingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
                    openSettingsView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
                    openSettingsView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
                    
                    let closeButton = sSelf.createCloseButton()
                    openSettingsView.addSubview(closeButton)
                    let leftInset: CGFloat = 16
                    let bottomInset: CGFloat = 32
                    if #available(iOS 11.0, *) {
                        let safeAreaLayoutGuide = sSelf.view.safeAreaLayoutGuide
                        closeButton.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor, constant: leftInset).isActive = true
                        closeButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -bottomInset).isActive = true
                    } else {
                        closeButton.leftAnchor.constraint(equalTo: sSelf.view.layoutMarginsGuide.leftAnchor, constant: leftInset).isActive = true
                        closeButton.bottomAnchor.constraint(equalTo: sSelf.bottomLayoutGuide.topAnchor, constant: -bottomInset).isActive = true
                    }
                case .success(let configuration):
                    sSelf.cameraController.createPreview { [weak sSelf] (previewLayer) in
                        guard let ssSelf = sSelf else { return }
                        guard let previewLayer = previewLayer else { return }
                        
                        let view = ssSelf.view!
                        view.layer.insertSublayer(previewLayer, at: 0)
                        ssSelf.previewLayer = previewLayer
                        ssSelf.invalidatePreviewLayer(previewLayer, size: view.bounds.size)
                        
                        let tapGestureRecognizer = UITapGestureRecognizer(target: ssSelf, action: #selector(ssSelf.handleFocusGesture(_:)))
                        view.addGestureRecognizer(tapGestureRecognizer)
                        /////////////////////////////////////////////////////////////////////
                        let cropView = NSKCropView(isResizingEnabled: false, isMovingEnabled: false,
                                                   resizingMode: .saveAspectRatio, shouldDisplayThinBorders: true, minSize: .zero)
                        cropView.translatesAutoresizingMaskIntoConstraints = false
                        
                        view.addSubview(cropView)
                        cropView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
                        cropView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                        
                        cropView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32).isActive = true
                        let w2 = cropView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32)
                        w2.priority = .defaultHigh
                        w2.isActive = true
                        
                        cropView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -32).isActive = true
                        let h2 = cropView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: -32)
                        h2.priority = w2.priority
                        h2.isActive = true
                        
                        cropView.widthAnchor.constraint(equalTo: cropView.heightAnchor).isActive = true
                        /////////////////////////////////////////////////////////////////////
                        
                        if let flashMode = configuration.flashMode {
                            let flashButton = UIButton(type: .system)
                            flashButton.tag = ssSelf.flashButtonTag
                            flashButton.translatesAutoresizingMaskIntoConstraints = false
                            flashButton.setImage(flashMode.flashImage, for: .normal)
                            flashButton.addTarget(sSelf, action: #selector(ssSelf.toggleFlashModeAction(_:)), for: .touchUpInside)
                            view.addSubview(flashButton)
                            flashButton.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor).isActive = true
                            if #available(iOS 11.0, *) {
                                let safeAreaLayoutGuide = view.safeAreaLayoutGuide
                                flashButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16).isActive = true
                            } else {
                                flashButton.topAnchor.constraint(equalTo: ssSelf.topLayoutGuide.bottomAnchor, constant: 16).isActive = true
                                
                            }
                        }
                        
                        let captureButton = UIButton()
                        captureButton.translatesAutoresizingMaskIntoConstraints = false
                        captureButton.setImage(NSKResourceProvider.captureButton, for: .normal)
                        captureButton.setImage(NSKResourceProvider.captureButtonHighlighted, for: .highlighted)
                        captureButton.addTarget(sSelf, action: #selector(ssSelf.captureImageAction(_:)), for: .touchUpInside)
                        view.addSubview(captureButton)
                        if #available(iOS 11.0, *) {
                            let safeAreaLayoutGuide = view.safeAreaLayoutGuide
                            captureButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16).isActive = true
                            captureButton.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor).isActive = true
                        } else {
                            captureButton.bottomAnchor.constraint(equalTo: ssSelf.bottomLayoutGuide.topAnchor, constant: -16).isActive = true
                            captureButton.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor).isActive = true
                        }
                        
                        let closeButton = ssSelf.createCloseButton()
                        view.addSubview(closeButton)
                        closeButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor).isActive = true
                        closeButton.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor).isActive = true
                        
                        if configuration.hasFrontCamera {
                            let swapCameraButton = UIButton(type: .system)
                            swapCameraButton.translatesAutoresizingMaskIntoConstraints = false
                            swapCameraButton.setImage(NSKResourceProvider.swapCameraImage, for: .normal)
                            swapCameraButton.addTarget(sSelf, action: #selector(ssSelf.swapCameraAction(_:)), for: .touchUpInside)
                            view.addSubview(swapCameraButton)
                            swapCameraButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor).isActive = true
                            swapCameraButton.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor).isActive = true
                        }
                        
                        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: ssSelf, action: #selector(ssSelf.handlePinchGesture(_:)))
                        view.addGestureRecognizer(pinchGestureRecognizer)
                        
                        ssSelf.cameraController.startRunning()
                    }
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.shouldInvalidatePreviewLayerPosition, let previewLayer = self.previewLayer {
            previewLayer.frame = self.view.bounds
        }
    }
    
    private func invalidatePreviewLayer(_ layer: AVCaptureVideoPreviewLayer, size: CGSize) {
        layer.frame = CGRect(origin: .zero, size: size)
        
        guard let connection = layer.connection, connection.isVideoOrientationSupported else { return }
        
        if size.width > size.height {
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                connection.videoOrientation = .landscapeLeft
            case .landscapeRight:
                connection.videoOrientation = .landscapeRight
            default:
                break
            }
        } else {
            connection.videoOrientation = .portrait
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard let previewLayer = self.previewLayer else { return }
        self.shouldInvalidatePreviewLayerPosition = false
        
        coordinator.animate(alongsideTransition: { (_) in
            self.invalidatePreviewLayer(previewLayer, size: size)
        }, completion: { _ in
            self.shouldInvalidatePreviewLayerPosition = true
        })
    }
    
    @objc private func openSettingsAction(_ sender: UIButton) {
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
        }
    }
    
    @objc private func closeAction(_ sender: UIButton) {
        self.commitBlock(self, .cancelled)
    }
    
    @objc private func toggleFlashModeAction(_ sender: UIButton) {
        sender.isEnabled = false
        self.cameraController.switchToNextFlashMode(completion: { [weak sender] (newFlashMode) in
            guard let sender = sender else { return }
            
            sender.isEnabled = true
            if let newFlashMode = newFlashMode {
                sender.setImage(newFlashMode.flashImage, for: .normal)
            }
        })
    }
    
    @objc private func swapCameraAction(_ sender: UIButton) {
        sender.isEnabled = false
        let flashButton = self.view.viewWithTag(self.flashButtonTag) as? UIButton
        flashButton?.isEnabled = false
        
        self.cameraController.swapCamera(completion: { (isFlashAvailable) in
            sender.isEnabled = true
            if let flashButton = flashButton {
                flashButton.isEnabled = true
                flashButton.isHidden = isFlashAvailable == false
            }
        })
    }
    
    @objc private func captureImageAction(_ sender: UIButton) {
        sender.isEnabled = false
        
        self.cameraController.captureImage(initialOrientation: UIApplication.shared.statusBarOrientation, completion: { [weak self] (result) in
            guard let sSelf = self else { return }
            sender.isEnabled = true
            switch result {
            case .success(let image):
                sSelf.commitBlock(sSelf, .image(image))
            case .failure(let error):
                sSelf.commitBlock(sSelf, .error(error))
            }
        })
    }
    
    @objc private func handlePinchGesture(_ sender: UIPinchGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            self.cameraController.updateZoom(with: sender.velocity)
        default:
            break
        }
    }
    
    @objc private func handleFocusGesture(_ sender: UITapGestureRecognizer) {
        if let previewLayer = self.previewLayer {
            sender.isEnabled = false
            let point = sender.location(in: sender.view)
            self.cameraController.focus(on: point, previewLayer: previewLayer, completion: { (isEnabled) in
                sender.isEnabled = true
                if isEnabled {
                    let cropView = NSKCropView(isResizingEnabled: false, isMovingEnabled: false, resizingMode: .saveAspectRatio,
                                               shouldDisplayThinBorders: false, minSize: .zero)
                    cropView.frame = CGRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100)
                    cropView.alpha = 0
                    cropView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                    
                    self.view.addSubview(cropView)
                    
                    UIView.animateKeyframes(withDuration: 1.5, delay: 0, options: UIView.KeyframeAnimationOptions(), animations: {
                        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.15, animations: {
                            cropView.alpha = 1
                            cropView.transform = CGAffineTransform.identity
                        })
                        
                        UIView.addKeyframe(withRelativeStartTime: 0.80, relativeDuration: 0.20, animations: {
                            cropView.alpha = 0
                            cropView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                        })
                        }, completion: { finished in
                            cropView.isHidden = true
                            cropView.removeFromSuperview()
                    })
                }
            })
        }
    }
    
    private func createCloseButton() -> UIButton {
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(NSKResourceProvider.retakeImage, for: .normal)
        closeButton.addTarget(self, action: #selector(self.closeAction(_:)), for: .touchUpInside)
        return closeButton
    }
}

