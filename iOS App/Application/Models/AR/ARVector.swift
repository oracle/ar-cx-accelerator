// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 12/4/18 2:44 PM
// *********************************************************************************************
// File: ARVector.swift
// *********************************************************************************************
// 

import SceneKit

/**
 Definition for a simple vector type that can be interpreted from JSON.
 */
struct ARVector: Decodable {
    var x: Double
    
    var y: Double
    
    var z: Double
    
    func getVector3() -> SCNVector3 {
        return SCNVector3(x, y, z)
    }
    
    func getVector3Radians() -> SCNVector3 {
        return SCNVector3(x.degreesToRadians, y.degreesToRadians, z.degreesToRadians)
    }
}
