//
//  ViewController.swift
//  NSKCameraControllerTest
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import NSKCameraController

class ViewController: UIViewController {
    var settings = Settings()
    var images: [UIImage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        let photoLibraryButton = UIBarButtonItem(title: "Library", style: .plain, target: self, action: #selector(self.presentPhotoLibrary(_:)))
        let settingsButton = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(self.settingsAction(_:)))
        self.navigationItem.rightBarButtonItems = [settingsButton, photoLibraryButton]
        
        let cameraButton = UIBarButtonItem(title: "Camera", style: .plain, target: self, action: #selector(self.presentCamera(_:)))
        self.navigationItem.leftBarButtonItem = cameraButton
    }
    
    @objc func presentPhotoLibrary(_ sender: UIBarButtonItem) {
        self.presentImagePicker(source: .photoLibrary)
    }
    
    @objc func presentCamera(_ sender: UIBarButtonItem) {
        self.presentImagePicker(source: .camera)
    }
    
    private func presentImagePicker(source: NSKCameraController.Source) {
        let cameraController = NSKCameraController(source: source, options: [.isCroppingEnabled(self.settings.isCroppingEnabled),
                                                                             .isResizingEnabled(self.settings.isResizingEnabled),
                                                                             .isConfirmationRequired(self.settings.isConfirmationRequired),
                                                                             .limits(self.settings.limits),
                                                                             .resizingMode(self.settings.resizingMode),
                                                                             .numberOfPhotos(self.settings.numberOfPhotos),
                                                                             .accentColor(.red)],
                                                             commitBlock: { [weak self] (imagePickerController, result) in
                                                                guard let sSelf = self else {
                                                                    imagePickerController.dismiss(animated: false, completion: nil)
                                                                    return
                                                                }
                                                                imagePickerController.dismiss(animated: true, completion: {
                                                                    let view = sSelf.view!
                                                                    for subview in view.subviews {
                                                                        subview.removeFromSuperview()
                                                                    }
                                                                    sSelf.images.removeAll()
                                                                    
                                                                    switch result {
                                                                    case .image(let image):
                                                                        let imageView = UIImageView()
                                                                        imageView.contentMode = .scaleAspectFit
                                                                        view.addSubview(imageView)
                                                                        imageView.translatesAutoresizingMaskIntoConstraints = false
                                                                        imageView.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor).isActive = true
                                                                        imageView.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor).isActive = true
                                                                        imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                                                                        imageView.image = image
                                                                    case .images(let images):
                                                                        sSelf.images = images
                                                                        let tableView = UITableView(frame: .zero, style: .grouped)
                                                                        tableView.register(ImageCell.self, forCellReuseIdentifier: "ImageCell")
                                                                        tableView.translatesAutoresizingMaskIntoConstraints = false
                                                                        tableView.delegate = sSelf
                                                                        tableView.dataSource = sSelf 
                                                                        view.addSubview(tableView)
                                                                        if #available(iOS 11.0, *) {
                                                                            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
                                                                            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
                                                                        } else {
                                                                            tableView.topAnchor.constraint(equalTo: sSelf.topLayoutGuide.bottomAnchor).isActive = true
                                                                            tableView.topAnchor.constraint(equalTo: sSelf.bottomLayoutGuide.topAnchor).isActive = true
                                                                        }
                                                                        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
                                                                        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
                                                                    case.cancelled:
                                                                        let label = UILabel()
                                                                        label.textAlignment = .center
                                                                        label.text = "CANCELLED"
                                                                        label.translatesAutoresizingMaskIntoConstraints = false
                                                                        view.addSubview(label)
                                                                        label.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor).isActive = true
                                                                        label.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor).isActive = true
                                                                        label.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
                                                                    case .error(let error):
                                                                        let ac = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                                                                        ac.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
                                                                        sSelf.present(ac, animated: true, completion: nil)
                                                                    }
                                                                })
        })
        self.present(cameraController, animated: true, completion: nil)
    }
    
    @objc func settingsAction(_ sender: UIBarButtonItem) {
        let settingsController = SettingsController(settings: self.settings, commitBlock: { (settingsController, newSettings) in
            self.settings = newSettings
            settingsController.dismiss(animated: true, completion: nil)
        })
        let nc = UINavigationController(rootViewController: settingsController)
        nc.modalPresentationStyle = .fullScreen
        self.present(nc, animated: true, completion: nil)
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let size = self.images[indexPath.section].size
        
        return tableView.bounds.width * (size.height / size.width)
    }
}
extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.images.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let image = self.images[indexPath.section]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCell", for: indexPath) as! ImageCell
        cell.mainImageView.image = image
        
        return cell
    }
}

