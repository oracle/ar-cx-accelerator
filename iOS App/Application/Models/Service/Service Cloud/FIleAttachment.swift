//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/23/19 4:43 PM
// *********************************************************************************************
// File: FIleAttachment.swift
// *********************************************************************************************
// 

import Foundation

struct FileAttachment: Encodable {
    /**
    The name of the file attachment.
     */
    var fileName: String
    
    /**
    Base64 encoded string of the attachment data.
     */
    var data: String
}
