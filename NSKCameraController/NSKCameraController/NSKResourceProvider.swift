//
//  NSKResourceProvider.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit


class NSKResourceProvider {
    private init() {}
    
    static var cancelImage: UIImage? {
        return UIImage(named: "cancel", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var confirmImage: UIImage? {
        return UIImage(named: "confirm", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var retakeImage: UIImage? {
        return UIImage(named: "retake", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var shadowBorderImage: UIImage? {
        return UIImage(named: "shadow_border", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var permissionsCameraImage: UIImage? {
        return UIImage(named: "permissions-camera", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var swapCameraImage: UIImage? {
        return UIImage(named: "swap-camera-button", in: Bundle(for: self.self), compatibleWith: nil)
    }
    
    static var flashAutoImage: UIImage? {
        return UIImage(named: "flash-auto", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var flashOnImage: UIImage? {
        return UIImage(named: "flash-on", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var flashOffImage: UIImage? {
        return UIImage(named: "flash-off", in: Bundle(for: self.self), compatibleWith: nil)
    }
    
    static var captureButton: UIImage? {
        return UIImage(named: "capture-button", in: Bundle(for: self.self), compatibleWith: nil)
    }
    static var captureButtonHighlighted: UIImage? {
        return UIImage(named: "capture-button-highlighted", in: Bundle(for: self.self), compatibleWith: nil)
    }
}
