//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 7/9/19 12:14 PM
// *********************************************************************************************
// File: Thread.swift
// *********************************************************************************************
// 

import Foundation

struct IncidentThread: Codable {
    var account: NamedID?
    var channel: NamedID?
    var contact: NamedID?
    var contentType: NamedID?
    var createdTime: String?
    var displayOrder: Int?
    var entryType: NamedID?
    var id: Int?
    var text: String?
}
