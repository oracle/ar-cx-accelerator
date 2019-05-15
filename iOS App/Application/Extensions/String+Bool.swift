// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 11/8/18 10:47 AM
// *********************************************************************************************
// File: String+Bool.swift
// *********************************************************************************************
// 

import Foundation

extension String{
    /**
     String to bool conversion.
     */
    var boolValue: Bool {
        return NSString(string: self).boolValue
    }
}
