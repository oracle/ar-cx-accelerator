//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: String+Capitalization.swift
// *********************************************************************************************
// 

import Foundation

extension String {
    
    /**
     Returns a new string with the first letter uppercased.
     */
    var firstUppercased: String? {
        guard let first = first else { return nil }
        return String(first).uppercased() + dropFirst()
    }
    
    /**
     Returns a new string with the first letter capitalized and others lowercased.
     */
    var firstCapitalized: String? {
        guard let first = first else { return nil }
        return String(first).capitalized + dropFirst()
    }
    
    /**
     Converts the current string to a capitalized string.
     */
    mutating func capitalizeFirstLetter() {
        self = self.firstCapitalized ?? ""
    }
}
