//
//  NSKConfirmationController.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import Foundation
import UIKit


class NSKConfirmationController: UIViewController {
    struct Layout {
        private init() {}
        
        static let scrollViewTag = 101
        static let contentViewTag = 102
        static let imageViewTag = 103
        static let cropViewTag = 104
        
        
        static let centerXCropViewIdentifier = "cropView.center.x"
        static let centerYCropViewIdentifier = "cropView.center.y"
        static let widthCropViewIdentifier = "cropView.width"
        static let heightCropViewIdentifier = "cropView.height"
        static let aspectCropViewIdentifier = "cropView.aspect"
        
        static let cornerTouchSize: CGFloat = 44
    }
    
    let image: UIImage
    let isCroppingEnabled: Bool
    let isResizingEnabled: Bool
    typealias ResizingMode = NSKCameraController.ResizingMode
    let resizingMode: ResizingMode
    let minSize: CGSize
    let maxSize: CGSize?
    let commitBlock: (NSKConfirmationController, UIImage?) -> Void
    private var cropViewConstraints: [NSLayoutConstraint] = []
    private var verticalButtonsConstraints: [NSLayoutConstraint] = []
    private var horizontalButtonsConstraints: [NSLayoutConstraint] = []
    private var anchorInset: CGFloat { return 15 }
    
    init(image: UIImage, isCroppingEnabled: Bool, isResizingEnabled: Bool,
         resizingMode: ResizingMode, minSize: CGSize, maxSize: CGSize?,
         commitBlock: @escaping (NSKConfirmationController, UIImage?) -> Void) {
        self.image = image
        self.isCroppingEnabled = isCroppingEnabled
        self.isResizingEnabled = isResizingEnabled
        self.resizingMode = resizingMode
        self.minSize = minSize
        self.maxSize = maxSize
        self.commitBlock = commitBlock
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scrollView = UIScrollView()
        scrollView.tag = Layout.scrollViewTag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.delegate = self
        
        let contentView = UIView()
        contentView.tag = Layout.contentViewTag
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor).isActive = true
        contentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        
        let imageSize = self.image.size
        let imageView = UIImageView(image: self.image)
        imageView.tag = Layout.imageViewTag
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        imageView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor).isActive = true
        imageView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor).isActive = true
        
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: imageSize.width / imageSize.height).isActive = true
        imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        
        self.view.addSubview(scrollView)
        if #available(iOS 11.0, *) {
            let safeAreaLayoutGuide = self.view.safeAreaLayoutGuide
            scrollView.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor).isActive = true
            scrollView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor).isActive = true
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor).isActive = true
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else {
            scrollView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
            scrollView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
            scrollView.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true
            scrollView.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor).isActive = true
        }
        
        if self.isCroppingEnabled {
            let cropView = NSKCropView(isResizingEnabled: self.isResizingEnabled, isMovingEnabled: true,
                                       resizingMode: self.resizingMode, shouldDisplayThinBorders: true, minSize: self.minSize)
            cropView.delegate = self
            cropView.tag = Layout.cropViewTag
            cropView.translatesAutoresizingMaskIntoConstraints = false
            
            self.view.addSubview(cropView)
            let centerXAnchor = cropView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor)
            centerXAnchor.identifier = Layout.centerXCropViewIdentifier
            centerXAnchor.isActive = true
            let centerYAnchor = cropView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
            centerYAnchor.identifier = Layout.centerYCropViewIdentifier
            centerYAnchor.isActive = true
            
            let w1 = cropView.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -32)
            w1.identifier = Layout.widthCropViewIdentifier
            w1.isActive = true
            let w2 = cropView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
            w2.priority = .defaultHigh
            w2.identifier = w1.identifier
            w2.isActive = true
            
            let h1 = cropView.heightAnchor.constraint(lessThanOrEqualTo: scrollView.heightAnchor, constant: -32)
            h1.identifier = Layout.heightCropViewIdentifier
            h1.isActive = true
            let h2 = cropView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -32)
            h2.priority = w2.priority
            h2.identifier = h1.identifier
            h2.isActive = true
            
            let aspect = cropView.widthAnchor.constraint(equalTo: cropView.heightAnchor)
            aspect.identifier = Layout.aspectCropViewIdentifier
            aspect.isActive = true
            
            self.cropViewConstraints = [centerXAnchor, centerYAnchor, w1, w2, h1, h2, aspect]
        }
        
        
        let confirmButton = UIButton(type: .system)
        confirmButton.setImage(NSKResourceProvider.confirmImage, for: .normal)
        confirmButton.addTarget(self, action: #selector(self.confirmAction(_:)), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        
        let retakeButton = UIButton(type: .system)
        retakeButton.setImage(NSKResourceProvider.retakeImage, for: .normal)
        retakeButton.addTarget(self, action: #selector(self.retakeAction(_:)), for: .touchUpInside)
        retakeButton.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.addSubview(confirmButton)
        self.view.addSubview(retakeButton)
        
        let bottomInset: CGFloat = 30
        let hShift: CGFloat = 60
        let layoutMarginsGuide = self.view.layoutMarginsGuide
        
        if #available(iOS 11.0, *) {
            let safeAreaLayoutGuide = self.view.safeAreaLayoutGuide
            self.verticalButtonsConstraints = [
                confirmButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -bottomInset),
                confirmButton.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor, constant: -hShift),
                retakeButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -bottomInset),
                retakeButton.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor, constant: hShift)
            ]
            self.horizontalButtonsConstraints = [
                confirmButton.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor),
                confirmButton.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor, constant: -hShift),
                retakeButton.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor),
                retakeButton.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor, constant: hShift)
            ]
        } else {
            self.verticalButtonsConstraints = [
                confirmButton.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor, constant: -bottomInset),
                confirmButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor, constant: -hShift),
                retakeButton.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor, constant: -bottomInset),
                retakeButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor, constant: hShift)
            ]
            self.horizontalButtonsConstraints = [
                confirmButton.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor),
                confirmButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -hShift),
                retakeButton.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor),
                retakeButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: hShift)
            ]
        }
        
        let bounds = self.view.bounds
        let isHorizontal = bounds.width > bounds.height
        if isHorizontal {
            NSLayoutConstraint.activate(self.horizontalButtonsConstraints)
        } else {
            NSLayoutConstraint.activate(self.verticalButtonsConstraints)
        }
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let isHorizontal = size.width > size.height
        coordinator.animate(alongsideTransition: { (c) in
            if isHorizontal {
                NSLayoutConstraint.activate(self.horizontalButtonsConstraints)
                NSLayoutConstraint.deactivate(self.verticalButtonsConstraints)
            } else {
                NSLayoutConstraint.activate(self.verticalButtonsConstraints)
                NSLayoutConstraint.deactivate(self.horizontalButtonsConstraints)
            }
        },
                            completion: nil)
    }
    
    private func makeProportionalCropRect() -> CGRect {
        guard let scrollView = self.view.viewWithTag(Layout.scrollViewTag) else {
            return .zero
        }
        guard let contentView = scrollView.viewWithTag(Layout.contentViewTag) else {
            return .zero
        }
        guard let imageView = contentView.viewWithTag(Layout.imageViewTag) else {
            return .zero
        }
        guard let cropView = self.view.viewWithTag(Layout.cropViewTag) else {
            return .zero
        }
        let anchorInset = self.anchorInset
        let adjustedRect = cropView.frame.inset(by: UIEdgeInsets(top: anchorInset, left: anchorInset, bottom: anchorInset, right: anchorInset))
        
        let cropRectInScrollView = self.view.convert(adjustedRect, to: scrollView)
        let cropRectInContentView = scrollView.convert(cropRectInScrollView, to: contentView)
        let cropRect = contentView.convert(cropRectInContentView, to: imageView)
        
        let normalizedX = max(0, cropRect.origin.x / imageView.frame.width)
        let normalizedY = max(0, cropRect.origin.y / imageView.frame.height)
        
        let extraWidth = min(0, cropRect.origin.x)
        let extraHeight = min(0, cropRect.origin.y)
        
        let normalizedWidth = min(1, (cropRect.width + extraWidth) / imageView.frame.width)
        let normalizedHeight = min(1, (cropRect.height + extraHeight) / imageView.frame.height)
        
        return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }
    
    @objc private func confirmAction(_ sender: UIButton) {
        let cropRect: CGRect
        if self.isCroppingEnabled {
            cropRect = self.makeProportionalCropRect()
        } else {
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        let imageSize = self.image.size
        let size = CGSize(width: imageSize.width * cropRect.width, height: imageSize.height * cropRect.height)
        
        let resizedCropRect = CGRect(x: imageSize.width * cropRect.origin.x,
                                     y: imageSize.height * cropRect.origin.y,
                                     width: size.width,
                                     height: size.height)
        
        let newImage = self.image.crop(rect: resizedCropRect, maximumSize: self.maxSize)
        self.commitBlock(self, newImage)
    }
    
    @objc private func retakeAction(_ sender: UIButton) {
        self.commitBlock(self, nil)
    }
}

