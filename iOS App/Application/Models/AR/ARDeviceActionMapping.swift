//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/19/19 4:09 PM
// *********************************************************************************************
// File: ARDeviceActionMapping.swift
// *********************************************************************************************
// 

import Foundation

/**
 Decodable that represents a mapping between IoT device ID and actions within the AR application.
 For instance, this mapping will tell the app whether to trigger an IoT even after procedures are over.
 */
struct ARDeviceActionMapping: Decodable {
    var deviceId: String?
    var applicationId: String?
    var arAppEvent: ARAppEvent?
    var iotTriggerName: String?
    
    enum ARAppEvent: String, CaseIterable {
        case procedureEnd
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceId,
        applicationId,
        arAppEvent,
        iotTriggerName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        deviceId = try? container.decode(String.self, forKey: .deviceId)
        applicationId = try? container.decode(String.self, forKey: .applicationId)
        iotTriggerName = try? container.decode(String.self, forKey: .iotTriggerName)
        
        let appEvent = try? container.decode(String.self, forKey: .arAppEvent)
        for type in ARAppEvent.allCases {
            if type.rawValue == appEvent {
                self.arAppEvent = type
                break
            }
        }
    }
}

/**
 Struct that represents an API response with many action mappings.
 */
struct ARDeviceActionMappingArrayResponse: Decodable {
    var items: [ARDeviceActionMapping]?
}
