//
//  NSKVideoCaptureController.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 02.03.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

private var kInterfaceOrientation: Int8 = 0


struct NSKVideoCapture {
    let videoData: Data // данные видео
    let url: URL // адрес видео
}

class NSKVideoCameraManager: NSObject {
    private var captureSession: AVCaptureSession?
    private var backCameraInput: AVCaptureDeviceInput?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var flashMode: AVCaptureDevice.FlashMode? // если nil - то недоступен в данный момент
    private var imageCapture: ((Result<UIImage, Error>) -> Void)?
    private var videoCapture: ((Result<NSKVideoCapture, Error>) -> Void)?
    
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
            sSelf.movieFileOutput = nil
            sSelf.flashMode = nil
            sSelf.imageCapture = nil
            sSelf.videoCapture = nil
            
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
        
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
            } catch {
                print(error)
            }
        }
        
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
        
        let movieFileOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieFileOutput) {
            if let connection = movieFileOutput.connection(with: .video) {
                if #available(iOS 11.0, *) {
                    if movieFileOutput.availableVideoCodecTypes.contains(.h264) {
                        movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264.rawValue], for: connection)
                    }
                } else {
                    if movieFileOutput.availableVideoCodecTypes.contains(AVVideoCodecType(rawValue: AVVideoCodecH264)) {
                        movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecH264], for: connection)
                    }
                }
            }
            
            captureSession.addOutput(movieFileOutput)
            self.movieFileOutput = movieFileOutput
        }
        
        captureSession.commitConfiguration()
        
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
            
            if let movieFileOutput = sSelf.movieFileOutput {
                if movieFileOutput.isRecording {
                    movieFileOutput.stopRecording()
                    return
                }
            }
            
            if let captureSession = sSelf.captureSession, let photoOutput = sSelf.photoOutput {
                sSelf.imageCapture = completion
                let photoSettings: AVCapturePhotoSettings
                if #available(iOS 11.0, *) {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])
                    photoSettings.metadata[kCGImagePropertyOrientation as String] = initialOrientation.rawValue
                    if #available(iOS 12.0, *) {
                        photoSettings.isAutoRedEyeReductionEnabled = true
                    }
                } else {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])
                    objc_setAssociatedObject(photoOutput, &kInterfaceOrientation, NSNumber(value: initialOrientation.rawValue), .OBJC_ASSOCIATION_COPY)
                }
                if let firstAvailablePreviewPhotoPixelFormatTypes = photoSettings.__availablePreviewPhotoPixelFormatTypes.first {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: firstAvailablePreviewPhotoPixelFormatTypes]
                }
                
                if let backCameraInput = sSelf.backCameraInput, captureSession.inputs.contains(backCameraInput), let flashMode = sSelf.flashMode {
                    photoSettings.flashMode = flashMode
                }
                photoOutput.capturePhoto(with: photoSettings, delegate: sSelf)
            }
        }
    }
    
    func captureVideo(initialOrientation: UIInterfaceOrientation, completion: @escaping (Result<NSKVideoCapture, Error>) -> Void) {
        self.queue.async { [weak self] in
            guard let sSelf = self, let movieFileOutput = sSelf.movieFileOutput else { return }
            
            guard let directory = FileManager.default.documentDirectory else {
                return
            }
            if movieFileOutput.isRecording {
                movieFileOutput.stopRecording()
            } else {
                sSelf.videoCapture = completion
                
                objc_setAssociatedObject(movieFileOutput, &kInterfaceOrientation, NSNumber(value: initialOrientation.rawValue), .OBJC_ASSOCIATION_COPY)
                //movieFileOutput.maxRecordedDuration = CMTime(seconds: sSelf.maxVideoDuration, preferredTimescale: 1)
                
                let path = directory.appendingPathComponent("temp_\(Date()).mov")
                movieFileOutput.startRecording(to: path, recordingDelegate: sSelf)
            }
        }
    }
    func stopVideo() {
        self.queue.async { [weak self] in
            guard let sSelf = self, let movieFileOutput = sSelf.movieFileOutput else { return }
            
            if movieFileOutput.isRecording {
                movieFileOutput.stopRecording()
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
        self.queue.async { [weak self] in
            guard let sSelf = self, let imageCapture = sSelf.imageCapture else { return }
            
            sSelf.imageCapture = nil
            
            if let error = error {
                DispatchQueue.main.async {
                    imageCapture(.failure(error))
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
                    
                    DispatchQueue.main.async {
                        imageCapture(.success(image))
                    }
                } else {
                    let error = NSError(domain: NSKCameraControllerErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture image."])
                    DispatchQueue.main.async {
                        imageCapture(.failure(error))
                    }
                }
            }
        }
    }
    
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        self.queue.async { [weak self] in
            guard let sSelf = self, let imageCapture = sSelf.imageCapture else { return }
            
            sSelf.imageCapture = nil
            
            if let error = error {
                DispatchQueue.main.async {
                    imageCapture(.failure(error))
                }
            } else if let cgImage = photo.cgImageRepresentation() {
                let interfaceOrientation: UIInterfaceOrientation
                if let i = photo.metadata[kCGImagePropertyOrientation as String] as? Int, let interfaceOrientationValue = UIInterfaceOrientation(rawValue: i) {
                    interfaceOrientation = interfaceOrientationValue
                } else {
                    interfaceOrientation = .portrait
                }
                let image = Self.image(from: cgImage, interfaceOrientation: interfaceOrientation)
                
                DispatchQueue.main.async {
                    imageCapture(.success(image))
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

extension NSKVideoCameraManager: AVCaptureFileOutputRecordingDelegate {
    private func resize(inputURL: URL, interfaceOrientation: UIInterfaceOrientation) -> AVAssetExportSession? {
        guard let session = AVAssetExportSession(asset: AVAsset(url: inputURL), presetName: AVAssetExportPreset960x540) else {
            return nil
        }
        
        let asset = session.asset
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let naturalSize = videoTrack.naturalSize
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let renderSize: CGSize
            
            switch interfaceOrientation {
            case .landscapeLeft:
                let tr = CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -naturalSize.width, y: -naturalSize.height)
                layerInstruction.setTransform(tr, at: .zero)
                renderSize = naturalSize
            case .landscapeRight:
                renderSize = naturalSize
            case .portrait:
                renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                let tr = CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -naturalSize.height)
                layerInstruction.setTransform(tr, at: .zero)
            default:
                renderSize = naturalSize
            }
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
            instruction.layerInstructions = [layerInstruction]
            
            let videoComposition = AVMutableVideoComposition()
            videoComposition.renderSize = renderSize
            videoComposition.instructions = [instruction]
            videoComposition.frameDuration = videoTrack.minFrameDuration
            
            session.videoComposition = videoComposition
        }
        
        let mp4Url = inputURL.deletingLastPathComponent().appendingPathComponent("appercode-resize.mp4")
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
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        self.queue.async { [weak self] in
            guard let sSelf = self else { return }
            guard let videoCapture = sSelf.videoCapture else { return }
            
            if let nsError = error as NSError?, let result = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool, result == false {
                DispatchQueue.main.async {
                    videoCapture(.failure(nsError))
                }
            } else {
                guard let orientation = objc_getAssociatedObject(output, &kInterfaceOrientation) as? NSNumber, let interfaceOrientation = UIInterfaceOrientation(rawValue: orientation.intValue) else {
                    return
                }
                guard let resizeSession = sSelf.resize(inputURL: outputFileURL, interfaceOrientation: interfaceOrientation) else {
                    return
                }
                
                resizeSession.exportAsynchronously {
                    switch resizeSession.status {
                    case .completed:
                        do {
                            let videoOutputURL = resizeSession.outputURL!
                            let videoData = try Data(contentsOf: videoOutputURL)
                            let capture = NSKVideoCapture(videoData: videoData, url: videoOutputURL)
                            
                            DispatchQueue.main.async {
                                videoCapture(.success(capture))
                            }
                        } catch {
                            DispatchQueue.main.async {
                                videoCapture(.failure(error))
                            }
                        }
                    case .failed:
                        let error = resizeSession.error ?? NSError(domain: NSKCameraControllerErrorDomain, code: -1,
                                                                   userInfo: [NSLocalizedDescriptionKey: "Failed to resize video."])
                        DispatchQueue.main.async {
                            videoCapture(.failure(error))
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
}


class NSKVideoCaptureController: UIViewController {
    enum VideoCaptureResult {
        case cancelled
        case image(UIImage)
        case video(NSKVideoCapture)
        case error(Error)
    }
    public enum CaptureType {
        case image, video(/*tipString*/String)
    }
    let captureType: CaptureType
    let commitBlock: (NSKVideoCaptureController, VideoCaptureResult) -> Void
    let isCroppingEnabled: Bool
    
    private let cameraController = NSKVideoCameraManager()
    private let timer = NSKBackgroundTimer()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var shouldInvalidatePreviewLayerPosition = true
    private var verticalCaptureButtonConstraint: [NSLayoutConstraint] = []
    private var horizontalCaptureButtonConstraint: [NSLayoutConstraint] = []
    
    private var flashButtonTag: Int { return -1001 }
    private var swapButtonTag: Int { return -1002 }
    private var timeLabel: UILabel?
    private var tipLabel: UIView?
    
    init(captureType: CaptureType, isCroppingEnabled: Bool,
         commitBlock: @escaping (NSKVideoCaptureController, VideoCaptureResult) -> Void) {
        self.captureType = captureType
        self.commitBlock = commitBlock
        self.isCroppingEnabled = isCroppingEnabled
        
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
                        
                        let topInset: CGFloat = 16
                        let view = ssSelf.view!
                        let viewBounds = view.bounds.size
                        
                        view.layer.insertSublayer(previewLayer, at: 0)
                        ssSelf.previewLayer = previewLayer
                        ssSelf.invalidatePreviewLayer(previewLayer, size: viewBounds)
                        
                        let tapGestureRecognizer = UITapGestureRecognizer(target: ssSelf, action: #selector(ssSelf.handleFocusGesture(_:)))
                        view.addGestureRecognizer(tapGestureRecognizer)
                        /////////////////////////////////////////////////////////////////////
                        if ssSelf.isCroppingEnabled {
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
                        }
                        /////////////////////////////////////////////////////////////////////
                        
                        let closeButton = ssSelf.createCloseButton()
                        view.addSubview(closeButton)
                        closeButton.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor).isActive = true
                        if #available(iOS 11.0, *) {
                            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -34).isActive = true
                        } else {
                            closeButton.bottomAnchor.constraint(equalTo: ssSelf.bottomLayoutGuide.topAnchor, constant: -34).isActive = true
                        }
                        
                        if let flashMode = configuration.flashMode {
                            let flashButton = UIButton(type: .system)
                            flashButton.tag = ssSelf.flashButtonTag
                            flashButton.translatesAutoresizingMaskIntoConstraints = false
                            flashButton.setImage(flashMode.flashImage, for: .normal)
                            flashButton.addTarget(ssSelf, action: #selector(ssSelf.toggleFlashModeAction(_:)), for: .touchUpInside)
                            view.addSubview(flashButton)
                            flashButton.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor).isActive = true
                            if #available(iOS 11.0, *) {
                                flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topInset).isActive = true
                            } else {
                                flashButton.topAnchor.constraint(equalTo: ssSelf.topLayoutGuide.bottomAnchor, constant: topInset).isActive = true
                            }
                        }
                        
                        let captureButton = UIButton()
                        captureButton.translatesAutoresizingMaskIntoConstraints = false
                        captureButton.setImage(NSKResourceProvider.captureButton, for: .normal)
                        captureButton.setImage(NSKResourceProvider.captureButtonHighlighted, for: .highlighted)
                        view.addSubview(captureButton)
                        
                        ssSelf.verticalCaptureButtonConstraint = [captureButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
                                                                  captureButton.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor)]
                        ssSelf.horizontalCaptureButtonConstraint = [captureButton.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),
                                                                    captureButton.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor)]
                        if viewBounds.height > viewBounds.width {
                            NSLayoutConstraint.activate(ssSelf.verticalCaptureButtonConstraint)
                        } else {
                            NSLayoutConstraint.activate(ssSelf.horizontalCaptureButtonConstraint)
                        }
                        
                        switch ssSelf.captureType {
                        case .image:
                            captureButton.addTarget(ssSelf, action: #selector(ssSelf.captureMediaAction(_:)), for: .touchUpInside)
                        case .video(let tip):
                            captureButton.addTarget(ssSelf, action: #selector(ssSelf.captureVideoAction(_:)), for: .touchDown)
                            captureButton.addTarget(ssSelf, action: #selector(ssSelf.stopVideoAction(_:)), for: .touchUpInside)
                            ssSelf.configureTipLabel(tip: tip, captureButton: captureButton)
                        }
                        
                        if configuration.hasFrontCamera {
                            let swapCameraButton = UIButton(type: .system)
                            swapCameraButton.tag = ssSelf.swapButtonTag
                            swapCameraButton.translatesAutoresizingMaskIntoConstraints = false
                            swapCameraButton.setImage(NSKResourceProvider.swapCameraImage, for: .normal)
                            swapCameraButton.addTarget(sSelf, action: #selector(ssSelf.swapCameraAction(_:)), for: .touchUpInside)
                            view.addSubview(swapCameraButton)
                            swapCameraButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor).isActive = true
                            swapCameraButton.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor).isActive = true
                        }
                        
                        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: ssSelf, action: #selector(ssSelf.handlePinchGesture(_:)))
                        view.addGestureRecognizer(pinchGestureRecognizer)
                        
                        let label = UILabel()
                        label.textColor = .white
                        label.translatesAutoresizingMaskIntoConstraints = false
                        view.addSubview(label)
                        
                        label.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor).isActive = true
                        if #available(iOS 11.0, *) {
                            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topInset).isActive = true
                        } else {
                            label.topAnchor.constraint(equalTo: ssSelf.topLayoutGuide.bottomAnchor, constant: topInset).isActive = true
                        }
                        ssSelf.timeLabel = label
                        
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
    
    private func configureTipLabel(tip: String, captureButton: UIView) {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 13)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = tip
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let parentLabelView = UIView()
        parentLabelView.backgroundColor = UIColor(red: CGFloat(92) / 255,
                                                  green: CGFloat(92) / 255,
                                                  blue: CGFloat(92) / 255,
                                                  alpha: 1)
        parentLabelView.layer.cornerRadius = 2
        parentLabelView.translatesAutoresizingMaskIntoConstraints = false
        
        parentLabelView.addSubview(label)
        let padding: CGFloat = 4
        label.leftAnchor.constraint(equalTo: parentLabelView.leftAnchor, constant: padding).isActive = true
        label.rightAnchor.constraint(equalTo: parentLabelView.rightAnchor, constant: -padding).isActive = true
        label.topAnchor.constraint(equalTo: parentLabelView.topAnchor, constant: padding).isActive = true
        label.bottomAnchor.constraint(equalTo: parentLabelView.bottomAnchor, constant: -padding).isActive = true
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 150).isActive = true
        
        let parentView = UIView()
        parentView.translatesAutoresizingMaskIntoConstraints = false
        
        parentView.addSubview(parentLabelView)
        parentLabelView.leftAnchor.constraint(equalTo: parentView.leftAnchor).isActive = true
        parentLabelView.rightAnchor.constraint(equalTo: parentView.rightAnchor).isActive = true
        parentLabelView.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        
        let imageView = UIImageView(image: NSKResourceProvider.triangle)
        imageView.tintColor = parentLabelView.backgroundColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(imageView)
        imageView.topAnchor.constraint(equalTo: parentLabelView.bottomAnchor).isActive = true
        imageView.centerXAnchor.constraint(equalTo: parentView.centerXAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
        
        if let superview = captureButton.superview {
            superview.addSubview(parentView)
            parentView.bottomAnchor.constraint(equalTo: captureButton.topAnchor).isActive = true
            parentView.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor).isActive = true
        }
        self.tipLabel = parentView
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard let previewLayer = self.previewLayer else { return }
        self.shouldInvalidatePreviewLayerPosition = false
        let isVertical = size.height > size.width
        
        coordinator.animate(alongsideTransition: { (_) in
            self.invalidatePreviewLayer(previewLayer, size: size)
            if isVertical {
                NSLayoutConstraint.activate(self.verticalCaptureButtonConstraint)
                NSLayoutConstraint.deactivate(self.horizontalCaptureButtonConstraint)
            } else {
                NSLayoutConstraint.deactivate(self.verticalCaptureButtonConstraint)
                NSLayoutConstraint.activate(self.horizontalCaptureButtonConstraint)
            }
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
    
    @objc private func captureVideoAction(_ sender: UIButton) {
        let tag = 1
        sender.tag = tag
        sender.removeTarget(self, action: #selector(self.captureVideoAction(_:)), for: .touchDown)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let sSelf = self else { return }
            
            sender.addTarget(sSelf, action: #selector(sSelf.captureVideoAction(_:)), for: .touchDown)
            
            if sender.tag != tag {
                return
            }
            if let tipLabel = sSelf.tipLabel {
                tipLabel.removeFromSuperview()
                sSelf.tipLabel = nil
            }
            sender.isEnabled = false
            let flashButton = sSelf.view.viewWithTag(sSelf.flashButtonTag) as? UIButton
            let isFlashButtonEnabled = flashButton?.isEnabled ?? false
            
            let swapButton = sSelf.view.viewWithTag(sSelf.swapButtonTag) as? UIButton
            let isSwapButtonEnabled = swapButton?.isEnabled ?? false
            
            flashButton?.isEnabled = false
            swapButton?.isEnabled = false
            
            if let timeLabel = sSelf.timeLabel {
                var videoDuration: TimeInterval = 0
                timeLabel.text = Self.timeString(from: videoDuration)
                sSelf.timer.start(withPeriod: 1, event: { (sender) in
                    videoDuration += 1
                    let timeString = Self.timeString(from: videoDuration)
                    DispatchQueue.main.async {
                        timeLabel.text = timeString
                    }
                })
            }
            
            sSelf.cameraController.captureVideo(initialOrientation: UIApplication.shared.statusBarOrientation,
                                                completion: { [weak sSelf] (result) in
                                                    guard let ssSelf = sSelf else { return }
                                                    
                                                    ssSelf.timer.stop()
                                                    ssSelf.timeLabel?.text = nil
                                                    
                                                    let commonCompletion: () -> Void = {
                                                        sender.tag = 0
                                                        sender.isEnabled = true
                                                        flashButton?.isEnabled = isFlashButtonEnabled
                                                        swapButton?.isEnabled = isSwapButtonEnabled
                                                    }
                                                    
                                                    switch result {
                                                    case .success(let capture):
                                                        commonCompletion()
                                                        ssSelf.commitBlock(ssSelf, .video(capture))
                                                    case .failure(let error):
                                                        commonCompletion()
                                                        ssSelf.commitBlock(ssSelf, .error(error))
                                                    }
            })
        }
    }
    @objc private func captureMediaAction(_ sender: UIButton) {
        self.stopVideo(sender)
        
        sender.isEnabled = false
        
        let flashButton = self.view.viewWithTag(self.flashButtonTag) as? UIButton
        let isFlashButtonEnabled = flashButton?.isEnabled ?? false
        
        let swapButton = self.view.viewWithTag(self.swapButtonTag) as? UIButton
        let isSwapButtonEnabled = swapButton?.isEnabled ?? false
        
        flashButton?.isEnabled = false
        swapButton?.isEnabled = false
        
        self.cameraController.captureImage(initialOrientation: UIApplication.shared.statusBarOrientation, completion: { [weak self] (result) in
            guard let sSelf = self else { return }
            sender.isEnabled = true
            flashButton?.isEnabled = isFlashButtonEnabled
            swapButton?.isEnabled = isSwapButtonEnabled
            
            switch result {
            case .success(let image):
                sSelf.commitBlock(sSelf, .image(image))
            case .failure(let error):
                sSelf.commitBlock(sSelf, .error(error))
            }
        })
    }
    
    @objc private func stopVideoAction(_ sender: UIButton) {
        self.stopVideo(sender)
        self.cameraController.stopVideo()
    }
    
    private func stopVideo(_ sender: UIButton) {
        self.timer.stop()
        self.timeLabel?.text = nil
        sender.tag = 0
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
    
    private static func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = floor(timeInterval / 60)
        let seconds = timeInterval - 60 * minutes
        
        return String(format: "%02.0f", min(minutes, 59)) + ":" + String(format: "%02.0f", seconds)
    }
}

