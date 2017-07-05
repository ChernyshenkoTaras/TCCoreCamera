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
    
    private var session: AVCaptureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    private var audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
    
    private var videoDevice: AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    private var audioConnection: AVCaptureConnection?
    private var videoConnection: AVCaptureConnection?
    
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var videoInput: AVAssetWriterInput?
    
    private var fileManager: FileManager = FileManager()
    private var recordingURL: URL?
    
    private var isCameraRecording: Bool = false
    private var isRecordingSessionStarted: Bool = false
    
    private var recordingQueue = DispatchQueue(label: "recording.queue")

    @IBAction func recordingButton(_ sender: Any) {
        if self.isCameraRecording {
            self.stopRecording()
        } else {
            self.startRecording()
        }
        self.isCameraRecording = !self.isCameraRecording
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "TEST"
        self.setup()
    }
    
    private func setup() {
        self.session.sessionPreset = AVCaptureSessionPresetHigh
        
        self.recordingURL = URL(fileURLWithPath: "\(NSTemporaryDirectory() as String)/file.mov")
        if self.fileManager.isDeletableFile(atPath: self.recordingURL!.path) {
            _ = try? self.fileManager.removeItem(atPath: self.recordingURL!.path)
        }
    
        self.assetWriter = try? AVAssetWriter(outputURL: self.recordingURL!,
            fileType: AVFileTypeQuickTimeMovie)
        
        let audioSettings = [
            AVFormatIDKey : kAudioFormatAppleIMA4,
            AVNumberOfChannelsKey : 1,
            AVSampleRateKey : 16000.0
        ] as [String : Any]
        
        let videoSettings = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : UIScreen.main.bounds.width,
            AVVideoHeightKey : UIScreen.main.bounds.width
        ] as [String : Any]
        
        self.videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo,
             outputSettings: videoSettings)
        self.audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio,
             outputSettings: audioSettings)
        
        self.videoInput?.expectsMediaDataInRealTime = true
        self.audioInput?.expectsMediaDataInRealTime = true
        
        if self.assetWriter!.canAdd(self.videoInput!) {
            self.assetWriter?.add(self.videoInput!)
        }
        
        if self.assetWriter!.canAdd(self.audioInput!) {
            self.assetWriter?.add(self.audioInput!)
        }
        
        self.deviceInput = try? AVCaptureDeviceInput(device: self.videoDevice)
        
        if self.session.canAddInput(self.deviceInput) {
            self.session.addInput(self.deviceInput)
        }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        
        //importent line of code what will did a trick
        self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        let rootLayer = self.view.layer
        rootLayer.masksToBounds = true
        self.previewLayer?.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
        
        rootLayer.insertSublayer(self.previewLayer!, at: 0)
        
        self.session.startRunning()
        
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
        if self.assetWriter?.startWriting() != true {
            print("error: \(self.assetWriter?.error.debugDescription ?? "")")
        }
        
        self.videoOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
    }
    
    private func stopRecording() {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
        
        self.assetWriter?.finishWriting {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.recordingURL!)
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
            print("saved")
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
            if self.audioInput!.isReadyForMoreMediaData {
                print("appendSampleBuffer audio");
                self.audioInput?.append(sampleBuffer)
            }
        } else {
            if self.videoInput!.isReadyForMoreMediaData {
                print("appendSampleBuffer video");
                if !self.videoInput!.append(sampleBuffer) {
                    print("Error writing video buffer");
                }
            }
        }
    }
}

