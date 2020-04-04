//
//  NSKViews.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 03.03.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit

protocol NSKCropViewDelegate: AnyObject {
    func cropView(_ cropView: NSKCropView, wantsToMoveTo newFrame: CGRect)
    func cropView(_ cropView: NSKCropView, wantsToMoveBy translation: CGPoint)
}

class NSKCropView: UIView {
    enum CropMode: Int {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let minSize: CGSize
    typealias ResizingMode = NSKCameraController.ResizingMode
    let resizingMode: ResizingMode
    weak var delegate: NSKCropViewDelegate?
    private var anchorInset: CGFloat { return 15 }
    
    init(isResizingEnabled: Bool, isMovingEnabled: Bool, resizingMode: ResizingMode, shouldDisplayThinBorders: Bool, minSize: CGSize) {
        self.resizingMode = resizingMode
        self.minSize = minSize
        super.init(frame: .zero)
        
        let cornerAnchorSize: CGFloat = 44
        let cornerViewMaxSize = cornerAnchorSize / 2
        let cornerViewMinSize: CGFloat = 3
        let borderViewSize: CGFloat = 1
        let anchorInset = self.anchorInset
        
        let topLeftVCorner = self.createCornerView()
        topLeftVCorner.leftAnchor.constraint(equalTo: self.leftAnchor, constant: anchorInset).isActive = true
        topLeftVCorner.topAnchor.constraint(equalTo: self.topAnchor, constant: anchorInset).isActive = true
        topLeftVCorner.widthAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        topLeftVCorner.heightAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        
        let topLeftHCorner = self.createCornerView()
        topLeftHCorner.leftAnchor.constraint(equalTo: topLeftVCorner.leftAnchor).isActive = true
        topLeftHCorner.topAnchor.constraint(equalTo: topLeftVCorner.topAnchor).isActive = true
        topLeftHCorner.widthAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        topLeftHCorner.heightAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        
        let topRightVCorner = self.createCornerView()
        topRightVCorner.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -anchorInset).isActive = true
        topRightVCorner.topAnchor.constraint(equalTo: topLeftVCorner.topAnchor).isActive = true
        topRightVCorner.widthAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        topRightVCorner.heightAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        
        let topRightHCorner = self.createCornerView()
        topRightHCorner.rightAnchor.constraint(equalTo: topRightVCorner.rightAnchor).isActive = true
        topRightHCorner.topAnchor.constraint(equalTo: topRightVCorner.topAnchor).isActive = true
        topRightHCorner.heightAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        topRightHCorner.widthAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        /////////////////////////////////////////////////////////////////////////////////////////////////////////
        let bottomLeftVCorner = self.createCornerView()
        bottomLeftVCorner.leftAnchor.constraint(equalTo: topLeftVCorner.leftAnchor).isActive = true
        bottomLeftVCorner.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -anchorInset).isActive = true
        bottomLeftVCorner.widthAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        bottomLeftVCorner.heightAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        
        let bottomLeftHCorner = self.createCornerView()
        bottomLeftHCorner.leftAnchor.constraint(equalTo: bottomLeftVCorner.leftAnchor).isActive = true
        bottomLeftHCorner.bottomAnchor.constraint(equalTo: bottomLeftVCorner.bottomAnchor).isActive = true
        bottomLeftHCorner.widthAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        bottomLeftHCorner.heightAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        
        let bottomRightVCorner = self.createCornerView()
        bottomRightVCorner.rightAnchor.constraint(equalTo: topRightVCorner.rightAnchor).isActive = true
        bottomRightVCorner.bottomAnchor.constraint(equalTo: bottomLeftVCorner.bottomAnchor).isActive = true
        bottomRightVCorner.widthAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        bottomRightVCorner.heightAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        
        let bottomRightHCorner = self.createCornerView()
        bottomRightHCorner.rightAnchor.constraint(equalTo: bottomRightVCorner.rightAnchor).isActive = true
        bottomRightHCorner.bottomAnchor.constraint(equalTo: bottomRightVCorner.bottomAnchor).isActive = true
        bottomRightHCorner.heightAnchor.constraint(equalToConstant: cornerViewMinSize).isActive = true
        bottomRightHCorner.widthAnchor.constraint(equalToConstant: cornerViewMaxSize).isActive = true
        /////////////////////////////////////////////////////////////////////////////////////////////////////////
        if shouldDisplayThinBorders {
            let leftBorderView = self.createCornerView()
            leftBorderView.leftAnchor.constraint(equalTo: topLeftVCorner.leftAnchor).isActive = true
            leftBorderView.topAnchor.constraint(equalTo: topLeftVCorner.bottomAnchor).isActive = true
            leftBorderView.bottomAnchor.constraint(equalTo: bottomLeftVCorner.topAnchor).isActive = true
            leftBorderView.widthAnchor.constraint(equalToConstant: borderViewSize).isActive = true
            
            let rightBorderView = self.createCornerView()
            rightBorderView.rightAnchor.constraint(equalTo: topRightVCorner.rightAnchor).isActive = true
            rightBorderView.topAnchor.constraint(equalTo: topRightVCorner.bottomAnchor).isActive = true
            rightBorderView.bottomAnchor.constraint(equalTo: bottomRightVCorner.topAnchor).isActive = true
            rightBorderView.widthAnchor.constraint(equalToConstant: borderViewSize).isActive = true
            
            let topBorderView = self.createCornerView()
            topBorderView.leftAnchor.constraint(equalTo: topLeftHCorner.rightAnchor).isActive = true
            topBorderView.rightAnchor.constraint(equalTo: topRightHCorner.leftAnchor).isActive = true
            topBorderView.topAnchor.constraint(equalTo: topLeftHCorner.topAnchor).isActive = true
            topBorderView.heightAnchor.constraint(equalToConstant: borderViewSize).isActive = true
            
            let bottomBorderView = self.createCornerView()
            bottomBorderView.leftAnchor.constraint(equalTo: bottomLeftHCorner.rightAnchor).isActive = true
            bottomBorderView.rightAnchor.constraint(equalTo: bottomRightHCorner.leftAnchor).isActive = true
            bottomBorderView.bottomAnchor.constraint(equalTo: bottomLeftHCorner.bottomAnchor).isActive = true
            bottomBorderView.heightAnchor.constraint(equalToConstant: borderViewSize).isActive = true
        }
        /////////////////////////////////////////////////////////////////////////////////////////////////////////
        let leftShadowView = self.createShadowView()
        leftShadowView.rightAnchor.constraint(equalTo: topLeftVCorner.leftAnchor).isActive = true
        leftShadowView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        leftShadowView.heightAnchor.constraint(equalToConstant: 10000).isActive = true
        leftShadowView.widthAnchor.constraint(equalToConstant: 10000).isActive = true
        
