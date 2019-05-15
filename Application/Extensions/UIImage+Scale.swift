// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/2/18 2:22 PM
// *********************************************************************************************
// File: UIImage+Scale.swift
// *********************************************************************************************
// 

import UIKit

extension UIImage {
    /**
     UIImage extension method that will scale an image to the new size provided.
     
     - Parameter newSize: A CGSize that defines the height and width of the new image.
     
     - Returns: A new UIImage object.
    */
    func scaleImage(_ newSize: CGSize) -> UIImage? {
        var imageRatio: CGFloat!
        
        if self.size.width > self.size.height {
            imageRatio = newSize.width / self.size.width
        } else {
            imageRatio = newSize.height / self.size.height
        }
        
        let newRect = CGRect(x: 0, y: 0, width: self.size.width * imageRatio, height: self.size.height * imageRatio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        
        self.draw(in: newRect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        return newImage
    }
    
    /**
     UIImage extension method that will scale an image proportionately based on the new width provided.
     
     - Parameter newWidth: The width to scale the image to.
     
     - Returns: A new UIImage object.
     */
    func scaleImage(toWidth newWidth: CGFloat) -> UIImage? {
        let imageRatio: CGFloat = self.size.height / self.size.width
        
        let newHeight = newWidth * imageRatio
        let newSize = CGSize(width: newWidth, height: newHeight)
        let newRect = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        
        self.draw(in: newRect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        return newImage
    }
}
