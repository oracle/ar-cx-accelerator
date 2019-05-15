// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/22/18 10:01 AM
// *********************************************************************************************
// File: ContextImage.swift
// *********************************************************************************************
// 

import UIKit

/**
 Provides two different parameters to provide an image to display.  If a URL is present, then the image will be pulled from that URL.  If the name is present, then we will examine the .xcassets files for an image with that name and display it.
 
 The URL field will take priority over a name when both fields are provided.
 */
struct ContextImage: Decodable {
    /**
     The name of an image in demo.xcassets to display.
     */
    var name: String?
    
    /**
     A URL path to a supported image file.
     */
    var url: String?
    
    /**
     Base64 string of the image.
     */
    var data: String?
    
    /**
     Coding keys for JSON deconstruction.
     */
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case url = "url"
        case data = "data"
    }
    
    /**
     Attempts to return a UIImage from the data in this struct.
     Data strings are examined first, then URL links, then file names for images in xcasset packages.
     
     - Returns: The image retrieved or nil.
     */
    func getImage() -> UIImage? {
        var image: UIImage?
        
        if let dataStr = data, let data = Data(base64Encoded: dataStr) {
            image = UIImage(data: data)
        }
        else if let urlStr = url, let url = URL(string: urlStr) {
            do {
                let data = try Data(contentsOf: url)
                image = UIImage(data: data)
            } catch {
                error.log()
            }
        }
        else if let name = name {
            image = UIImage(named: name)
        }
        
        return image
    }
}
