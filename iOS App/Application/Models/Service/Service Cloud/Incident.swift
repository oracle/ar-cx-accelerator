//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 7/8/19 3:25 PM
// *********************************************************************************************
// File: Incident.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct that represents an incident request object to create a new record.
 */
struct IncidentRequest: Encodable {
    var customFields: CustomFields?
    var primaryContact: PrimaryContact
    var subject: String
    
    struct CustomFields: Codable {
        let ar: AR?
        
        enum CodingKeys: String, CodingKey {
            case ar = "AR"
        }
        
        struct AR: Codable {
            var deviceId, partId, sensors: String?
        }
    }
    
    struct PrimaryContact: Codable {
        let id: Int?
    }
    
    init(primaryContactId: Int, subject: String) {
        self.subject = subject
        self.primaryContact = PrimaryContact(id: primaryContactId)
    }
}

/**
 Struct that represents an incident response object from a query.
 */
struct IncidentResponse: Decodable {
    let id: Int?
    let lookupName, createdTime, updatedTime, closedTime: String?
    let asset: NamedID?
    let assignedTo: AssignedTo?
    let banner: Banner?
    let billedMinutes: BilledMinutes?
    let category, channel, chatQueue: NamedID?
    let createdByAccount: CreatedByAccount?
    let customFields: CustomFields?
    let disposition: NamedID?
    let fileAttachments: BilledMinutes?
    let initialResponseDueTime: String?
    let initialSolutionTime: NamedID?
    let interface: CreatedByAccount?
    let language: NamedID?
    let lastResponseTime, lastSurveyScore, mailbox, mailing: NamedID?
    let milestoneInstances: BilledMinutes?
    let organization: NamedID?
    let otherContacts: BilledMinutes?
    let primaryContact: CreatedByAccount?
    let product, queue: NamedID?
    let referenceNumber: String?
    let resolutionInterval: Int?
    let responseEmailAddressType: NamedID?
    let responseInterval: Int?
    let severity, sLAInstance: NamedID?
    let smartSenseCustomer: Bool?
    let smartSenseStaff: NamedID?
    let source: Source?
    let statusWithType: StatusWithType?
    let subject: String?
    let threads: BilledMinutes?
    let links: [CreatedByAccountLink]?
    
    struct AssignedTo: Decodable {
        let account, staffGroup: NamedID?
    }
    
    struct Banner: Decodable {
        let importanceFlag, text, updatedByAccount, updatedTime: NamedID?
    }
    
    struct BilledMinutes: Codable {
        let links: [BilledMinutesLink]?
    }
    
    struct BilledMinutesLink: Codable {
        let rel: PathRel?
        let href: String?
        let templated: Bool?
    }
    
    enum PathRel: String, Codable {
        case full = "full"
        case relSelf = "self"
    }
    
    struct CreatedByAccount: Codable {
        let links: [CreatedByAccountLink]?
    }
    
    struct CreatedByAccountLink: Codable {
        let rel: DescriptionRel?
        let href: String?
        let mediaType: String?
    }
    
    enum DescriptionRel: String, Codable {
        case canonical = "canonical"
        case describedby = "describedby"
        case relSelf = "self"
    }
    
    struct CustomFields: Decodable {
        let ar: AR?
        let ml: Ml?
        
        enum CodingKeys: String, CodingKey {
            case ar = "AR"
            case ml = "ML"
        }
        
        struct AR: Decodable {
            let deviceId: String?
            let partId: String?
            let sensors: String?
        }
        
        struct Ml: Decodable {
            let createdByPrediction, device, deviceRPM, deviceTemp: NamedID?
            let predictionScore: NamedID?
            
            enum CodingKeys: String, CodingKey {
                case createdByPrediction = "CreatedByPrediction"
                case device = "Device"
                case deviceRPM = "DeviceRPM"
                case deviceTemp = "DeviceTemp"
                case predictionScore = "PredictionScore"
            }
        }
    }
    
    struct Source: Decodable {
        let id: Int?
        let lookupName: String?
        let parents: [NamedID]?
    }
    
    struct StatusWithType: Decodable {
        let status, statusType: NamedID?
    }
}

/**
 Struct that represents an array of incident request objects.
 */
struct IncidentArrayResponse: Decodable {
    var items: [IncidentResponse]?
}
