# NSKCameraController
A camera view controller with custom image picker and image cropping.

Installation: place this into `Podfile`
```
use_frameworks!
target 'Target' do
    pod 'NSKCameraController'
end
```

Usage:
```objc
import NSKCameraController

let cameraController = NSKCameraController(source: .camera | .photoLibrary, options: [
                                                                     .isCroppingEnabled(Bool),
                                                                     .isResizingEnabled(Bool),
                                                                     .isConfirmationRequired(Bool),
                                                                     .limits(self.settings.limits),
                                                                     .resizingMode(.free | .saveAspectRatio),
                                                                     .numberOfPhotos(.single | .multiply(Int, String)),
                                                                     .accentColor(.red),
                                                                     .videoMaximumDuration(TimeInterval),
                                                                     .tipString(String),
                                                                     .maxNumberOfVideos(Int),
                                                                     ],
                                                     commitBlock: { [weak self] (imagePickerController, result) in
                                                        switch result {
                                                        case .image(let image):
                                                            break
                                                        case .images(let images):
                                                            break
                                                        case.cancelled:
                                                            break
                                                        case .error(let error):
                                                            break
                                                        }
                                                })
self.present(cameraController, animated: true, completion: nil)

```
