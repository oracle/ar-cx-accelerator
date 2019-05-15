// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 12/12/18 11:18 AM
// *********************************************************************************************
// File: ARRect.swift
// *********************************************************************************************
// 

import ARKit

/**
 Helper to decode a rectangle from JSON.
 */
struct ARRect: Decodable {
    var width: Double
    var height: Double
    
    func getCGFrame() -> CGSize {
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }
    
    func getPlane() -> SCNPlane {
        return SCNPlane(width: CGFloat(width), height: CGFloat(height))
    }
}
