// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 12/12/18 11:17 AM
// *********************************************************************************************
// File: ARPoint.swift
// *********************************************************************************************
// 

import ARKit

struct ARPoint: Decodable {
    var x: Double
    var y: Double
    
    func getPoint() -> CGPoint {
        return CGPoint(x: x, y: y)
    }
}
