//
//  ViewController.swift
//  ActionShot
//
//  Created by Joshua Newnham on 31/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class CameraViewController: UIViewController {
    
    /**
     Reference to our views CapturePreviewView (Camera stream)
     */
    weak var previewView: CapturePreviewView?
    
    /**
     Utility class that encapsulates setting up and tearing down the video capture; we'll start recording
     and assign the ViewController as a delegate to receive captured images from the video stream.
     */
    let videoCapture : VideoCapture = VideoCapture()
    
    /**
     Set when the 'Action Button' is tapped; will start saving frames and process the frames
     when either:
     a) the user  lifts their finger
     b) the time elapses
     */
    var capturingFrames : Bool = false{
        didSet{
            if capturingFrames{
                captureTimestamp = Date()
            }
        }
    }
    
    let captureMaxTime : TimeInterval = 3.0
    
    var captureTimestamp : Date?
    
    /**
     Instantiate an instance of ImageProcessor; the class which encapsulates the
     functionality for performing the 'action shot' effect
     **/
    let imageProcessor = ImageProcessor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initUI()
        
        videoCapture.delegate = self
        
        startCamera()
    }
    
    func startCamera(){
        videoCapture.asyncInit { (success) in
            if success{
                // Assign the capture session instance being previewed
                (self.previewView?.layer as! AVCaptureVideoPreviewLayer).session = self.videoCapture.captureSession
                // You use the videoGravity property to influence how content is viewed relative to the layer bounds;
                // in this case setting it to full the screen while respecting the aspect ratio.
                (self.previewView?.layer as! AVCaptureVideoPreviewLayer).videoGravity = AVLayerVideoGravity.resizeAspectFill
                
                self.videoCapture.startCapturing()
            } else{
                print("Failed to init VideoCapture")
            }
        }
    }
    
    func stopCamera(){
        videoCapture.stopCapturing()
    }
    
    func showEffect(){
        guard self.imageProcessor.frames.count > 0 else{ return }        
        
        // Untoggle requestCapture variable
        capturingFrames = false
        
        // stop capturing frames
        self.stopCamera()
        
        // create and add a blur effect
        let effect = UIBlurEffect(style: .regular)
        let visualEffectsView = UIVisualEffectView(effect: effect)
        visualEffectsView.tag = 99
        visualEffectsView.frame = self.view.bounds
        visualEffectsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(visualEffectsView)
        
        // Create and present EffectViewController
        let effectCV = EffectsViewController()
        
        effectCV.delegate = self
        effectCV.imageProcessor = self.imageProcessor
        effectCV.modalPresentationStyle = .overCurrentContext
        
        present(effectCV, animated: false) {
            
        }
    }
    
    func getTestImages() -> [CIImage]{
        var frames = [CIImage]()
        
        for i in stride(from: 1, to: 49, by: 2){
            let uiImage = UIImage(named: "run_test_\(i)")
            let frame = CIImage(cgImage: (uiImage?.cgImage)!)
            frames.append(frame)
        }
        
        return frames
    }
}

// MARK: - VideoCaptureDelegate

extension CameraViewController : VideoCaptureDelegate{
    
    func onFrameCaptured(
        videoCapture: VideoCapture,
        pixelBuffer:CVPixelBuffer?,
        timestamp:CMTime){
        
        // Unwrap the parameter pixxelBuffer and cast to image; exit early if either are null
        guard capturingFrames, let pixelBuffer = pixelBuffer else{
            print("WARNING: onFrameCaptured; null pixelBuffer")
            return
        }
        
        // Create CIImage from pixel buffer
        let frame = CIImage(cvPixelBuffer:pixelBuffer)
        
        self.imageProcessor.addFrame(frame: frame)
        
        // Test elapsed time; we have added a limit - force stopping
        // if we have exceeded this limit
        let et = Date().timeIntervalSince(self.captureTimestamp!)
        
        if et >= self.captureMaxTime{
            self.showEffect()
        }
    }
}

// MARK: - UI

extension CameraViewController{
    
    func initUI() {
        // Create preview view (where our camera frames will be rendered to)
        let previewView = CapturePreviewView(frame: self.view.bounds)
        self.view.addSubview(previewView)
        
        previewView.topAnchor.constraint(equalTo: self.view.topAnchor,
                                         constant: 0).isActive = true
        previewView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor,
                                            constant: 0).isActive = true
        previewView.leftAnchor.constraint(equalTo: self.view.leftAnchor,
                                          constant: 0).isActive = true
        previewView.rightAnchor.constraint(equalTo: self.view.rightAnchor,
                                           constant: 0).isActive = true
        self.previewView = previewView
        
        // Create action button (used for taken the photo)
        let actionButtonSize = CGSize(width: self.view.bounds.width * 0.2,
                                      height: self.view.bounds.width * 0.2)
        let actionButton = UIButton(frame:
            CGRect(x: self.view.frame.width/2 - actionButtonSize.width/2,
                   y: self.view.frame.height - (actionButtonSize.height + actionButtonSize.height * 0.3) ,
                   width: actionButtonSize.width,
                   height: actionButtonSize.height))
        self.view.addSubview(actionButton)
        actionButton.setImage(UIImage(named: "action_button"), for: .normal)
        actionButton.addTarget(self,
                               action: #selector(CameraViewController.onActionButtonTappedDown(_:)),
                               for: UIControlEvents.touchDown)
        actionButton.addTarget(self,
                               action: #selector(CameraViewController.onActionButtonTappedUp(_:)),
                               for: UIControlEvents.touchUpInside)
        
        // Create flip camera button
        let flipButtonImage = UIImage(named: "camera_flip_button")
        let flipButtonSize = CGSize(width: self.view.bounds.width * 0.075,
                                    height: self.view.bounds.width * 0.075 * (flipButtonImage!.size.height / flipButtonImage!.size.width))
        let flipButton = UIButton(frame:
            CGRect(x: self.view.bounds.width - (flipButtonSize.width * 2.0),
                   y: UIApplication.shared.statusBarFrame.height + (flipButtonSize.width * 0.5),
                   width: flipButtonSize.width,
                   height: flipButtonSize.height))
        self.view.addSubview(flipButton)
        flipButton.setImage(flipButtonImage, for: .normal)
        flipButton.addTarget(self,
                             action: #selector(CameraViewController.onFlipCameraButtonTapped(_:)), for: .touchUpInside)
    }
    
    @objc func onActionButtonTappedDown(_ sender:UIButton){
        //guard !self.capturingFrames, self.videoCapture.isCapturing else{ return }
        guard !self.capturingFrames else{ return }
        
        // Reset/Prepare imageProcessor; essentially removing all previous
        // frames and setting it's current frame index to 0)
        self.imageProcessor.reset()
        
        capturingFrames = true
    }
    
    @objc func onActionButtonTappedUp(_ sender:UIButton){
        guard self.capturingFrames else{ return }
        
        self.showEffect()
    }
    
    @objc func onFlipCameraButtonTapped(_ sender:UIButton){
        stopCamera()
        
        videoCapture.cameraPostion == AVCaptureDevice.Position.front ?
            AVCaptureDevice.Position.back : AVCaptureDevice.Position.front
        
        videoCapture.startCapturing()
    }
}

// MARK: - StyleTransferViewControllerDelegate

extension CameraViewController : UINavigationControllerDelegate, EffectsViewControllerDelegate{
    
    func onEffectsViewDismissed(sender:EffectsViewController){
        // remove effect
        guard let effectView = self.view.viewWithTag(99) else { return }
        effectView.removeFromSuperview()
        
        // restart camera
        self.startCamera()
    }
    
}

