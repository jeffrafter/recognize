//
//  ViewController.swift
//  Recognize
//
//  Created by Jeffrey Rafter on 1/24/17.
//  Copyright © 2017 Jeffrey Rafter. All rights reserved.
//

import UIKit
import CoreImage
import GPUImage2
import AVFoundation

class ViewController: UIViewController {
    
    var pictureOutput = PictureOutput()
    
    var url: URL!

    var camera:Camera!
    
    @IBOutlet weak var outputLabel: UILabel!
    @IBOutlet weak var cropView: UIImageView!
    @IBOutlet weak var renderView: RenderView!
    @IBOutlet weak var screenView: UIView!
    
    override func viewDidLoad() {
       
        super.viewDidLoad()
        if let imageFileName = Bundle.main.path(forResource: "010001.bin", ofType: "png") {
            if let modelFileName = Bundle.main.path(forResource: "uw3-500-199999", ofType: "clstm") {
                let start = DispatchTime.now()
                let ptr : UnsafePointer<CChar> = clstm_recognize(modelFileName, imageFileName)
                let answer = String(cString: ptr)
                let end = DispatchTime.now()
                let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
                let timeInterval = Double(nanoTime) / 1_000_000_000
            
                print(answer)
                print(timeInterval)
            }
        }

        do {
            camera = try Camera(sessionPreset:AVCaptureSessionPreset640x480)
            camera --> renderView
            camera.startCapture()
        } catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func takeItTapped(_ sender: Any) {
        self.pictureOutput = PictureOutput()
        self.url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        self.camera.saveNextFrameToURLAndCallback(url, pictureOutput: self.pictureOutput, format:.png, rect: self.screenView.frame) { image, answer in
            self.cropView.image = image
            self.outputLabel.text = answer
        }
    }
}

extension UIImage {
    func crop(rect: CGRect) -> UIImage? {
        var scaledRect = rect
        scaledRect.origin.x *= scale
        scaledRect.origin.y *= scale
        scaledRect.size.width *= scale
        scaledRect.size.height *= scale
        guard let imageRef: CGImage = cgImage?.cropping(to: scaledRect) else {
            return nil
        }
        return UIImage(cgImage: imageRef, scale: scale, orientation: imageOrientation)
    }
    
    func scale(amount: CGFloat) -> UIImage? {
        let newSize = CGSize(width: self.size.width * amount, height: self.size.height * amount)
        UIGraphicsBeginImageContext(newSize)
        self.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

public extension ImageSource {
    public func saveNextFrameToURLAndCallback(_ url:URL, pictureOutput: PictureOutput, format:PictureFileFormat, rect: CGRect, completion: @escaping (UIImage, String) -> Void) {
        pictureOutput.onlyCaptureNextFrame = true
        pictureOutput.encodedImageFormat = format
        pictureOutput.imageAvailableCallback = {image in
            do {
                if let croppedImage = image.scale(amount: 1) {
                  if let imageData = UIImagePNGRepresentation(croppedImage) {
                    try imageData.write(to: url, options:.atomic)
                    
                    if let modelFileName = Bundle.main.path(forResource: "uw3-500-199999", ofType: "clstm") {
                        let start = DispatchTime.now()
                        let ptr : UnsafePointer<CChar> = clstm_recognize(modelFileName, url.absoluteString.replacingOccurrences(of: "file://", with: ""))
                        let answer = String(cString: ptr)
                        let end = DispatchTime.now()
                        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
                        let timeInterval = Double(nanoTime) / 1_000_000_000
                        
                        print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
                        print(answer)
                        print("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<")
                        print(timeInterval)
                        
                        DispatchQueue.main.async {
                            print(url)
                            do {
                              let data = try Data(contentsOf: url)
                              let segmentImage = UIImage(data: data)
                              completion(segmentImage!, answer)
                            } catch {
                                print("Aw dang")
                            
                            }
                        }                        
                    }
                  }
                }
            } catch {
                // TODO: Handle this better
                print("WARNING: Couldn't save image with error:\(error)")
            }
        }
        pictureOutput.saveNextFrameToURL(url, format:format)
        
        
        self --> pictureOutput
    }
}
