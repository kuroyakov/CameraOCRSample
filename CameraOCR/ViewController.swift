//
//  ViewController.swift
//  CameraOCR
//
//  Created by Katsutoshi Kuroya on 2016/11/24.
//  Copyright © 2016年 Katsutoshi Kuroya. All rights reserved.
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
    var session = AVCaptureSession()
    var sourceCIImage: CIImage?
    var sourceCGImage: CGImage?
    var JpegData: Data?
    var sendingBuffer: Data?
    var imgProcManager = ImageProcessingManager()
    var videoDevice : AVCaptureDevice?
    var selectedIdx = 0
    
    let tesseract = G8Tesseract(language: "eng+ita+osd")

    public func synchronized(obj: AnyObject, closure: () -> Void) {
        objc_sync_enter(obj)
        closure()
        objc_sync_exit(obj)
    }
    override func viewWillAppear(_ animated: Bool) {
        
        // キャプチャの設定
        // 動画タイプである
        let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        // 入力デバイスを取得
        let videoInput = try! AVCaptureDeviceInput(device: videoDevice)
        
        // デバイスを本オブジェクトに保持する（後で制御するため）
        self.videoDevice = videoInput.device
        
        // 出力の設定（連続画像モード）
        let myVideodataoutput = AVCaptureVideoDataOutput()
        myVideodataoutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)]
        myVideodataoutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.background))
        
        // キャプチャセッションの設定
        // 入力
        self.session.addInput(videoInput)
        // 出力
        self.session.addOutput(myVideodataoutput)
        
        //self.session.sessionPreset = AVCaptureSessionPresetHigh
        // 取得画像サイズをVGAにする
        self.session.sessionPreset = AVCaptureSessionPreset640x480
        
        var videoConnection: AVCaptureConnection?
        self.session.beginConfiguration()
        
        for connection in myVideodataoutput.connections as! [AVCaptureConnection]
        {
            for port in connection.inputPorts as! [AVCaptureInputPort]{
                if port.mediaType == AVMediaTypeVideo{
                    videoConnection = connection
                }
            }
        }
        
        if videoConnection!.isVideoOrientationSupported{
            videoConnection?.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        try! videoDevice?.lockForConfiguration()
        // FPSを30にする
        videoDevice?.activeVideoMinFrameDuration = CMTimeMake(1, 20)
        videoDevice?.activeVideoMaxFrameDuration = CMTimeMake(1, 20)
        
        videoDevice?.unlockForConfiguration()
        
        self.session.commitConfiguration()
        self.session .startRunning()
        
        filterPicker.delegate = self
        filterPicker.dataSource = self
        
        self.tesseract?.delegate = self
        self.tesseract?.pageSegmentationMode = .autoOSD
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // キャプチャ時に１フレーム取得するたびに呼ばれるコールバック
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
            // まずCIDetectorでテキスト領域認識をかける
            var recognizedText = ""
            if let textfeatures = self.imgProcManager.detector?.features(in: sourceCIImage!){
                for f in textfeatures {
                    // CIの座標系とCG座標系が違うのでCG変換する
                    var rect = f.bounds
                    rect.origin.y = uiimage.size.height - (rect.origin.y + rect.size.height)
                    
                    // uiimageに矩形を描画する
                    if let cgcontext = UIGraphicsGetCurrentContext(){
                        cgcontext.setLineWidth(3.0)
                        cgcontext.setStrokeColor(UIColor.blue.cgColor)
                        cgcontext.stroke(rect)
                    }
                    
                    // OCRにかける画像を切り取る
                    if let textImage = outImage.cropping(to: rect){
                        self.synchronized(obj: self){
                            self.tesseract?.image = UIImage(cgImage:textImage)
                            if (self.tesseract?.recognize())!{
                                print("recognizedText: \(self.tesseract?.recognizedText)")
                                
                                self.synchronized(obj: self){
                                    recognizedText = (self.tesseract?.recognizedText)!
                                }
                            }
                        }
                        DispatchQueue.main.async(execute: {
                            self.synchronized(obj: self){
                                self.recogTextLabel.text = recognizedText
                            }
                        })
                    }

                }
            }
            uiimage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            
            DispatchQueue.main.async(execute: {
                self.imageView.image = uiimage
            })
        }
    }
    
    /*
     pickerに表示する列数を返すデータソースメソッド.
     (実装必須)
     */
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    /*
     pickerに表示する行数を返すデータソースメソッド.
     (実装必須)
     */
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
    {
        return self.imgProcManager.filters.count
    }
    
    /*
     pickerに表示する値を返すデリゲートメソッド.
     */
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
        return self.imgProcManager.filterNames[row]
    }
    
    /*
     pickerが選択された際に呼ばれるデリゲートメソッド.
     */
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedIdx = row
    }
}
