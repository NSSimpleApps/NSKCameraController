//
//  ViewController.swift
//  NSKCameraControllerTest
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import AVKit
import NSKCameraController

class ViewController: UIViewController {
    struct Image {
        let image: UIImage
        //let byteCount: Int // 0, если это просто изображение
        let data: Data?
    }
    var settings = Settings()
    var images: [Image] = []
    
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
        self.presentImagePicker(source: .photoLibrary(self.settings.mediaType))
    }
    
    @objc func presentCamera(_ sender: UIBarButtonItem) {
        self.presentImagePicker(source: .camera(self.settings.mediaType))
    }
    
    private func presentImagePicker(source: NSKCameraController.Source) {
        let cameraController = NSKCameraController(source: source, options: [.isCroppingEnabled(self.settings.isCroppingEnabled),
                                                                             .isResizingEnabled(self.settings.isResizingEnabled),
                                                                             .isConfirmationRequired(self.settings.isConfirmationRequired),
                                                                             .limits(self.settings.limits),
                                                                             .resizingMode(self.settings.resizingMode),
                                                                             .numberOfAttachments(self.settings.numberOfAttachments),
                                                                             .accentColor(.red),
                                                                             .videoMaximumDuration(self.settings.videoMaximumDuration),
                                                                             .tipString("Hold to record")],
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
                                                                    case .result(let media):
                                                                        sSelf.handle(media: [media])
                                                                    case .results(let media):
                                                                        sSelf.handle(media: media)
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
                                                                        print(error)
                                                                        let ac = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                                                                        ac.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
                                                                        sSelf.present(ac, animated: true, completion: nil)
                                                                    }
                                                                })
        })
        self.present(cameraController, animated: true, completion: nil)
    }
    
    private func handle(media: [NSKCameraController.ImagePickerResult.Media]) {
        self.images = media.map { (media) -> Image in
            switch media {
            case .image(let image):
                return Image(image: image, data: nil)
            case .video(let image, let data):
                return Image(image: image, data: data)
            }
        }
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(ImageCell.self, forCellReuseIdentifier: "ImageCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
        if #available(iOS 11.0, *) {
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else {
            tableView.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true
            tableView.topAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor).isActive = true
        }
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
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
        let size = self.images[indexPath.section].image.size
        
        return tableView.bounds.width * (size.height / size.width)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let image = self.images[indexPath.section]
        
        if let data = image.data, let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = documentDirectory.appendingPathComponent("test.mp4")
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print(error)
            }
            do {
                try data.write(to: url)
                let player = AVPlayer(url: url)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                
                self.present(playerViewController, animated: true, completion: nil)
            } catch {
                print(error)
            }
        }
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
        cell.mainImageView.image = image.image
        var text = "SIZE: " + String(describing: image.image.size)
        
        if let data = image.data {
            let byteCount = data.count
            text += " " + String(byteCount / 1024) + " KB"
        }
        cell.centeredLabel.text = text
        
        return cell
    }
}