        let rightShadowView = self.createShadowView()
        rightShadowView.leftAnchor.constraint(equalTo: topRightVCorner.rightAnchor).isActive = true
        rightShadowView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        rightShadowView.heightAnchor.constraint(equalTo: leftShadowView.heightAnchor).isActive = true
        rightShadowView.widthAnchor.constraint(equalTo: leftShadowView.widthAnchor).isActive = true
        
        let topShadowView = self.createShadowView()
        topShadowView.bottomAnchor.constraint(equalTo: topLeftHCorner.topAnchor).isActive = true
        topShadowView.rightAnchor.constraint(equalTo: rightShadowView.leftAnchor).isActive = true
        topShadowView.leftAnchor.constraint(equalTo: leftShadowView.rightAnchor).isActive = true
        topShadowView.heightAnchor.constraint(equalTo: leftShadowView.heightAnchor).isActive = true
        
        let bottomShadowView = self.createShadowView()
        bottomShadowView.topAnchor.constraint(equalTo: bottomLeftHCorner.bottomAnchor).isActive = true
        bottomShadowView.rightAnchor.constraint(equalTo: rightShadowView.leftAnchor).isActive = true
        bottomShadowView.leftAnchor.constraint(equalTo: leftShadowView.rightAnchor).isActive = true
        bottomShadowView.heightAnchor.constraint(equalTo: topShadowView.heightAnchor).isActive = true
        /////////////////////////////////////////////////////////////////////////////////////////////////////////
        if isResizingEnabled {
            let topLeftAnchorView = self.createAnchorView(withTag: CropMode.topLeft.rawValue, size: cornerAnchorSize)
            topLeftAnchorView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
            topLeftAnchorView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
            
            let topRightAnchorView = self.createAnchorView(withTag: CropMode.topRight.rawValue, size: cornerAnchorSize)
            topRightAnchorView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
            topRightAnchorView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
            
            let bottomLeftAnchorView = self.createAnchorView(withTag: CropMode.bottomLeft.rawValue, size: cornerAnchorSize)
            bottomLeftAnchorView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
            bottomLeftAnchorView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
            
            let bottomRightAnchorView = self.createAnchorView(withTag: CropMode.bottomRight.rawValue, size: cornerAnchorSize)
            bottomRightAnchorView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
            bottomRightAnchorView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        }
        if isMovingEnabled {
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture(_:)))
            self.addGestureRecognizer(panGestureRecognizer)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createServiceView(withColor color: UIColor) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = color
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)
        
        return view
    }
    private func createCornerView() -> UIView {
        return self.createServiceView(withColor: .white)
    }
    private func createShadowView() -> UIView {
        return self.createServiceView(withColor: UIColor.black.withAlphaComponent(0.5))
    }
    private func createAnchorView(withTag tag: Int, size: CGFloat) -> UIView {
        let anchorView = UIView()
        anchorView.translatesAutoresizingMaskIntoConstraints = false
        anchorView.tag = tag
        anchorView.widthAnchor.constraint(equalToConstant: size).isActive = true
        anchorView.heightAnchor.constraint(equalToConstant: size).isActive = true
        self.addSubview(anchorView)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleResizePanGesture(_:)))
        anchorView.addGestureRecognizer(panGestureRecognizer)
        
        return anchorView
    }
    
    @objc private func handleResizePanGesture(_ sender: UIPanGestureRecognizer) {
        guard let anchorView = sender.view else { return }
        guard let cropMode = CropMode(rawValue: anchorView.tag) else { return }
        
        switch sender.state {
        case .began, .changed:
            let translation = sender.translation(in: anchorView)
            let minSize = self.minSize
            let anchorInset = self.anchorInset
            let oldFrame = self.frame
            
            var newFrame = self.newFrame(translation: translation, cropViewFrame: oldFrame, cropMode: cropMode)
            newFrame.size = CGSize(width: max(newFrame.size.width, minSize.width + 2 * anchorInset), height: max(newFrame.size.height, minSize.height + 2 * anchorInset))
            
            self.delegate?.cropView(self, wantsToMoveTo: newFrame)
        default:
            break
        }
        sender.setTranslation(.zero, in: self)
    }
    
    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            let translation = sender.translation(in: self)
            self.delegate?.cropView(self, wantsToMoveBy: translation)
        default:
            break
        }
        sender.setTranslation(.zero, in: self)
    }
    
    private func newFrame(translation: CGPoint, cropViewFrame: CGRect, cropMode: CropMode) -> CGRect {
        func sizeForSaveAspectMode(rect: CGRect, translation: CGPoint) -> CGSize {
            let aspect = rect.width/rect.height
            let minTrans = min(translation.x, translation.y)
            let newTranslation = CGPoint(x: minTrans, y: aspect * minTrans)
            
            return CGSize(width: rect.width + newTranslation.y, height: rect.height + newTranslation.x)
        }
        
        func sizeForFreeMode(rect: CGRect, translation: CGPoint) -> CGSize {
            return CGSize(width: rect.width + translation.x, height: rect.height + translation.y)
        }
        
        switch cropMode {
        case .topLeft:
            let newTranslation = CGPoint(x: -translation.x, y: -translation.y)
            let result: (CGSize) -> CGRect = { newSize in
                return CGRect(origin: CGPoint(x: cropViewFrame.maxX - newSize.width, y: cropViewFrame.maxY - newSize.height), size: newSize)
            }
            switch self.resizingMode {
            case .saveAspectRatio:
                if (translation.x < 0 && translation.y < 0) || (translation.x > 0 && translation.y > 0) {
                    let newSize = sizeForSaveAspectMode(rect: cropViewFrame, translation: newTranslation)
                    return result(newSize)
                } else {
                    return cropViewFrame
                }
            case .free:
                let newSize = sizeForFreeMode(rect: cropViewFrame, translation: newTranslation)
                return result(newSize)
            }
            
        case .topRight:
            let newTranslation = CGPoint(x: translation.x, y: -translation.y)
            let result: (CGSize) -> CGRect = { newSize in
                return CGRect(origin: CGPoint(x: cropViewFrame.origin.x, y: cropViewFrame.maxY - newSize.height), size: newSize)
            }
            switch self.resizingMode {
            case .saveAspectRatio:
                if (translation.x > 0 && translation.y < 0) || (translation.x < 0 && translation.y > 0) {
                    let newSize = sizeForSaveAspectMode(rect: cropViewFrame, translation: newTranslation)
                    return result(newSize)
                } else {
                    return cropViewFrame
                }
            case .free:
                let newSize = sizeForFreeMode(rect: cropViewFrame, translation: newTranslation)
                return result(newSize)
            }
            
        case .bottomRight:
            let result: (CGSize) -> CGRect = { newSize in
                return CGRect(origin: cropViewFrame.origin, size: newSize)
            }
            switch self.resizingMode {
            case .saveAspectRatio:
                if (translation.x < 0 && translation.y < 0) || (translation.x > 0 && translation.y > 0) {
                    let newSize = sizeForSaveAspectMode(rect: cropViewFrame, translation: translation)
                    return result(newSize)
                } else {
                    return cropViewFrame
                }
            case .free:
                let newSize = sizeForFreeMode(rect: cropViewFrame, translation: translation)
                return result(newSize)
            }
            
        case .bottomLeft:
            let newTranslation = CGPoint(x: -translation.x, y: translation.y)
            let result: (CGSize) -> CGRect = { newSize in
                return CGRect(origin: CGPoint(x: cropViewFrame.maxX - newSize.width, y: cropViewFrame.origin.y), size: newSize)
            }
            switch self.resizingMode {
            case .saveAspectRatio:
                if (translation.x > 0 && translation.y < 0) || (translation.x < 0 && translation.y > 0) {
                    let newSize = sizeForSaveAspectMode(rect: cropViewFrame, translation: newTranslation)
                    return result(newSize)
                } else {
                    return cropViewFrame
                }
            case .free:
                let newSize = sizeForFreeMode(rect: cropViewFrame, translation: newTranslation)
                return result(newSize)
            }
        }
    }
}


