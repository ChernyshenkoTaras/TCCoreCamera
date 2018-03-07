# TCCoreCamera

Would you like to create your camera same as Snapchat or Instagram? I think this library could help you. Basicly it is a wrapper above AVFoundation that allows you to use camera feature without extra setup. Build your own UI with buttons/sliders/anything else exactly like you want and just assign appropriate actions to them.

Library is under development, so I will appreciate your suggestions, bug reports and stars ;)

## How to install

Just drag and drop files from `Source` folder into project

## How to use

Look into example project first. Then add `private var cameraManager: TCCoreCamera?` property into `UIViewController`

and setup `TCCoreCamera` with appropriate `UIView` 

```swift
self.cameraManager = TCCoreCamera(view: self.view)
self.cameraManager?.completion = { (fileURL) in
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
```

Now create all buttons you need and assign `TCCoreCamera actions` to them

## Actions and properties

* `startRecording()` - start video recording/take photo
* `stopRecording()` - stop video recording
* `flip()` - flip btw front/back camera
* `zoomIn()` - increase camera zoom
* `zoomOut()` - decrease camera zoom
* `isRecording` - show if camera is already recording video or not
* `camereType` - set camera to `.photo` or `.video` mode
* `videoCompletion` - get result of video recording
* `photoCompletion` - get result of photo capturing

## Contributing to this project

If you have feature requests or bug reports, feel free to help out by sending pull requests or create issues.

## License

This code is distributed under the terms and conditions of the [MIT license](LICENSE).

