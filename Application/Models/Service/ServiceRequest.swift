//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ServiceRequest.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct to represent the AR model object in the service application data model.  This structure will be the same in Engagement Cloud or Service Cloud if the accelerator configuration documentation is followed.
 */
struct ARDevice : Codable {
    var deviceId: String?
    var partId: String?
    var temperature: String?
    var vibration: String?
    var sound: String?
    var rpm: String?
}

/**
 Struct to represent the ServiceRequest JSON object sent to ICS for creation.
 */
struct ServiceRequestRequest : Encodable {
    var image: String?
    var primaryContact: NamedId
    var subject: String?
    var notes: String?
    var device: ARDevice?
    
    init() {
        self.primaryContact = NamedId()
    }
}

/**
 Struct to represent the ServiceRequestResponse JSON object returned from ICS
 */
struct ServiceRequestResponse : Decodable {
    struct Contact : Decodable {
        var id: String? // Could be a string in Engagement Cloud
        var firstName: String?
        var lastName: String?
    }
    
    var id: String? // a string in Engagement Cloud
    var referenceNumber: String?
    var subject: String?
    var contact: Contact?
    var device: ARDevice?
    
    enum CodingKeys: String, CodingKey {
        case id = "srId",
        referenceNumber = "srReferenceNumber",
        subject = "srSubject",
        contact = "srContact",
        device = "srDevice"
    }
}

/**
 Struct to represent the ServiceRequestArrayResponse JSON object returned from ICS
 */
struct ServiceRequestArrayResponse : Decodable {
    var items: [ServiceRequestResponse]?
}
