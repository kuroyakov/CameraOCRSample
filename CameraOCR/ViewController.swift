//
//  ViewController.swift
//  CameraOCR
//
//  Created by Katsutoshi Kuroya on 2016/11/24.
//  Copyright © 2016 Katsutoshi Kuroya. All rights reserved.
//

/*
 This software using the OSS: TesseractOCRiOS
 The MIT License (MIT)
 Copyright (c) 2014 Daniele Galiotto
 https://github.com/gali8/Tesseract-OCR-iOS/blob/master/LICENSE.md
 */


import UIKit
import UIKit
import CoreImage
import AVFoundation
import TesseractOCR

class ViewController: UIViewController,
    UIPickerViewDelegate, UIPickerViewDataSource,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    G8TesseractDelegate
{
    
    @IBOutlet weak var recogTextLabel: UILabel!
    @IBOutlet weak var filterPicker: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var detectSwitch: UISwitch!
    // --------------------------------------------------------
    // For camera capture
    // --------------------------------------------------------
    var session = AVCaptureSession()
    var sourceCIImage: CIImage?
    var sourceCGImage: CGImage?
    var videoDevice : AVCaptureDevice?

    // --------------------------------------------------------
    // Image processing object
    // --------------------------------------------------------
    var imgProcManager = ImageProcessingManager()
    var selectedIdx = 0

    // --------------------------------------------------------
    // For text recognition
    // --------------------------------------------------------
    let tesseract = G8Tesseract(language: "eng+ita+osd")

    // --------------------------------------------------------
    // Function for critical section
    // --------------------------------------------------------
    public func synchronized(obj: AnyObject, closure: () -> Void) {
        objc_sync_enter(obj)
        closure()
        objc_sync_exit(obj)
    }
    
    // --------------------------------------------------------
    // ViewController overrides
    // --------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        
        // Configuration for video capture
        let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        let videoInput = try! AVCaptureDeviceInput(device: videoDevice)
        
        // Retaining into the variable to control from another functions
        self.videoDevice = videoInput.device
        
        // Configuration for output
        let myVideodataoutput = AVCaptureVideoDataOutput()
        myVideodataoutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)]
        myVideodataoutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.background))
        
        // Configuration for the capture session
        // Input
        self.session.addInput(videoInput)
        // Output
        self.session.addOutput(myVideodataoutput)
        
        //self.session.sessionPreset = AVCaptureSessionPresetHigh
        // Capture size
        self.session.sessionPreset = AVCaptureSessionPreset640x480
        
        var videoConnection: AVCaptureConnection?
        self.session.beginConfiguration()
        
        // Retrieving capture connection of video type
        for connection in myVideodataoutput.connections as! [AVCaptureConnection]
        {
            for port in connection.inputPorts as! [AVCaptureInputPort]{
                if port.mediaType == AVMediaTypeVideo{
                    videoConnection = connection
                }
            }
        }
        
        // Fix video capture orientation
        if videoConnection!.isVideoOrientationSupported{
            videoConnection?.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        try! videoDevice?.lockForConfiguration()

        // Setting FPS(20)
        videoDevice?.activeVideoMinFrameDuration = CMTimeMake(1, 20)
        videoDevice?.activeVideoMaxFrameDuration = CMTimeMake(1, 20)
        
        videoDevice?.unlockForConfiguration()
        
        self.session.commitConfiguration()
        self.session .startRunning()
        
        // Init for picker view
        filterPicker.delegate = self
        filterPicker.dataSource = self
        
        // Init for OCR
        self.tesseract?.delegate = self
        self.tesseract?.pageSegmentationMode = .autoOSD
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // --------------------------------------------------------
    // Callback for video capture session
    // --------------------------------------------------------
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        let inCIImage  = CIImage(cvImageBuffer: CMSampleBufferGetImageBuffer(sampleBuffer)!)
        
        // Filter
        let filter = self.imgProcManager.filters[selectedIdx]
        filter.setValue(inCIImage, forKey: "inputImage")
        self.sourceCIImage = filter.outputImage
        
        // Filter
        let context = CIContext()
        self.sourceCGImage = context.createCGImage(self.sourceCIImage!, from: (self.sourceCIImage?.extent)!)
        if let outImage = self.sourceCGImage{
            var uiimage = UIImage(cgImage: outImage)
            UIGraphicsBeginImageContextWithOptions(uiimage.size, false, 0.0)
            uiimage.draw(in: CGRect(x: 0.0, y: 0.0, width: uiimage.size.width, height: uiimage.size.height))

            // Finding text rects
            var recognizedText = ""
            if let textfeatures = self.imgProcManager.detector?.features(in: sourceCIImage!){
                for f in textfeatures {
                    // Adjusting coordinate between CoreImage and CoreGraphics
                    var rect = f.bounds
                    rect.origin.y = uiimage.size.height - (rect.origin.y + rect.size.height)
                    
                    // Drawing rect 
                    if let cgcontext = UIGraphicsGetCurrentContext(){
                        cgcontext.setLineWidth(3.0)
                        cgcontext.setStrokeColor(UIColor(red: 0.2, green: 0.2, blue: 0.8, alpha: 1.0).cgColor)
                        cgcontext.stroke(rect)
                    }
                    if self.detectSwitch.isOn {                        
                        // Recognition text by text rect (same as the above drawing rect)
                        if let textImage = outImage.cropping(to: rect){
                            self.synchronized(obj: self){
                                self.tesseract?.image = UIImage(cgImage:textImage).g8_blackAndWhite()
                                if (self.tesseract?.recognize())!{
                                    print("recognizedText: \(self.tesseract?.recognizedText)")
                                    
                                    self.synchronized(obj: self){
                                        recognizedText = (self.tesseract?.recognizedText)!
                                    }
                                }
                            }
                            // Updating UILabel in the main thread
                            DispatchQueue.main.async(execute: {
                                self.synchronized(obj: self){
                                    self.recogTextLabel.text = recognizedText
                                }
                            })
                        }
                    }
                }
            }
            uiimage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            // Updating ImageView in the main thread
            DispatchQueue.main.async(execute: {
                self.imageView.image = uiimage
            })
        }
    }
    
    // --------------------------------------------------------
    // UIPickerViewDataSource
    // --------------------------------------------------------
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
    {
        return self.imgProcManager.filters.count
    }
    
    // --------------------------------------------------------
    // UIPickerViewDelegate
    // --------------------------------------------------------
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
        return self.imgProcManager.filterNames[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedIdx = row
    }
}
