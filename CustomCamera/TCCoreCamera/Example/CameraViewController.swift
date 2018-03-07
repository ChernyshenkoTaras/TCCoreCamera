//
//  ViewController.swift
//  CustomCamera
//
//  Created by Taras Chernyshenko on 6/27/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import UIKit
import Photos

class CameraViewController: UIViewController {
    
    @IBOutlet private weak var topView: UIView?
    @IBOutlet private weak var middleView: UIView?
    @IBOutlet private weak var innerView: UIView?
    
    @IBAction private func recordingButton(_ sender: UIButton) {
        guard let cameraManager = self.cameraManager else { return }
        if cameraManager.isRecording {
            cameraManager.stopRecording()
            self.setupStartButton()
        } else {
            cameraManager.startRecording()
            self.setupStopButton()
        }
    }
   
    @IBAction private func flipButtonPressed(_ button: UIButton) {
        self.cameraManager?.flip()
    }
    
    private var cameraManager: TCCoreCamera?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = true
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(zoomingGesture(gesture:)))
        self.view.addGestureRecognizer(gesture)
        self.topView?.layer.borderWidth = 1.0
        self.topView?.layer.borderColor = UIColor.darkGray.cgColor
        self.topView?.layer.cornerRadius = 32
        self.middleView?.layer.borderWidth = 4.0
        self.middleView?.layer.borderColor = UIColor.white.cgColor
        self.middleView?.layer.cornerRadius = 32
        self.innerView?.layer.borderWidth = 32.0
        self.innerView?.layer.cornerRadius = 32
        self.setupStartButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.cameraManager = TCCoreCamera(view: self.view)
        self.cameraManager?.videoCompletion = { (fileURL) in
            self.saveInPhotoLibrary(with: fileURL)
            print("finished writing to \(fileURL.absoluteString)")
        }
        self.cameraManager?.photoCompletion = { [weak self] (image) in
            do {
                try PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                self?.setupStartButton()
            } catch {
                print(error.localizedDescription)
            }
        }
        self.cameraManager?.camereType = .video
    }
    
    @objc private func zoomingGesture(gesture: UIPanGestureRecognizer) {
        let velocity = gesture.velocity(in: self.view)
        if velocity.y > 0 {
            self.cameraManager?.zoomOut()
        } else {
            self.cameraManager?.zoomIn()
        }
    }
    private func setupStartButton() {
        self.topView?.backgroundColor = UIColor.clear
        self.middleView?.backgroundColor = UIColor.clear
        
        self.innerView?.layer.borderWidth = 32.0
        self.innerView?.layer.borderColor = UIColor.white.cgColor
        self.innerView?.layer.cornerRadius = 32
        self.innerView?.backgroundColor = UIColor.lightGray
        self.innerView?.alpha = 0.2
    }
    
    private func setupStopButton() {
        self.topView?.backgroundColor = UIColor.white
        self.middleView?.backgroundColor = UIColor.white
        
        self.innerView?.layer.borderColor = UIColor.red.cgColor
        self.innerView?.backgroundColor = UIColor.red
        self.innerView?.alpha = 1.0
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

