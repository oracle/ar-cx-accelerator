// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/5/18 6:18 PM
// *********************************************************************************************
// File: Float+Radians.swift
// *********************************************************************************************
// 

import Foundation

extension FloatingPoint {
    
    /**
     Convert degrees to radians.
    */
    var degreesToRadians: Self {
        return self * .pi / 180
    }
    
    /**
     Convert radians to degrees.
     */
    var radiansToDegrees: Self {
        return self * 180 / .pi
    }
}
