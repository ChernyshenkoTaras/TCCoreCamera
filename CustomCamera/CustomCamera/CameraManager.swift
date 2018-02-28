//
//  CameraManager.swift
//  CustomCamera
//
//  Created by Taras Chernyshenko on 2/28/18.
//  Copyright © 2018 Taras Chernyshenko. All rights reserved.
//

import UIKit
import AVFoundation

class CameraManager: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias Completion = (URL) -> Void
    
    private enum CameraMode {
        case photo
        case camera
    }
    
    private let recordingQueue = DispatchQueue(label: "recording.queue")
    private let audioSettings: [String : Any]
    private let videoSettings: [String : Any]
    private let view: UIView
    private let audioWriterInput: AVAssetWriterInput
    private let videoWriterInput: AVAssetWriterInput
    private let videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    private let audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
    private let session: AVCaptureSession = AVCaptureSession()

    private var deviceInput: AVCaptureDeviceInput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var assetWriter: AVAssetWriter?
    private var recordingURL: URL?
    private(set) var isRecording: Bool = false
    private var isRecordingSessionStarted: Bool = false
    private var mode: CameraMode = .camera
    
    open var completion: Completion?
    
    init(view: UIView) {
        self.view = view
        self.audioSettings = [
            AVFormatIDKey : kAudioFormatAppleIMA4,
            AVNumberOfChannelsKey : 1,
            AVSampleRateKey : 32000.0
        ]
        self.videoSettings  = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : view.frame.width,
            AVVideoHeightKey : view.frame.height
        ]
        self.audioWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio,
            outputSettings: self.audioSettings)
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo,
            outputSettings: self.videoSettings)
        super.init()
        self.updateFileStorage(with: self.mode)
        self.initialize()
        self.configureWriters()
        self.configurePreview()
        self.configureSession()
    }
    
    open func startRecording() {
        self.configureWriters()
        self.updateFileStorage(with: self.mode)
        guard let assetWriter = self.assetWriter else {
            assertionFailure("AssetWriter was not initialized")
            return
        }
        if !assetWriter.startWriting() {
            assertionFailure("AssetWriter error: \(assetWriter.error.debugDescription)")
        }
        self.isRecording = true
        self.videoOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
    }
    
    open func stopRecording() {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
        self.assetWriter?.finishWriting {
            if let fileURL = self.recordingURL {
                self.completion?(fileURL)
            }
            self.isRecording = false
            self.isRecordingSessionStarted = false
        }
    }
    
    private func updateFileStorage(with mode: CameraMode) {
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
            let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            self.deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            assertionFailure(error.localizedDescription)
        }
        if self.session.canAddInput(self.deviceInput) {
            self.session.addInput(self.deviceInput)
        }
    }
    
    private func configureWriters() {
        do {
            if let fileURL = self.recordingURL {
                self.assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: AVFileTypeQuickTimeMovie)
            }
        } catch {
            print(error.localizedDescription)
        }
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
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer
        sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if !self.isRecordingSessionStarted {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.assetWriter?.startSession(atSourceTime: presentationTime)
            self.isRecordingSessionStarted = true
        }
        self.appendSampleBuffer(sampleBuffer)
    }
    
    private func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let description = CMFormatDescriptionGetMediaType(CMSampleBufferGetFormatDescription(sampleBuffer)!)
        switch description {
        case kCMMediaType_Audio:
            if self.audioWriterInput.isReadyForMoreMediaData {
                print("appendSampleBuffer audio");
                self.audioWriterInput.append(sampleBuffer)
            }
        default:
            if self.videoWriterInput.isReadyForMoreMediaData {
                print("appendSampleBuffer video");
                if !self.videoWriterInput.append(sampleBuffer) {
                    print("Error writing video buffer");
                }
            }
        }
    }
}
