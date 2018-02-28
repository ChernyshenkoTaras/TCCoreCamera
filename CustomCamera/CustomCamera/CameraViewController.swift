//
//  ViewController.swift
//  CustomCamera
//
//  Created by Taras Chernyshenko on 6/27/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController {
    
    @IBAction private func recordingButton(_ sender: UIButton) {
        guard let cameraManager = self.cameraManager else { return }
        if cameraManager.isRecording {
            cameraManager.stopRecording()
            sender.setImage(UIImage(named: "record")!, for: .normal)
        } else {
            cameraManager.startRecording()
            sender.setImage(UIImage(named: "stop")!, for: .normal)
        }
    }
    
    private var cameraManager: CameraManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.cameraManager = CameraManager(view: self.view)
        self.cameraManager?.completion = { (fileURL) in
            self.saveInPhotoLibrary(with: fileURL)
            print("finished writing to \(fileURL.absoluteString)")
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    private func saveInPhotoLibrary(with fileURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }) { saved, error in
            if saved {
                let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
            } else {
                print(error.debugDescription)
            }
        }
    }
}

