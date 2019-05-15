//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 4/3/19 7:46 PM
// *********************************************************************************************
// File: ServiceAppEvent.swift
// *********************************************************************************************
// 

import UIKit

/**
 Struct that represents a "stream" event to push to Service Cloud or Engagement Cloud custom objects for event logging.
 The current implementation of this struct can be used for both request and response payloads from ICS.
 */
struct ServiceAppEvent: Codable {
    
    // MARK: - Properties
    
    var name: String?
    var startTime: Date?
    var endTime: Date?
    var eventLength: Float = 0.0
    var uiElementName: String?
    var encodedScreenshot: String?
    var jsonData: String?
    
    // MARK: - Enums
    
    enum CodingKeys: String, CodingKey {
        case name = "EventName",
        startTime = "StartTime",
        endTime = "EndTime",
        eventLength = "EventLength",
        uiElementName = "UIElementName",
        encodedScreenshot = "Screenshot",
        jsonData = "JSONData"
    }
    
    //MARK: - Initializer Methods
    
    init() {
        
    }
    
    init (name: String) {
        self.name = name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try? container.decode(String.self, forKey: .name)
        uiElementName = try? container.decode(String.self, forKey: .uiElementName)
        encodedScreenshot = try? container.decode(String.self, forKey: .encodedScreenshot)
        jsonData = try? container.decode(String.self, forKey: .jsonData)
        
        if let lengthStr = try? container.decode(String.self, forKey: .eventLength) {
            let lenth = Float(lengthStr)
            eventLength = lenth ?? 0.0
        }
        
        let formatter = ISO8601DateFormatter()
        
        if let eventStartStr = try? container.decode(String.self, forKey: .startTime) {
            let date = formatter.date(from: eventStartStr)
            startTime = date
        }
        
        if let eventEndStr = try? container.decode(String.self, forKey: .endTime) {
            let date = formatter.date(from: eventEndStr)
            endTime = date
        }
    }
    
    //MARK: - Codable Methods
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(uiElementName, forKey: .uiElementName)
        try container.encode(encodedScreenshot, forKey: .encodedScreenshot)
        try container.encode(jsonData, forKey: .jsonData)
        try container.encode(String(eventLength), forKey: .eventLength)
        
        let formatter = ISO8601DateFormatter()
        
        if let startTime = self.startTime {
            let dateStr = formatter.string(from: startTime)
            try container.encode(dateStr, forKey: .startTime)
        }
        
        if let endTime = self.endTime {
            let dateStr = formatter.string(from: endTime)
            try container.encode(dateStr, forKey: .endTime)
        }
    }
}
