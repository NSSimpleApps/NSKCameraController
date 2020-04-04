//
//  NSKPhotoLibraryController.swift
//  NSKCameraController
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import Photos

public extension Notification.Name {
    static let NSKCameraControllerOverflow = Notification.Name(rawValue: "NSKCameraControllerOverflow")
}

class NSKPhotoLibraryController: UICollectionViewController {
    class ImageCell: UICollectionViewCell {
        let imageView = UIImageView()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.imageView.contentMode = .scaleAspectFill
            self.imageView.clipsToBounds = true
            self.contentView.addSubview(self.imageView)
            self.imageView.translatesAutoresizingMaskIntoConstraints = false
            self.imageView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor).isActive = true
            self.imageView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor).isActive = true
            self.imageView.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
            self.imageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        }
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    class CountImageCell: ImageCell {
        class RoundedLabel: UILabel {
            override func layoutSubviews() {
                super.layoutSubviews()
                self.layer.cornerRadius = self.bounds.height/2
            }
            
            override func sizeThatFits(_ size: CGSize) -> CGSize {
                if let text = self.text, text.isEmpty == false {
                    let minSize: CGFloat = 22
                    switch text.count {
                    case 1:
                        return CGSize(width: minSize, height: minSize)
                    case 2:
                        return CGSize(width: 30, height: minSize)
                    default:
                        break
                    }
                }
                return super.sizeThatFits(size)
            }
        }
        static func createLabel(textColor: UIColor?) -> UILabel {
            let numberLabel = RoundedLabel()
            numberLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            numberLabel.textColor = textColor
            numberLabel.textAlignment = .center
            numberLabel.clipsToBounds = true
            
            return numberLabel
        }
        let label = CountImageCell.createLabel(textColor: .white)
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let imageView = UIImageView(image: NSKResourceProvider.shadowBorderImage)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            self.contentView.addSubview(imageView)
            
            let imageSize: CGFloat = 26
            imageView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 6).isActive = true
            imageView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant: -6).isActive = true
            imageView.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: imageSize).isActive = true
            
            self.label.translatesAutoresizingMaskIntoConstraints = false
            imageView.addSubview(self.label)
            
            let offset: CGFloat = 2.5
            
            self.label.topAnchor.constraint(equalTo: imageView.topAnchor, constant: offset).isActive = true
            self.label.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -offset).isActive = true
            self.label.leftAnchor.constraint(equalTo: imageView.leftAnchor, constant: offset).isActive = true
            self.label.rightAnchor.constraint(equalTo: imageView.rightAnchor, constant: -offset).isActive = true
        }
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setCountValue(_ value: Int, color: UIColor?) {
            self.label.text = String(value)
            self.label.backgroundColor = color ?? .clear
        }
        func removeCountValue() {
            self.label.text = nil
            self.label.backgroundColor = .clear
        }
    }
    
    enum Result {
        case cancelled
        case assets([PHAsset])
        case asset(PHAsset)
    }
    
    let maximumNumberOfPhotos: Int
    let accentColor: UIColor?
    let commitBlock: (NSKPhotoLibraryController, Result) -> Void
    let selectButtonTitle: String?
    
    private var assets: PHFetchResult<PHAsset>?
    private var selectedIndexPaths: [IndexPath: Int] = [:]
    private var shouldDisplaySettingsPlaceholder = false
    
    init(maximumNumberOfPhotos: Int, selectButtonTitle: String?, accentColor: UIColor?, commitBlock: @escaping (NSKPhotoLibraryController, Result) -> Void) {
        self.maximumNumberOfPhotos = maximumNumberOfPhotos
        self.selectButtonTitle = selectButtonTitle
        self.accentColor = accentColor
        self.commitBlock = commitBlock
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        layout.sectionInset = .zero
        
        super.init(collectionViewLayout: layout)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var allowsMultipleSelection: Bool {
        return self.maximumNumberOfPhotos > 1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor(white: 0.2, alpha: 1)
        let collectionView = self.collectionView!
        collectionView.preservesSuperviewLayoutMargins = true
        collectionView.backgroundColor = nil
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: NSKResourceProvider.cancelImage,
                                                                style: .plain, target: self,
                                                                action: #selector(self.cancelAction(_:)))
        if self.allowsMultipleSelection {
            collectionView.register(CountImageCell.self, forCellWithReuseIdentifier: "CountImageCell")
            
            let tintColor: UIColor = .white
            let rightTitleButton = UIBarButtonItem(title: self.selectButtonTitle, style: .done, target: self,
                                                   action: #selector(self.commitAction(_:)))
            rightTitleButton.tintColor = tintColor
            rightTitleButton.isEnabled = false
            
            let label = CountImageCell.createLabel(textColor: self.accentColor)
            label.text = "0"
            label.sizeToFit()
            label.backgroundColor = tintColor
            label.isHidden = true
            let countButton = UIBarButtonItem(customView: label)
            
            self.navigationItem.rightBarButtonItems = [rightTitleButton, countButton]
        } else {
            collectionView.register(ImageCell.self, forCellWithReuseIdentifier: "ImageCell")
        }
        
        PHPhotoLibrary.requestAuthorization { [weak self] (status) in
            guard let sSelf = self else { return }
            
            switch status {
            case .authorized:
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(keyPath: \PHAsset.creationDate, ascending: false)]
                let assets = PHAsset.fetchAssets(with: .image, options: options)
                
                DispatchQueue.main.async { [weak sSelf] in
                    guard let ssSelf = sSelf else { return }
                    
                    ssSelf.assets = assets
                    ssSelf.collectionView.reloadData()
                }
            case .denied, .restricted, .notDetermined:
                DispatchQueue.main.async { [weak sSelf] in
                    guard let ssSelf = sSelf else { return }
                    
                    ssSelf.shouldDisplaySettingsPlaceholder = true
                    ssSelf.collectionView.reloadData()
                }
            @unknown default:
                break
            }
        }
    }
    @objc private func cancelAction(_ sender: UIBarButtonItem) {
        self.commitBlock(self, .cancelled)
    }
    @objc private func commitAction(_ sender: UIBarButtonItem) {
        if let assets = self.assets {
            let selectedAssets = self.selectedIndexPaths.sorted { (pair1, pair2) -> Bool in
                return pair1.value < pair2.value
                }.compactMap { (pair) -> PHAsset? in
                    assets[pair.key.item]
            }
            if selectedAssets.count == 1 {
                self.commitBlock(self, .asset(selectedAssets.first!))
            } else {
                self.commitBlock(self, .assets(selectedAssets))
            }
        } else {
            self.commitBlock(self, .cancelled)
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = self.assets?.count ?? 0
        
        if count == 0, self.shouldDisplaySettingsPlaceholder {
            collectionView.backgroundView = NSKOpenSettingsView.createOpenSettingsView(target: self, action: #selector(self.openSettingsAction(_:)))
        } else {
            collectionView.backgroundView = nil
        }
        return count
    }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let asset = self.assets?.object(at: indexPath.item) {
            let cell: ImageCell
            if self.allowsMultipleSelection {
                let countImageCell = collectionView.dequeueReusableCell(withReuseIdentifier: "CountImageCell", for: indexPath) as! CountImageCell
                if let number = self.selectedIndexPaths[indexPath] {
                    countImageCell.setCountValue(number, color: self.accentColor)
                } else {
                    countImageCell.removeCountValue()
                }
                cell = countImageCell
            } else {
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell
            }
            
            if case let tag = cell.tag, tag != 0 {
                PHImageManager.default().cancelImageRequest(PHImageRequestID(tag))
            }
            cell.tag = Int(PHImageManager.default().requestImage(for: asset, targetSize: cell.bounds.size, contentMode: .aspectFill, options: nil) { [weak cell] image, info in
                cell?.imageView.image = image
            })
            
            return cell
        } else {
            return UICollectionViewCell()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if self.allowsMultipleSelection {
            if self.selectedIndexPaths.count < self.maximumNumberOfPhotos {
                return true
            } else {
                if self.selectedIndexPaths[indexPath] == nil {
                    NotificationCenter.default.post(name: .NSKCameraControllerOverflow, object: self.maximumNumberOfPhotos)
                    return false
                } else {
                    return true
                }
            }
        } else {
            return true
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.allowsMultipleSelection {
            if let number = self.selectedIndexPaths[indexPath] {
                self.selectedIndexPaths[indexPath] = nil
                if let cell = collectionView.cellForItem(at: indexPath) as? CountImageCell {
                    cell.removeCountValue()
                }
                self.selectedIndexPaths = self.selectedIndexPaths.mapValues { (value) -> Int in
                    if value < number {
                        return value
                    } else {
                        return value - 1
                    }
                }
            } else {
                self.selectedIndexPaths[indexPath] = self.selectedIndexPaths.count + 1
            }
            self.selectedIndexPaths.forEach { (pair) in
                if let cell = collectionView.cellForItem(at: pair.key) as? CountImageCell {
                    cell.setCountValue(pair.value, color: self.accentColor)
                }
            }
            let isEmpty = self.selectedIndexPaths.isEmpty
            if let countButton = self.navigationItem.rightBarButtonItems?.last {
                if let label = countButton.customView as? UILabel {
                    label.isHidden = isEmpty
                    label.text = String(self.selectedIndexPaths.count)
                    label.sizeToFit()
                }
            }
            if let commitButton = self.navigationItem.rightBarButtonItems?.first {
                commitButton.isEnabled = isEmpty == false
            }
        } else {
            if let asset = self.assets?.object(at: indexPath.item) {
                self.commitBlock(self, .asset(asset))
            }
        }
    }
    
    @objc private func openSettingsAction(_ sender: UIButton) {
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
        }
    }
}

extension NSKPhotoLibraryController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let n = 4
        let sp = (collectionViewLayout as! UICollectionViewFlowLayout).minimumInteritemSpacing
        let width = (collectionView.bounds.width + sp) / CGFloat(n) - sp
        
        return CGSize(width: width, height: width)
    }
}
