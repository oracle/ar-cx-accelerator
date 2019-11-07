//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/23/19 8:18 AM
// *********************************************************************************************
// File: OciFunctions.swift
// *********************************************************************************************
// 

import Foundation

/**
 A struct that represents a single record from the OCI Functions get application functions request.
 */
struct OciFunction: Codable {
    
    // Properties
    
    let id, name, appID, image: String
    let memory, timeout, idleTimeout: Int
    let config: Config?
    let annotations: Annotations
    let createdAt, updatedAt: String
    
    // Sub-Structs

    struct Annotations: Codable {
        let fnprojectIoFnInvokeEndpoint: String
        let oracleCOMOciCompartmentID, oracleCOMOciImageDigest: String

        enum CodingKeys: String, CodingKey {
            case fnprojectIoFnInvokeEndpoint = "fnproject.io/fn/invokeEndpoint"
            case oracleCOMOciCompartmentID = "oracle.com/oci/compartmentId"
            case oracleCOMOciImageDigest = "oracle.com/oci/imageDigest"
        }
    }

    struct Config: Codable {
        let application, applicationHostName, contactID, knowledgeContentHostName: String?
        let knowledgeSearchHostName, hostname, password, username: String?
        let sitename: String?

        enum CodingKeys: String, CodingKey {
            case application, applicationHostName
            case contactID = "contactId"
            case knowledgeContentHostName, knowledgeSearchHostName, hostname, password, username, sitename
        }
    }
    
    // Enums

    enum CodingKeys: String, CodingKey {
        case id, name
        case appID = "app_id"
        case image, memory, timeout
        case idleTimeout = "idle_timeout"
        case config, annotations
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/**
A struct that represents the result set from the OCI Functions get application functions request.
*/
struct OciFunctionsApplicationFunctionsResponse: Decodable {
    var items: [OciFunction]?
}
