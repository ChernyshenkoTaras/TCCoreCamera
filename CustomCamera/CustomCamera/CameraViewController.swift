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
    
    private var videoDevice: AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    private var audioConnection: AVCaptureConnection?
    private var videoConnection: AVCaptureConnection?
    
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio,
        outputSettings: audioSettings)
    private var videoInput: AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
    
    private var fileManager: FileManager = FileManager()
    private var recordingURL: URL?
    
    private var isCameraRecording: Bool = false
    private var isRecordingSessionStarted: Bool = false
    
    private var recordingQueue = DispatchQueue(label: "recording.queue")

    private static let audioSettings: [String : Any] = [
        AVFormatIDKey : kAudioFormatAppleIMA4,
        AVNumberOfChannelsKey : 1,
        AVSampleRateKey : 32000.0
    ]
    private static let videoSettings: [String : Any] = [
        AVVideoCodecKey : AVVideoCodecH264,
        AVVideoWidthKey : UIScreen.main.bounds.width,
        AVVideoHeightKey : UIScreen.main.bounds.width
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
        if self.fileManager.isDeletableFile(atPath: fileURL.path) {
            _ = try? self.fileManager.removeItem(atPath: fileURL.path)
        }
    }
    
    private func initialize() {
        self.session.sessionPreset = AVCaptureSessionPresetHigh
        self.videoInput.expectsMediaDataInRealTime = true
        self.audioInput.expectsMediaDataInRealTime = true
        
        do {
            if let fileURL = self.recordingURL {
                self.assetWriter = try AVAssetWriter(outputURL: fileURL,
                    fileType: AVFileTypeQuickTimeMovie)
            }
            self.deviceInput = try AVCaptureDeviceInput(device: self.videoDevice)
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
        if assetWriter.canAdd(self.videoInput) {
            assetWriter.add(self.videoInput)
        }
        if assetWriter.canAdd(self.audioInput) {
            assetWriter.add(self.audioInput)
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
            self.videoConnection = self.videoOutput.connection(withMediaType: AVMediaTypeVideo)
            if self.videoConnection?.isVideoStabilizationSupported == true {
                self.videoConnection?.preferredVideoStabilizationMode = .auto
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
            
            self.audioConnection = self.audioOutput.connection(withMediaType: AVMediaTypeAudio)
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
            if self.audioInput.isReadyForMoreMediaData {
                print("appendSampleBuffer audio");
                self.audioInput.append(sampleBuffer)
            }
        } else {
            if self.videoInput.isReadyForMoreMediaData {
                print("appendSampleBuffer video");
                if !self.videoInput.append(sampleBuffer) {
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

