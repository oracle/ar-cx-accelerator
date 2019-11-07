//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 4/19/19 2:13 PM
// *********************************************************************************************
// File: Error+Log.swift
// *********************************************************************************************
// 

import Foundation
import os

extension Error {
    func log() {
        os_log(.error, "%@", String(format: "\(self)"))
    }
}
