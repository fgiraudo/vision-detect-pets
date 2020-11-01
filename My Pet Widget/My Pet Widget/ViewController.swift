//
//  ViewController.swift
//  My Pet Widget
//
//  Created by Fernando - Pessoal on 01/11/2020.
//

import UIKit
import SnapKit
import Photos
import Vision

class ViewController: UIViewController {
    
    private let button = UIButton()
    private var layout: UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = CGSize(width: view.frame.width, height: 300)
        
        return layout
    }
    
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    
    var animalRecognitionRequest = VNRecognizeAnimalsRequest(completionHandler: nil)
    
    private let animalRecognitionWorkQueue = DispatchQueue(label: "PetClassifierRequest", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private var width: CGFloat = 0
    
    private var allPhotos: PHFetchResult<PHAsset>? {
        didSet {
            DispatchQueue.global(qos: .background).async {
                self.fetchImages(with: self.width)
            }
        }
    }
    
    private var allImages = [UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        width = view.frame.width
        view.backgroundColor = UIColor(named: "backgroundColor")
        configureViews()
    }
    
    private func configureViews() {
        view.addSubview(button)
        view.addSubview(collectionView)
        
        configureButton()
        configureCollectionView()
    }
    
    private func configureButton() {
        button.setTitle("Select photos", for: .normal)
        button.sizeToFit()
        button.setTitleColor(UIColor(named: "textColor"), for: .normal)
        button.addTarget(self, action: #selector(self.retrievePhotos), for: .touchUpInside)
        
        button.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin)
            make.centerX.equalToSuperview()
        }
    }
    
    private func configureCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .white
        collectionView.register(CollectionViewCell.self, forCellWithReuseIdentifier: "photoCell")
        
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(button.snp.bottom)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    @objc private func retrievePhotos() {
        allImages.removeAll()
        
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                let fetchOptions = PHFetchOptions()
                fetchOptions.fetchLimit = 1000
                fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
                self.allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            case .denied, .restricted, .notDetermined, .limited: break
            @unknown default:
                break
            }
        }
    }
    
    private func fetchImages(with width: CGFloat) {
        guard let allPhotos = self.allPhotos else { return }
        
        for index in 0..<allPhotos.count {
            let asset = allPhotos.object(at: index)
            
            fetchImage(asset: asset, contentMode: .aspectFit, targetSize: CGSize(width: width, height: 300), index: index)
        }
    }
    
    func fetchImage(asset: PHAsset, contentMode: PHImageContentMode, targetSize: CGSize, index: Int) {
        let options = PHImageRequestOptions()
        options.version = .current
        options.isSynchronous = true
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
            guard let image = image else {
                return
            }
            
            self.animalClassifier(image)
        }
    }
}

// MARK: - Collection View
extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        allImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? CollectionViewCell else {
            return UICollectionViewCell()
        }

        cell.imageView.image = allImages[indexPath.row]

        return cell
    }
}

// MARK: - Vision

extension ViewController {
    private func animalClassifier(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        animalRecognitionWorkQueue.async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNRecognizeAnimalsRequest { request, error in
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    var isCatOrDog = false
                    
                    for result in results
                    {
                        let animals = result.labels
                        
                        for animal in animals {
                            if animal.identifier == "Cat" || animal.identifier == "Dog" {
                                isCatOrDog = true
                            }
                        }
                    }
                    
                    if isCatOrDog {
                        if self.allImages.contains(image) {
                            return
                        } else {
                            self.allImages.append(image)
                            
                            print("All Images count: \(self.allImages.count)")
                            
                            DispatchQueue.main.async {
                                self.collectionView.reloadData()
                            }
                        }
                    }
                }
            }
            
            do {
                try requestHandler.perform([request])
            } catch {
                print(error)
            }
        }
    }
}