public class NSKBackgroundView: UIView {
    public let contentView = UIView()
    
    public init() {
        super.init(frame: .zero)
        
        self.preservesSuperviewLayoutMargins = true
        self.contentView.preservesSuperviewLayoutMargins = true
        self.addSubview(self.contentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let frame: CGRect
        if let superview = self.superview {
            frame = superview.convert(superview.readableContentGuide.layoutFrame, to: self)
        } else {
            frame = self.bounds
        }
        self.contentView.frame = frame
    }
}

class NSKOpenSettingsView {
    private init() {}
    
    static func createOpenSettingsView(target: Any, action: Selector) -> UIView {
        let backgroundView = NSKBackgroundView()
        backgroundView.backgroundColor = UIColor(white: 0.2, alpha: 1)
        
        let centeredView = UIView()
        centeredView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: NSKResourceProvider.permissionsCameraImage)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        centeredView.addSubview(imageView)
        imageView.topAnchor.constraint(equalTo: centeredView.topAnchor).isActive = true
        imageView.centerXAnchor.constraint(equalTo: centeredView.centerXAnchor).isActive = true
        
        let topLabel = UILabel()
        topLabel.translatesAutoresizingMaskIntoConstraints = false
        topLabel.textAlignment = .center
        topLabel.textColor = .white
        topLabel.font = UIFont(name: "AppleSDGothicNeo-Light", size: 22)
        topLabel.text = "Camera Access Denied"
        centeredView.addSubview(topLabel)
        topLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16).isActive = true
        topLabel.leftAnchor.constraint(equalTo: centeredView.leftAnchor).isActive = true
        topLabel.rightAnchor.constraint(equalTo: centeredView.rightAnchor).isActive = true
        
