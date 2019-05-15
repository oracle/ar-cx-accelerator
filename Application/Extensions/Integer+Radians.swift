// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/5/18 6:17 PM
// *********************************************************************************************
// File: Integer+Radians.swift
// *********************************************************************************************
// 

import CoreGraphics

extension BinaryInteger {
    /**
     Convert degress to radians.
    */
    var degreesToRadians: CGFloat {
        return CGFloat(Int(self)) * .pi / 180
    }
}
