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

class CameraViewController: UIViewController,
    AVCaptureAudioDataOutputSampleBufferDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let recordingQueue = DispatchQueue(label: "recording.queue")
    
    enum CameraMode {
        case photo
        case camera
    }
    
    @IBOutlet private weak var recordingButton: UIButton?
    
    private var session: AVCaptureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    private var audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
    
    private var assetWriter: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio,
        outputSettings: audioSettings)
    private var videoWriterInput: AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
    
    private var recordingURL: URL?
    
    private var isCameraRecording: Bool = false
    private var isRecordingSessionStarted: Bool = false

    private static let audioSettings: [String : Any] = [
        AVFormatIDKey : kAudioFormatAppleIMA4,
        AVNumberOfChannelsKey : 1,
        AVSampleRateKey : 32000.0
    ]
    private static let videoSettings: [String : Any] = [
        AVVideoCodecKey : AVVideoCodecH264,
        AVVideoWidthKey : UIScreen.main.bounds.width,
        AVVideoHeightKey : UIScreen.main.bounds.height
    ]
    
    @IBAction func recordingButton(_ sender: Any) {
        if self.isCameraRecording {
            self.stopRecording()
        } else {
            self.startRecording()
        }
        let image = UIImage(named: self.isCameraRecording ? "record" : "stop")!
        self.recordingButton?.setImage(image, for: .normal)
        self.isCameraRecording = !self.isCameraRecording
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Video recording"
        self.update(with: .camera)
        self.initialize()
        self.configureWriters()
        self.configurePreview()
        self.configureSession()
    }
    
    private func update(with mode: CameraMode) {
        var fileURL: URL
        switch mode {
        case .camera:
            fileURL = URL(fileURLWithPath: "\(NSTemporaryDirectory() as String)/video.mov")
        case .photo:
            fileURL = URL(fileURLWithPath: "\(NSTemporaryDirectory() as String)/image.mp4")
        }
        self.recordingURL = fileURL
        let fileManager = FileManager()
        if fileManager.isDeletableFile(atPath: fileURL.path) {
            _ = try? fileManager.removeItem(atPath: fileURL.path)
        }
    }
    
    private func initialize() {
        self.session.sessionPreset = AVCaptureSessionPresetHigh
        self.videoWriterInput.expectsMediaDataInRealTime = true
        self.audioWriterInput.expectsMediaDataInRealTime = true
        
        do {
            if let fileURL = self.recordingURL {
                self.assetWriter = try AVAssetWriter(outputURL: fileURL,
                    fileType: AVFileTypeQuickTimeMovie)
            }
            let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            self.deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print(error.localizedDescription)
        }
        
        if self.session.canAddInput(self.deviceInput) {
            self.session.addInput(self.deviceInput)
        }
    }
    
    private func configureWriters() {
        guard let assetWriter = self.assetWriter else {
            assertionFailure("AssetWriter was not initialized")
            return
        }
        if assetWriter.canAdd(self.videoWriterInput) {
            assetWriter.add(self.videoWriterInput)
        }
        if assetWriter.canAdd(self.audioWriterInput) {
            assetWriter.add(self.audioWriterInput)
        }
    }
    
    private func configurePreview() {
        let previewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        //importent line of code what will did a trick
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        let rootLayer = self.view.layer
        rootLayer.masksToBounds = true
        previewLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        rootLayer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
        self.session.startRunning()
    }
    
    private func configureSession() {
        DispatchQueue.main.async {
            self.session.beginConfiguration()
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            if let videoConnection = self.videoOutput.connection(withMediaType: AVMediaTypeVideo) {
                if videoConnection.isVideoStabilizationSupported {
                    videoConnection.preferredVideoStabilizationMode = .auto
                }
                videoConnection.videoOrientation = .portrait
            }
            
            self.session.commitConfiguration()
            let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            let audioIn = try? AVCaptureDeviceInput(device: audioDevice)
            
            if self.session.canAddInput(audioIn) {
                self.session.addInput(audioIn)
            }
            
            if self.session.canAddOutput(self.audioOutput) {
                self.session.addOutput(self.audioOutput)
            }
        }
    }
    
    private func startRecording() {
        guard let assetWriter = self.assetWriter else {
            assertionFailure("AssetWriter was not initialized")
            return
        }
        if !assetWriter.startWriting() {
            print("AssetWriter error: \(assetWriter.error.debugDescription)")
        }
        self.videoOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
    }
    
    private func stopRecording() {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
        
        self.assetWriter?.finishWriting {
            if let fileURL = self.recordingURL {
                self.saveInPhotoLibrary(with: fileURL)
            }
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer
        sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if !self.isRecordingSessionStarted {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.assetWriter?.startSession(atSourceTime: presentationTime)
            self.isRecordingSessionStarted = true
        }
        
        let description = CMSampleBufferGetFormatDescription(sampleBuffer)!
        
        if CMFormatDescriptionGetMediaType(description) == kCMMediaType_Audio {
            if self.audioWriterInput.isReadyForMoreMediaData {
                print("appendSampleBuffer audio");
                self.audioWriterInput.append(sampleBuffer)
            }
        } else {
            if self.videoWriterInput.isReadyForMoreMediaData {
                print("appendSampleBuffer video");
                if !self.videoWriterInput.append(sampleBuffer) {
                    print("Error writing video buffer");
                }
            }
        }
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