        let bottomLabel = UILabel()
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomLabel.textColor = .lightGray
        bottomLabel.numberOfLines = 0
        bottomLabel.textAlignment = .center
        bottomLabel.font = UIFont(name: "AppleSDGothicNeo-Regular", size: 16)
        bottomLabel.text = "Please enable camera access in your privacy settings"
        centeredView.addSubview(bottomLabel)
        bottomLabel.topAnchor.constraint(equalTo: topLabel.bottomAnchor, constant: 10).isActive = true
        bottomLabel.leftAnchor.constraint(equalTo: centeredView.leftAnchor).isActive = true
        bottomLabel.rightAnchor.constraint(equalTo: centeredView.rightAnchor).isActive = true
        
        let settingsButton = UIButton(type: .system)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        settingsButton.setTitle("Settings", for: .normal)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.layer.cornerRadius = 4
        settingsButton.titleLabel?.font = UIFont(name: "AppleSDGothicNeo-Regular", size: 14)
        settingsButton.backgroundColor = UIColor(red: 52.0/255.0, green: 183.0/255.0, blue: 250.0/255.0, alpha: 1)
        settingsButton.addTarget(target, action: action, for: .touchUpInside)
        centeredView.addSubview(settingsButton)
        settingsButton.centerXAnchor.constraint(equalTo: centeredView.centerXAnchor).isActive = true
        settingsButton.topAnchor.constraint(equalTo: bottomLabel.bottomAnchor, constant: 16).isActive = true
        settingsButton.bottomAnchor.constraint(equalTo: centeredView.bottomAnchor).isActive = true
        
        let contentView = backgroundView.contentView
        contentView.addSubview(centeredView)
        centeredView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        centeredView.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        centeredView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        
        return backgroundView
    }
}