extension NSKConfirmationController: NSKCropViewDelegate {
    func cropView(_ cropView: NSKCropView, wantsToMoveTo newFrame: CGRect) {
        let oldFrame = cropView.frame
        for cropViewConstraint in self.cropViewConstraints {
            let diff: CGFloat
            switch cropViewConstraint.identifier {
            case Layout.centerXCropViewIdentifier:
                diff = newFrame.midX - oldFrame.midX
            case Layout.centerYCropViewIdentifier:
                diff = newFrame.midY - oldFrame.midY
            case Layout.widthCropViewIdentifier:
                diff = newFrame.width - oldFrame.width
            case Layout.heightCropViewIdentifier:
                diff = newFrame.height - oldFrame.height
            default:
                continue
            }
            cropViewConstraint.constant += diff
        }
        if let firstIndex = self.cropViewConstraints.firstIndex(where: { (c) -> Bool in
            c.identifier == Layout.aspectCropViewIdentifier
        }) {
            self.cropViewConstraints.remove(at: firstIndex).isActive = false
            let newAspect = cropView.widthAnchor.constraint(equalTo: cropView.heightAnchor, multiplier: newFrame.width / newFrame.height)
            newAspect.identifier = Layout.aspectCropViewIdentifier
            newAspect.isActive = true
            self.cropViewConstraints.append(newAspect)
        }
    }
    
    func cropView(_ cropView: NSKCropView, wantsToMoveBy translation: CGPoint) {
        for cropViewConstraint in self.cropViewConstraints {
            let diff: CGFloat
            switch cropViewConstraint.identifier {
            case Layout.centerXCropViewIdentifier:
                diff = translation.x
            case Layout.centerYCropViewIdentifier:
                diff = translation.y
            default:
                continue
            }
            cropViewConstraint.constant += diff
        }
    }
}

extension NSKConfirmationController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.viewWithTag(Layout.contentViewTag)
    }
}
