//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 4:04 PM
// *********************************************************************************************
// File: ARNodeDetail.swift
// *********************************************************************************************
// 

import Foundation

/**
 A data type used in querying for node data that is server side.  This data should be rolled into ARNodeContext when the full ARNodeContext structure can be stored remotely.
 */
struct ARNodeDetail: Decodable {
    var id: Int?
    var lookupName: String?
    var node: String?
    
    enum CodingKeys: String, CodingKey {
        case id,
        lookupName,
        node = "Node"
    }
}

struct ARNodeDetailArrayResponse: Decodable {
    var items: [ARNodeDetail]?
}