class ImageCell: UITableViewCell {
    let mainImageView = UIImageView()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        
        self.mainImageView.contentMode = .scaleAspectFit
        self.mainImageView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.mainImageView)
        self.mainImageView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor).isActive = true
        self.mainImageView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor).isActive = true
        self.mainImageView.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        self.mainImageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


struct Settings {
    var isCroppingEnabled: Bool// = true
    var isResizingEnabled: Bool// = true
    var isConfirmationRequired: Bool// = true
    
    var limits: NSKCameraController.Limits
    
    var resizingMode: NSKCameraController.ResizingMode//.free
    var numberOfPhotos: NSKCameraController.NumberOfPhotos//.single
    
    init() {
        self.isCroppingEnabled = true
        self.isResizingEnabled = true
        self.isConfirmationRequired = true
        
        self.limits = NSKCameraController.Limits()
        
        self.resizingMode = .free
        self.numberOfPhotos = .single
    }
}

class SettingsController: UIViewController {
    private var settings: Settings
    private let initialSettings: Settings
    
    private var currentNumberOfPhotos = 1
    private var currentButtonTitle = ""
    
    let commitBlock: (SettingsController, Settings) -> Void
    
    init(settings: Settings, commitBlock: @escaping (SettingsController, Settings) -> Void) {
        self.settings = settings
        self.initialSettings = settings
        self.commitBlock = commitBlock
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.saveAction(_:)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelAction(_:)))
        
        self.view.backgroundColor = .white
        let layoutMarginsGuide = self.view.layoutMarginsGuide
        let topAnchor: NSLayoutYAxisAnchor
        if #available(iOS 11.0, *) {
            topAnchor = self.view.safeAreaLayoutGuide.topAnchor
        } else {
            topAnchor = self.topLayoutGuide.bottomAnchor
        }
        
        let numberOfPhotosControl = UISegmentedControl(items: ["SINGLE", "MILTIPLY"])
        numberOfPhotosControl.translatesAutoresizingMaskIntoConstraints = false
        let multiPhotoView: MultiPhotoView
        switch self.settings.numberOfPhotos {
        case .single:
            numberOfPhotosControl.selectedSegmentIndex = 0
            multiPhotoView = MultiPhotoView(numberOfPhotos: 1, buttonTitle: "", target: self,
                                            numberOfPhotosAction: #selector(self.numberOfPhotosAction(_:)),
                                            buttonTitleAction: #selector(self.buttonTitleAction(_:)))
            multiPhotoView.alpha = 0.5
            multiPhotoView.isUserInteractionEnabled = false
        case .multiply(let maxNumber, let buttonTitle):
            self.currentNumberOfPhotos = maxNumber
            self.currentButtonTitle = buttonTitle
            numberOfPhotosControl.selectedSegmentIndex = 1
            multiPhotoView = MultiPhotoView(numberOfPhotos: maxNumber, buttonTitle: buttonTitle, target: self,
                                            numberOfPhotosAction: #selector(self.numberOfPhotosAction(_:)),
                                            buttonTitleAction: #selector(self.buttonTitleAction(_:)))
        }
        numberOfPhotosControl.tag = 2000
        multiPhotoView.tag = numberOfPhotosControl.tag + 1
        multiPhotoView.translatesAutoresizingMaskIntoConstraints = false
        
        numberOfPhotosControl.addTarget(self, action: #selector(self.handleNumberOfPhotosAction(_:)), for: .valueChanged)
        self.view.addSubview(numberOfPhotosControl)
        self.view.addSubview(multiPhotoView)
        
        numberOfPhotosControl.topAnchor.constraint(equalTo: topAnchor).isActive = true
        numberOfPhotosControl.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        
        multiPhotoView.topAnchor.constraint(equalTo: numberOfPhotosControl.bottomAnchor, constant: 30).isActive = true
        multiPhotoView.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor).isActive = true
        multiPhotoView.rightAnchor.constraint(equalTo: layoutMarginsGuide.rightAnchor).isActive = true
        
        let isCroppingEnabledSwitcher = self.configureLabelSwitch(labelTitle: "isCroppingEnabled",
                                                                  topAnchor: multiPhotoView.bottomAnchor, leftAnchor: layoutMarginsGuide.leftAnchor,
                                                                  rightAnchor: layoutMarginsGuide.rightAnchor, isOn: self.settings.isCroppingEnabled,
                                                                  action: #selector(self.isCroppingEnabledAction(_:)))
        
        let isResizingEnabledSwitcher = self.configureLabelSwitch(labelTitle: "isResizingEnabled",
                                                                  topAnchor: isCroppingEnabledSwitcher.bottomAnchor, leftAnchor: layoutMarginsGuide.leftAnchor,
                                                                  rightAnchor: layoutMarginsGuide.rightAnchor, isOn: self.settings.isResizingEnabled,
                                                                  action: #selector(self.isResizingEnabledAction(_:)))
        
        let isConfirmationRequiredSwitcher = self.configureLabelSwitch(labelTitle: "isConfirmationRequired",
                                                                       topAnchor: isResizingEnabledSwitcher.bottomAnchor, leftAnchor: layoutMarginsGuide.leftAnchor,
                                                                       rightAnchor: layoutMarginsGuide.rightAnchor, isOn: self.settings.isConfirmationRequired,
                                                                       action: #selector(self.isConfirmationRequiredAction(_:)))
        
        let limits = self.settings.limits
        let minimumSize = limits.minSize
        let minSizeSliderView = SliderView(title: "MIN SIZE", width: minimumSize.width, widthAction: #selector(self.handleMinWidthChange(_:)),
                                           height: minimumSize.height, heightAction: #selector(self.handleMinHeightChange(_:)),
                                           target: self)
        minSizeSliderView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(minSizeSliderView)
        minSizeSliderView.topAnchor.constraint(equalTo: isConfirmationRequiredSwitcher.bottomAnchor, constant: 20).isActive = true
        minSizeSliderView.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor).isActive = true
        minSizeSliderView.rightAnchor.constraint(equalTo: layoutMarginsGuide.rightAnchor).isActive = true
        
        let maxSize = limits.maxSize
        let isOn = maxSize != nil
        let maxSizeSwitcher = self.configureLabelSwitch(labelTitle: "TOP LIMIT MAX SIZE",
                                                        topAnchor: minSizeSliderView.bottomAnchor,
                                                        leftAnchor: layoutMarginsGuide.leftAnchor,
                                                        rightAnchor: layoutMarginsGuide.rightAnchor,
                                                        isOn: isOn,
                                                        action: #selector(self.maxSizeLimitAction(_:)))
        maxSizeSwitcher.tag = 1000
        let width = maxSize?.width ?? 0
        let height = maxSize?.height ?? 0
        let maxSizeSliderView = SliderView(title: "MAX SIZE", width: width, widthAction: #selector(self.handleMaxWidthChange(_:)),
                                           height: height, heightAction: #selector(self.handleMaxHeightChange(_:)),
                                           target: self)
        maxSizeSliderView.isUserInteractionEnabled = false
        maxSizeSliderView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(maxSizeSliderView)
        maxSizeSliderView.topAnchor.constraint(equalTo: maxSizeSwitcher.bottomAnchor, constant: 20).isActive = true
        maxSizeSliderView.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor).isActive = true
        maxSizeSliderView.rightAnchor.constraint(equalTo: layoutMarginsGuide.rightAnchor).isActive = true
        maxSizeSliderView.tag = maxSizeSwitcher.tag + 1
        maxSizeSliderView.isUserInteractionEnabled = isOn
        maxSizeSliderView.alpha = isOn ? 1 : 0.5
        
        let resizingModeControl = UISegmentedControl(items: ["FREE", "SAVE ASPECT"])
        resizingModeControl.translatesAutoresizingMaskIntoConstraints = false
        switch self.settings.resizingMode {
        case .free:
            resizingModeControl.selectedSegmentIndex = 0
        case .saveAspectRatio:
            resizingModeControl.selectedSegmentIndex = 1
        }
        resizingModeControl.addTarget(self, action: #selector(self.handleResizingModeAction(_:)), for: .valueChanged)
        self.view.addSubview(resizingModeControl)
        resizingModeControl.topAnchor.constraint(equalTo: maxSizeSliderView.bottomAnchor).isActive = true
        resizingModeControl.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
    }
    
    private func configureLabelSwitch(labelTitle: String,
                                      topAnchor: NSLayoutYAxisAnchor,
                                      leftAnchor: NSLayoutXAxisAnchor, rightAnchor: NSLayoutXAxisAnchor,
                                      isOn: Bool, action: Selector) -> UISwitch {
        let label = UILabel()
        label.text = labelTitle
        label.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(label)
        label.topAnchor.constraint(equalTo: topAnchor).isActive = true
        label.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        let switcher = UISwitch()
        switcher.isOn = isOn
        switcher.translatesAutoresizingMaskIntoConstraints = false
        switcher.addTarget(self, action: action, for: .valueChanged)
        self.view.addSubview(switcher)
        switcher.topAnchor.constraint(equalTo: label.topAnchor).isActive = true
        switcher.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        return switcher
    }
    
    @objc func isCroppingEnabledAction(_ sender: UISwitch) {
        self.settings.isCroppingEnabled = sender.isOn
    }
    @objc func isResizingEnabledAction(_ sender: UISwitch) {
        self.settings.isResizingEnabled = sender.isOn
    }
    @objc func isConfirmationRequiredAction(_ sender: UISwitch) {
        self.settings.isConfirmationRequired = sender.isOn
    }
    
    @objc func handleMinWidthChange(_ sender: UISlider) {
        var minSize = self.settings.limits.minSize
        minSize.width = CGFloat(sender.value)
        
        self.settings.limits = NSKCameraController.Limits(minSize: minSize, maxSize: self.settings.limits.maxSize)
    }
    @objc func handleMinHeightChange(_ sender: UISlider) {
        var minSize = self.settings.limits.minSize
        minSize.height = CGFloat(sender.value)
        
        self.settings.limits = NSKCameraController.Limits(minSize: minSize, maxSize: self.settings.limits.maxSize)
    }
    @objc func handleMaxWidthChange(_ sender: UISlider) {
        if var maxSize = self.settings.limits.maxSize {
            maxSize.width = CGFloat(sender.value)
            self.settings.limits = NSKCameraController.Limits(minSize: self.settings.limits.minSize, maxSize: maxSize)
        }
    }
    @objc func handleMaxHeightChange(_ sender: UISlider) {
        if var maxSize = self.settings.limits.maxSize {
            maxSize.height = CGFloat(sender.value)
            self.settings.limits = NSKCameraController.Limits(minSize: self.settings.limits.minSize, maxSize: maxSize)
        }
    }
    @objc func maxSizeLimitAction(_ sender: UISwitch) {
        if let maxSizeSliderView = self.view.viewWithTag(sender.tag + 1) {
            let isOn = sender.isOn
            maxSizeSliderView.isUserInteractionEnabled = isOn
            maxSizeSliderView.alpha = isOn ? 1 : 0.5
        }
    }
    
    @objc func handleResizingModeAction(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.settings.resizingMode = .free
        case 1:
            self.settings.resizingMode = .saveAspectRatio
        default:
            break
        }
    }
    
    @objc func handleNumberOfPhotosAction(_ sender: UISegmentedControl) {
        guard let multiPhotoView = self.view.viewWithTag(sender.tag + 1) else { return }
        
        switch sender.selectedSegmentIndex {
        case 0:
            self.settings.numberOfPhotos = .single
            multiPhotoView.isUserInteractionEnabled = false
            multiPhotoView.alpha = 0.5
        case 1:
            self.settings.numberOfPhotos = .multiply(self.currentNumberOfPhotos, self.currentButtonTitle)
            multiPhotoView.isUserInteractionEnabled = true
            multiPhotoView.alpha = 1
        default:
            break
        }
    }
    
    @objc func numberOfPhotosAction(_ sender: UISlider) {
        switch self.settings.numberOfPhotos {
        case .multiply(_, let title):
            let value = Int(exactly: ceil(sender.value)) ?? 0
            self.currentNumberOfPhotos = value
            self.settings.numberOfPhotos = .multiply(value, title)
        default:
            break
        }
    }
    @objc func buttonTitleAction(_ sender: UITextField) {
        switch self.settings.numberOfPhotos {
        case .multiply(let maxNumberOfPhotos, _):
            let title = sender.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            self.currentButtonTitle = title
            self.settings.numberOfPhotos = .multiply(maxNumberOfPhotos, title)
        default:
            break
        }
    }
    
    @objc func saveAction(_ sender: UIBarButtonItem) {
        self.commitBlock(self, self.settings)
    }
    @objc func cancelAction(_ sender: UIBarButtonItem) {
        self.commitBlock(self, self.initialSettings)
    }
}

class SliderView: UIView {
    init(title: String, width: CGFloat, widthAction: Selector,
         height: CGFloat, heightAction: Selector,
         target: Any) {
        super.init(frame: .zero)
        
        let titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.text = title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(titleLabel)
        titleLabel.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        titleLabel.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        titleLabel.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        
        let widthSlider = UISlider()
        widthSlider.tag = 101
        widthSlider.minimumValue = 0
        widthSlider.maximumValue = 1000
        widthSlider.value = Float(width)
        widthSlider.translatesAutoresizingMaskIntoConstraints = false
        widthSlider.addTarget(target, action: widthAction, for: .valueChanged)
        widthSlider.addTarget(self, action: #selector(self.handleWidthChange(_:)), for: .valueChanged)
        self.addSubview(widthSlider)
        widthSlider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor).isActive = true
        widthSlider.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        widthSlider.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        let widthLabel = UILabel()
        widthLabel.tag = widthSlider.tag + 1
        widthLabel.text = self.widthText(from: widthSlider.value)
        widthLabel.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        widthLabel.setContentCompressionResistancePriority(.required + 1, for: .horizontal)
        widthLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(widthLabel)
        widthLabel.centerYAnchor.constraint(equalTo: widthSlider.centerYAnchor).isActive = true
        widthLabel.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        
        widthSlider.leftAnchor.constraint(equalTo: widthLabel.rightAnchor, constant: 20).isActive = true
        
        let heightSlider = UISlider()
        heightSlider.tag = 102
        heightSlider.minimumValue = 0
        heightSlider.maximumValue = 1000
        heightSlider.value = Float(height)
        heightSlider.translatesAutoresizingMaskIntoConstraints = false
        heightSlider.addTarget(target, action: heightAction, for: .valueChanged)
        heightSlider.addTarget(self, action: #selector(self.handleHeightChange(_:)), for: .valueChanged)
        self.addSubview(heightSlider)
        heightSlider.topAnchor.constraint(equalTo: widthSlider.bottomAnchor).isActive = true
        heightSlider.rightAnchor.constraint(equalTo: widthSlider.rightAnchor).isActive = true
        heightSlider.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        heightSlider.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let heightLabel = UILabel()
        heightLabel.tag = heightSlider.tag + 1
        heightLabel.text = self.heightText(from: heightSlider.value)
        heightLabel.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        heightLabel.setContentCompressionResistancePriority(.required + 1, for: .horizontal)
        heightLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(heightLabel)
        heightLabel.centerYAnchor.constraint(equalTo: heightSlider.centerYAnchor).isActive = true
        heightLabel.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true

        heightSlider.leftAnchor.constraint(equalTo: heightLabel.rightAnchor, constant: 20).isActive = true
    }
    private func widthText(from width: Float) -> String {
        return "W: " + String(Int(exactly: ceil(width)) ?? 0)
    }
    private func heightText(from height: Float) -> String {
        return "H: " + String(Int(exactly: ceil(height)) ?? 0)
    }
    
    @objc func handleWidthChange(_ sender: UISlider) {
        if let label = self.viewWithTag(sender.tag + 1) as? UILabel {
            label.text = self.widthText(from: sender.value)
        }
    }
    @objc func handleHeightChange(_ sender: UISlider) {
        if let label = self.viewWithTag(sender.tag + 1) as? UILabel {
            label.text = self.heightText(from: sender.value)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MultiPhotoView: UIView {
    init(numberOfPhotos: Int, buttonTitle: String, target: Any, numberOfPhotosAction: Selector, buttonTitleAction: Selector) {
        super.init(frame: .zero)
        
        let numberSlider = UISlider()
        numberSlider.tag = 101
        numberSlider.minimumValue = 1
        numberSlider.maximumValue = 100
        numberSlider.value = Float(numberOfPhotos)
        numberSlider.translatesAutoresizingMaskIntoConstraints = false
        numberSlider.addTarget(target, action: numberOfPhotosAction, for: .valueChanged)
        numberSlider.addTarget(self, action: #selector(self.handleNumberOfPhotosChange(_:)), for: .valueChanged)
        self.addSubview(numberSlider)
        numberSlider.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        numberSlider.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        numberSlider.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        let numberLabel = UILabel()
        numberLabel.tag = numberSlider.tag + 1
        numberLabel.text = String(numberOfPhotos)
        numberLabel.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        numberLabel.setContentCompressionResistancePriority(.required + 1, for: .horizontal)
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(numberLabel)
        numberLabel.centerYAnchor.constraint(equalTo: numberSlider.centerYAnchor).isActive = true
        numberLabel.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        
        numberSlider.leftAnchor.constraint(equalTo: numberLabel.rightAnchor, constant: 20).isActive = true
        
        let titleTextField = UITextField()
        titleTextField.returnKeyType = .done
        titleTextField.borderStyle = .roundedRect
        titleTextField.delegate = self
        titleTextField.placeholder = "Button Title"
        titleTextField.text = buttonTitle
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.addTarget(target, action: buttonTitleAction, for: .editingChanged)
        self.addSubview(titleTextField)
        titleTextField.topAnchor.constraint(equalTo: numberSlider.bottomAnchor).isActive = true
        titleTextField.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        titleTextField.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        titleTextField.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func handleNumberOfPhotosChange(_ sender: UISlider) {
        if let label = self.viewWithTag(sender.tag + 1) as? UILabel {
            label.text = String(Int(ceil(sender.value)))
        }
    }
}
extension MultiPhotoView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
