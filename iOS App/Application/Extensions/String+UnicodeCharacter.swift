//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/4/19 3:53 PM
// *********************************************************************************************
// File: String+UnicodeCharacter.swift
// *********************************************************************************************
// 

import Foundation

extension String {
    var toUnicodeCharacter: Character? {
        guard let uInt = UInt32(hexString: self) else { return nil }
        guard let uScalar = UnicodeScalar(uInt) else { return nil }
        let unicodeCharacter = Character(uScalar)
        return unicodeCharacter
    }
}
