//
//  ViewController.swift
//  Camera
//
//  Created by Marton Kerekes on 26/04/2017.
//  Copyright © 2017 Marton Kerekes. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation

class ViewController: UIViewController {

    var selectedImage: UIImage? {
        willSet {
            prepare(newValue!)
        }
    }

    @IBOutlet var imageView: UIImageView!
    var topLeftVector: CIVector?
    var topRightVector: CIVector?
    var bottomRightVector: CIVector?
    var bottomLeftVector: CIVector?

    var topLeftDragButton: UIView?
    var topRightDragButton: UIView?
    var bottomRightDragButton: UIView?
    var bottomLeftDragButton: UIView?

    var perspectiveTransform: CIFilter?
    var composite: CIFilter?

    var image: CIImage?

    @IBAction func presentImagePicker(_ sender: Any) {
        imageView.subviews.forEach { $0.removeFromSuperview() }
        imageView.image = nil
        navigationItem.leftBarButtonItem = nil
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera)!
        present(imagePicker, animated: true, completion: nil)
    }

    func prepare(_ inputImage: UIImage) {
        image = CIImage(image: inputImage.normalizedImage())
        let ciContext =  CIContext()
        let detector = CIDetector(ofType: CIDetectorTypeRectangle, context: ciContext, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        guard let ciImage = image, let rect = detector?.features(in: ciImage).first as? CIRectangleFeature else {
            showError(with: "Couldn't get region")
            return
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Draw", style: .done, target: self, action: #selector(drawFullSize))
        drawPerspective(with: rect, on: ciImage)
    }

    func showError(with message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func drawSimpleOverlay(on image: CIImage) {
        let overlay = CIImage(image: UIImage(color: UIColor.yellow)!)
        let rect = image.extent.insetBy(dx: 25, dy: 25)
        let perspectiveTransform = CIFilter(name: "CIPerspectiveTransform")!
        perspectiveTransform.setValue(CIVector(cgPoint:CGPoint(x: rect.minX, y: rect.minY)), forKey: "inputTopLeft")
        perspectiveTransform.setValue(CIVector(cgPoint:CGPoint(x: rect.maxX, y: rect.minY)), forKey: "inputTopRight")
        perspectiveTransform.setValue(CIVector(cgPoint:CGPoint(x: rect.maxX, y: rect.maxY)), forKey: "inputBottomRight")
        perspectiveTransform.setValue(CIVector(cgPoint:CGPoint(x: rect.minX, y: rect.maxY)), forKey: "inputBottomLeft")
        perspectiveTransform.setValue(overlay, forKey: kCIInputImageKey)

        let composite = CIFilter(name: "CISourceAtopCompositing")!
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        composite.setValue(perspectiveTransform.outputImage!, forKey: kCIInputImageKey)

        imageView.image = UIImage(ciImage: composite.outputImage!)
    }

    func drawFullSize() {
        imageView.subviews.forEach { $0.removeFromSuperview() }
        let finalTransform = CIFilter(name: "CIPerspectiveCorrection")!
        finalTransform.setValue(topLeftVector!, forKey: "inputTopLeft")
        finalTransform.setValue(topRightVector!, forKey: "inputTopRight")
        finalTransform.setValue(bottomRightVector!, forKey: "inputBottomRight")
        finalTransform.setValue(bottomLeftVector!, forKey: "inputBottomLeft")
        finalTransform.setValue(image, forKey: kCIInputImageKey)

        guard let crop = finalTransform.outputImage else {
            showError(with: "Couldn't crop")
            return
        }

        imageView.image = UIImage(ciImage: crop)
        self.navigationItem.leftBarButtonItem = nil
    }

    func drawPerspective(with rect: CIRectangleFeature, on image: CIImage) {
        let overlayImage = UIImage(color: UIColor.red.withAlphaComponent(0.3), size: rect.bounds.size)!
        let overlay = CIImage(image: overlayImage)
        perspectiveTransform = CIFilter(name: "CIPerspectiveTransform")!

        topLeftVector = CIVector(cgPoint:rect.topLeft)
        perspectiveTransform?.setValue(topLeftVector!, forKey: "inputTopLeft")
        topLeftDragButton = addDraggableButton(at: rect.topLeft, from: image.extent, to: imageView.frame)
        imageView.addSubview(topLeftDragButton!)

        topRightVector = CIVector(cgPoint:rect.topRight)
        perspectiveTransform?.setValue(topRightVector!, forKey: "inputTopRight")
        topRightDragButton = addDraggableButton(at: rect.topRight, from: image.extent, to: imageView.frame)
        imageView.addSubview(topRightDragButton!)

        bottomRightVector = CIVector(cgPoint:rect.bottomRight)
        perspectiveTransform?.setValue(bottomRightVector!, forKey: "inputBottomRight")
        bottomRightDragButton = addDraggableButton(at: rect.bottomRight, from: image.extent, to: imageView.frame)
        imageView.addSubview(bottomRightDragButton!)

        bottomLeftVector = CIVector(cgPoint:rect.bottomLeft)
        perspectiveTransform?.setValue(bottomLeftVector!, forKey: "inputBottomLeft")
        bottomLeftDragButton = addDraggableButton(at: rect.bottomLeft, from: image.extent, to: imageView.frame)
        imageView.addSubview(bottomLeftDragButton!)

        perspectiveTransform?.setValue(overlay, forKey: kCIInputImageKey)

        render()
    }

    func render() {
        guard let perspectiveImage = perspectiveTransform?.outputImage else {
            showError(with: "Could not trim image")
            return
        }
        composite = CIFilter(name: "CISourceAtopCompositing")!
        composite?.setValue(image, forKey: kCIInputBackgroundImageKey)
        composite?.setValue(perspectiveImage, forKey: kCIInputImageKey)

        guard let outputImage = composite?.outputImage else {
            showError(with: "Could not render image")
            return
        }
        imageView.image = UIImage(ciImage: outputImage)
        imageView.isUserInteractionEnabled = true
    }

    func addDraggableButton(at point: CGPoint, from ciImageRect: CGRect, to imageViewRect: CGRect) -> UIView? {
        let normalizedPoint = normalizePoint(point, from: ciImageRect, to: imageViewRect)
        guard let image = UIImage(color: UIColor.blue.withAlphaComponent(0.5), size: CGSize(width: 40, height: 40)) else {
            return nil
        }
        let dragView = UIImageView(image: image)
        dragView.isUserInteractionEnabled = true
        dragView.center = CGPoint(x: normalizedPoint.x, y: normalizedPoint.y)
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        dragView.addGestureRecognizer(gesture)
        return dragView
    }

    func normalizePoint(_ point: CGPoint, from ciImageRect: CGRect, to imageViewRect: CGRect) -> CGPoint {
        let xFactor = imageViewRect.width / ciImageRect.width
        let yFactor = imageViewRect.height / ciImageRect.height
        let transform = CGAffineTransform(scaleX: xFactor, y: yFactor);
        let transformedPoint = point.applying(transform)
        return CGPoint(x: transformedPoint.x, y: imageViewRect.height - transformedPoint.y)
    }

    func coreImagePoint(_ point: CGPoint, from imageViewRect: CGRect, to ciImageRect: CGRect) -> CGPoint {
        let xFactor = ciImageRect.width / imageViewRect.width
        let yFactor = ciImageRect.height / imageViewRect.height
        let transform = CGAffineTransform(scaleX: xFactor, y: yFactor);
        let transformedPoint = point.applying(transform)
        return CGPoint(x: transformedPoint.x, y: ciImageRect.height - transformedPoint.y)
    }

    @objc func didPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let point = gestureRecognizer.location(in: imageView)
        switch (gestureRecognizer.state, gestureRecognizer.view) {
        case (.changed, let draggedView):
            gestureRecognizer.view?.center = point
            guard let ciImage = image else {
                return
            }
            let ciPoint = coreImagePoint(point, from: imageView.frame, to: ciImage.extent)
            if draggedView == topLeftDragButton {
                topLeftVector = CIVector(cgPoint: ciPoint)
                perspectiveTransform?.setValue(topLeftVector!, forKey: "inputTopLeft")
            } else if draggedView == topRightDragButton {
                topRightVector = CIVector(cgPoint: ciPoint)
                perspectiveTransform?.setValue(topRightVector!, forKey: "inputTopRight")
            } else if draggedView == bottomRightDragButton {
                bottomRightVector = CIVector(cgPoint: ciPoint)
                perspectiveTransform?.setValue(bottomRightVector!, forKey: "inputBottomRight")
            } else if draggedView == bottomLeftDragButton {
                bottomLeftVector = CIVector(cgPoint: ciPoint)
                perspectiveTransform?.setValue(bottomLeftVector!, forKey: "inputBottomLeft")
            }
            render()
        default:
            ()
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: false) {
            self.selectedImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: false, completion: nil)
    }
}

extension UIImage {

    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        let scaleFactorForTesting: CGFloat = 1.0
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scaleFactorForTesting)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }

    func normalizedImage() -> UIImage {

        if (self.imageOrientation == UIImageOrientation.up) {
            return self;
        }

        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale);
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        self.draw(in: rect)
        
        let normalizedImage : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext();
        return normalizedImage;
    }
}

