Pod::Spec.new do |spec|
  spec.name               = "NSKCameraController"
  spec.version            = "0.1"
  spec.summary            = "A camera view controller with custom image picker and image cropping."
  spec.source             = { :git => "https://github.com/NSSimpleApps/NSKCameraController", :tag => spec.version.to_s }
  spec.platform           = :ios, "10.0"
  spec.license            = "MIT"
  spec.swift_versions     = "5.2"
  spec.source_files       = "NSKCameraController/NSKCameraController/*.{swift}"
  spec.resources          = ["NSKCameraController/NSKCameraController/Media.xcassets"]
  spec.homepage           = "https://github.com/NSSimpleApps/NSKCameraController"
  spec.author             = { 'NSSimpleApps, Sergey Poluyanov' => 'ns.simple.apps@gmail.com' }
end