class ImageCell: UITableViewCell {
    let mainImageView = UIImageView()
    let centeredLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        
        self.mainImageView.contentMode = .scaleAspectFit
        self.mainImageView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.mainImageView)
        self.mainImageView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor).isActive = true
        self.mainImageView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor).isActive = true
        self.mainImageView.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        self.mainImageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        
        self.centeredLabel.textColor = .white
        self.centeredLabel.translatesAutoresizingMaskIntoConstraints = false
        self.mainImageView.addSubview(self.centeredLabel)
        self.centeredLabel.centerYAnchor.constraint(equalTo: self.mainImageView.centerYAnchor).isActive = true
        self.centeredLabel.leftAnchor.constraint(equalTo: self.mainImageView.layoutMarginsGuide.leftAnchor).isActive = true
        self.centeredLabel.rightAnchor.constraint(equalTo: self.mainImageView.layoutMarginsGuide.rightAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


struct Settings {
    var isCroppingEnabled: Bool
    var isResizingEnabled: Bool
    var isConfirmationRequired: Bool
    
    var limits: NSKCameraController.Limits
    
    var resizingMode: NSKCameraController.ResizingMode
    var numberOfAttachments: NSKCameraController.NumberOfAttachments
    var mediaType: NSKCameraController.Source.MediaType // images
    var videoMaximumDuration: TimeInterval // 20
    
    init() {
        self.isCroppingEnabled = true
        self.isResizingEnabled = true
        self.isConfirmationRequired = true
        
        self.limits = NSKCameraController.Limits()
        
        self.resizingMode = .free
        self.numberOfAttachments = .single
        self.mediaType = .image
        self.videoMaximumDuration = 20
    }
}

class SettingsController: UIViewController {
    private var settings: Settings
    private let initialSettings: Settings
    
    private var currentNumberOfAttachments = 1
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
    
    private func addView(contentView: UIStackView, subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        contentView.addArrangedSubview(subview)
        
        subview.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor).isActive = true
        subview.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.saveAction(_:)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelAction(_:)))
        
        self.view.backgroundColor = .white
        
        let scrollView = UIScrollView()
        scrollView.preservesSuperviewLayoutMargins = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let contentView = UIStackView()
        contentView.spacing = 16
        contentView.axis = .vertical
        contentView.alignment = .center
        contentView.isLayoutMarginsRelativeArrangement = true
        contentView.preservesSuperviewLayoutMargins = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(contentView)
        contentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor).isActive = true
        contentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).isActive = true
        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        
        let h = contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        h.priority = .defaultLow - 1
        h.isActive = true
        
        let topAnchor: NSLayoutYAxisAnchor
        if #available(iOS 11.0, *) {
            topAnchor = self.view.safeAreaLayoutGuide.topAnchor
        } else {
            topAnchor = self.topLayoutGuide.bottomAnchor
        }
        self.view.addSubview(scrollView)
        scrollView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        scrollView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        if #available(iOS 11.0, *) {
            scrollView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else {
            scrollView.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor).isActive = true
        }
        
        let numberOfAttachmentsControl = UISegmentedControl(items: ["SINGLE", "MILTIPLY"])
        let multiPhotoView: MultiPhotoView
        switch self.settings.numberOfAttachments {
        case .single:
            numberOfAttachmentsControl.selectedSegmentIndex = 0
            multiPhotoView = MultiPhotoView(numberOfAttachments: 1, buttonTitle: "", target: self,
                                            numberOfAttachmentsAction: #selector(self.numberOfAttachmentsAction(_:)),
                                            buttonTitleAction: #selector(self.buttonTitleAction(_:)))
            multiPhotoView.alpha = 0.5
            multiPhotoView.isUserInteractionEnabled = false
        case .multiply(let maxNumber, let buttonTitle):
            self.currentNumberOfAttachments = maxNumber
            self.currentButtonTitle = buttonTitle
            numberOfAttachmentsControl.selectedSegmentIndex = 1
            multiPhotoView = MultiPhotoView(numberOfAttachments: maxNumber, buttonTitle: buttonTitle, target: self,
                                            numberOfAttachmentsAction: #selector(self.numberOfAttachmentsAction(_:)),
                                            buttonTitleAction: #selector(self.buttonTitleAction(_:)))
        }
        numberOfAttachmentsControl.tag = 2000
        multiPhotoView.tag = numberOfAttachmentsControl.tag + 1
        
        numberOfAttachmentsControl.addTarget(self, action: #selector(self.handleNumberOfAttachmentsAction(_:)), for: .valueChanged)
        
        self.addView(contentView: contentView, subview: numberOfAttachmentsControl)
        self.addView(contentView: contentView, subview: multiPhotoView)
        
        let isCroppingEnabledSwitcher = self.configureLabelSwitch(labelTitle: "isCroppingEnabled", isOn: self.settings.isCroppingEnabled,
                                                                  action: #selector(self.isCroppingEnabledAction(_:)))
        self.addView(contentView: contentView, subview: isCroppingEnabledSwitcher)
        
        let isResizingEnabledSwitcher = self.configureLabelSwitch(labelTitle: "isResizingEnabled", isOn: self.settings.isResizingEnabled,
                                                                  action: #selector(self.isResizingEnabledAction(_:)))
        self.addView(contentView: contentView, subview: isResizingEnabledSwitcher)
        
        let isConfirmationRequiredSwitcher = self.configureLabelSwitch(labelTitle: "isConfirmationRequired", isOn: self.settings.isConfirmationRequired,
                                                                       action: #selector(self.isConfirmationRequiredAction(_:)))
        self.addView(contentView: contentView, subview: isConfirmationRequiredSwitcher)
        
        let limits = self.settings.limits
        let minimumSize = limits.minSize
        let minSizeSliderView = SliderView(title: "MIN SIZE", width: minimumSize.width, widthAction: #selector(self.handleMinWidthChange(_:)),
                                           height: minimumSize.height, heightAction: #selector(self.handleMinHeightChange(_:)),
                                           target: self)
        self.addView(contentView: contentView, subview: minSizeSliderView)
        
        let maxSize = limits.maxSize
        let isOn = maxSize != nil
        let switcherTag = 1000
        let maxSizeSwitcher = self.configureLabelSwitch(labelTitle: "TOP LIMIT MAX SIZE", isOn: isOn,
                                                        switcherTag: switcherTag,
                                                        action: #selector(self.maxSizeLimitAction(_:)))
        self.addView(contentView: contentView, subview: maxSizeSwitcher)
        
        let width = maxSize?.width ?? 0
        let height = maxSize?.height ?? 0
        let maxSizeSliderView = SliderView(title: "MAX SIZE", width: width, widthAction: #selector(self.handleMaxWidthChange(_:)),
                                           height: height, heightAction: #selector(self.handleMaxHeightChange(_:)),
                                           target: self)
        maxSizeSliderView.isUserInteractionEnabled = false
        self.addView(contentView: contentView, subview: maxSizeSliderView)
        maxSizeSliderView.tag = switcherTag + 1
        maxSizeSliderView.isUserInteractionEnabled = isOn
        maxSizeSliderView.alpha = isOn ? 1 : 0.5
        
        let resizingModeControl = UISegmentedControl(items: ["FREE", "SAVE ASPECT"])
        switch self.settings.resizingMode {
        case .free:
            resizingModeControl.selectedSegmentIndex = 0
        case .saveAspectRatio:
            resizingModeControl.selectedSegmentIndex = 1
        }
        resizingModeControl.addTarget(self, action: #selector(self.handleResizingModeAction(_:)), for: .valueChanged)
        self.addView(contentView: contentView, subview: resizingModeControl)
        
        let filterSegmentedControl = UISegmentedControl(items: ["Image", "Video", "Image and video"])
        filterSegmentedControl.selectedSegmentIndex = self.settings.mediaType.rawValue
        self.addView(contentView: contentView, subview: filterSegmentedControl)
        filterSegmentedControl.addTarget(self, action: #selector(self.mediaFilterChanged(_:)), for: .valueChanged)
        
        let maxDurationSlider = UISlider()
        maxDurationSlider.minimumValue = 1
        maxDurationSlider.maximumValue = 20
        maxDurationSlider.value = Float(self.settings.videoMaximumDuration)
        maxDurationSlider.translatesAutoresizingMaskIntoConstraints = false
        maxDurationSlider.addTarget(self, action: #selector(self.handleMaxDurationValue(_:)), for: .valueChanged)
        self.addView(contentView: contentView, subview: maxDurationSlider)
    }
    
    private func configureLabelSwitch(labelTitle: String, isOn: Bool, switcherTag: Int = 0, action: Selector) -> UIView {
        let view = UIView()
        
        let switcher = UISwitch()
        switcher.isOn = isOn
        switcher.tag = switcherTag
        switcher.translatesAutoresizingMaskIntoConstraints = false
        switcher.addTarget(self, action: action, for: .valueChanged)
        view.addSubview(switcher)
        switcher.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        switcher.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        switcher.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        let label = UILabel()
        label.text = labelTitle
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        label.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: switcher.leftAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: switcher.centerYAnchor).isActive = true
        
        return view
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
        let maxWidth = CGFloat(sender.value)
        let maxHeight: CGFloat
        
        if let maxSize = self.settings.limits.maxSize {
            maxHeight = maxSize.height
        } else {
            maxHeight = 0
        }
        self.settings.limits = NSKCameraController.Limits(minSize: self.settings.limits.minSize, maxSize: CGSize(width: maxWidth, height: maxHeight))
    }
    @objc func handleMaxHeightChange(_ sender: UISlider) {
        let maxHeight = CGFloat(sender.value)
        let maxWidth: CGFloat
        
        if let maxSize = self.settings.limits.maxSize {
            maxWidth = maxSize.width
        } else {
            maxWidth = 0
        }
        self.settings.limits = NSKCameraController.Limits(minSize: self.settings.limits.minSize, maxSize: CGSize(width: maxWidth, height: maxHeight))
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
    
    @objc func handleNumberOfAttachmentsAction(_ sender: UISegmentedControl) {
        guard let multiPhotoView = self.view.viewWithTag(sender.tag + 1) else { return }
        
        switch sender.selectedSegmentIndex {
        case 0:
            self.settings.numberOfAttachments = .single
            multiPhotoView.isUserInteractionEnabled = false
            multiPhotoView.alpha = 0.5
        case 1:
            self.settings.numberOfAttachments = .multiply(self.currentNumberOfAttachments, self.currentButtonTitle)
            multiPhotoView.isUserInteractionEnabled = true
            multiPhotoView.alpha = 1
        default:
            break
        }
    }
    
    @objc func numberOfAttachmentsAction(_ sender: UISlider) {
        switch self.settings.numberOfAttachments {
        case .multiply(_, let title):
            let value = Int(exactly: ceil(sender.value)) ?? 0
            self.currentNumberOfAttachments = value
            self.settings.numberOfAttachments = .multiply(value, title)
        default:
            break
        }
    }
    @objc func buttonTitleAction(_ sender: UITextField) {
        switch self.settings.numberOfAttachments {
        case .multiply(let maxNumberOfAttachments, _):
            let title = sender.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            self.currentButtonTitle = title
            self.settings.numberOfAttachments = .multiply(maxNumberOfAttachments, title)
        default:
            break
        }
    }
    
    @objc func mediaFilterChanged(_ sender: UISegmentedControl) {
        if let mediaType = NSKCameraController.Source.MediaType(rawValue: sender.selectedSegmentIndex) {
            self.settings.mediaType = mediaType
        }
    }
    
    @objc func handleMaxDurationValue(_ sender: UISlider) {
        self.settings.videoMaximumDuration = TimeInterval(sender.value)
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
    init(numberOfAttachments: Int, buttonTitle: String, target: Any, numberOfAttachmentsAction: Selector, buttonTitleAction: Selector) {
        super.init(frame: .zero)
        
        let numberSlider = UISlider()
        numberSlider.tag = 101
        numberSlider.minimumValue = 1
        numberSlider.maximumValue = 100
        numberSlider.value = Float(numberOfAttachments)
        numberSlider.translatesAutoresizingMaskIntoConstraints = false
        numberSlider.addTarget(target, action: numberOfAttachmentsAction, for: .valueChanged)
        numberSlider.addTarget(self, action: #selector(self.handleNumberOfAttachmentsChange(_:)), for: .valueChanged)
        self.addSubview(numberSlider)
        numberSlider.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        numberSlider.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        numberSlider.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        let numberLabel = UILabel()
        numberLabel.tag = numberSlider.tag + 1
        numberLabel.text = String(numberOfAttachments)
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
    
    @objc func handleNumberOfAttachmentsChange(_ sender: UISlider) {
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
