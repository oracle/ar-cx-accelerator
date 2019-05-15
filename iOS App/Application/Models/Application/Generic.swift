// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/28/18 9:26 AM
// *********************************************************************************************
// File: Generic.swift
// *********************************************************************************************
// 

import Foundation

/**
 Link struct that is shared among REST API calls to CX applications
 */
struct Link : Decodable {
    var rel: String?
    var href: String?
    var mediaType: String?
}

/**
 Generic items list struct that is shared among REST API calls to CX applications
 */
struct ItemList: Decodable {
    var items: [Link]?
    var links: [Link]?
}

/**
 Struct to represent the NamedID JSON object returned from the Service Cloud data model
 */
struct NamedId : Codable {
    var id: Int?
    var lookupName: String?
}
