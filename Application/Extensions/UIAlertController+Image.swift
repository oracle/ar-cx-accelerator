// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/2/18 1:26 PM
// *********************************************************************************************
// File: UIAlertController+Image.swift
// *********************************************************************************************
// 

import UIKit

extension UIAlertController {
    /**
     Add an action to this alert controller with an image.
     
     - Parameter image: The image to display in the alert.
     - Parameter size: The size of the image to display.
     */
    func addImageAction(_ image: UIImage, size: CGSize = CGSize(width: 240, height: 240)) {
        
        guard let resizedImage = image.scaleImage(size) else { return }
        
        let imageAction = UIAlertAction(title: "", style: .default, handler: nil)
        imageAction.setValue(resizedImage.withRenderingMode(.alwaysOriginal), forKey: "image")
        
        self.addAction(imageAction)
    }
}
