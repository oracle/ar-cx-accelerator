//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: IoT.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct to represent the IoTDevice JSON object returned from ICS
 */
struct IoTDevice : Decodable {
    var id: String?
    var hardwareId: String?
    var type: String?
    var description: String?
    var created: Int?
    var createdAsString: String?
    var activationTime: Int?
    var activationTimeAsString: String?
    var state: String?
    var name: String?
    var manufacturer: String?
    var modelNumber: String?
    var serialNumber: String?
    var hardwareRevision: String?
    var softwareRevision: String?
    var softwareVersion: String?
    var enabled: Bool?
    var deviceModels: [DeviceModel]?
    
    struct DeviceModel : Decodable {
        var urn: String?
        var name: String?
        var description: String?
        var system: Bool?
        var draft: Bool?
        var created: Int?
        var createdAsString: String?
        var lastModified: Int?
        var lastModifiedAsString: String?
        var userLastModified: String?
        var formats: [DeviceFormat]?
        var attributes: [DeviceAttribute]?
        
        struct DeviceFormat : Decodable {
            var urn: String?
            var name: String?
            var description: String?
            var type: String?
            var deviceModel: String?
            var sourceId: String?
            var sourceType: String?
            var value: DeviceValue?
            
            struct DeviceValue : Decodable {
                var fields: [DeviceField]?
                
                struct DeviceField : Decodable {
                    var name: String?
                    var optional: Bool?
                    var type: String?
                    
                    enum CodingKeys: String, CodingKey {
                        case name,
                        optional,
                        type
                    }
                    
                    // ICS doesn't properly convert bools; it leaves them as strings.  We need to perform the convertion here.
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        
                        name = try? container.decode(String.self, forKey: .name)
                        type = try? container.decode(String.self, forKey: .type)
                        
                        if let optional = try? container.decode(Bool.self, forKey: .optional) {
                            self.optional = optional
                        }
                        else if let optional = try? container.decode(String.self, forKey: .optional) {
                            self.optional = optional.boolValue
                        }
                    }
                }
            }
        }
        
        struct DeviceAttribute : Codable {
            var description: String?
            var name: String?
            var range: String?
            var type: String?
            var writable: Bool?
            
            private enum CodingKeys: String, CodingKey {
                case description,
                name,
                range,
                type,
                writable
            }
            
            // ICS doesn't properly convert bools; it leaves them as strings.  We need to perform the convertion here.
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                description = try? container.decode(String.self, forKey: .description)
                name = try? container.decode(String.self, forKey: .name)
                range = try? container.decode(String.self, forKey: .range)
                type = try? container.decode(String.self, forKey: .type)
                
                if let writable = try? container.decode(Bool.self, forKey: .writable) {
                    self.writable = writable
                }
                else if let writable = try? container.decode(String.self, forKey: .writable) {
                    self.writable = writable.boolValue
                }
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case urn,
            name,
            description,
            system,
            draft,
            created,
            createdAsString,
            lastModified,
            lastModifiedAsString,
            userLastModified,
            formats,
            attributes
        }
        
        // ICS doesn't properly convert bools; it leaves them as strings.  We need to perform the convertion here.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            urn = try? container.decode(String.self, forKey: .urn)
            name = try? container.decode(String.self, forKey: .name)
            description = try? container.decode(String.self, forKey: .description)
            created = try? container.decode(Int.self, forKey: .created)
            createdAsString = try? container.decode(String.self, forKey: .createdAsString)
            lastModified = try? container.decode(Int.self, forKey: .lastModified)
            lastModifiedAsString = try? container.decode(String.self, forKey: .lastModifiedAsString)
            formats = try? container.decode([DeviceFormat].self, forKey: .formats)
            attributes = try? container.decode([DeviceAttribute].self, forKey: .attributes)
            
            if let system = try? container.decode(Bool.self, forKey: .system) {
                self.system = system
            }
            else if let system = try? container.decode(String.self, forKey: .system) {
                self.system = system.boolValue
            }
            
            if let draft = try? container.decode(Bool.self, forKey: .draft) {
                self.draft = draft
            }
            else if let draft = try? container.decode(String.self, forKey: .draft) {
                self.draft = draft.boolValue
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id,
        hardwareId,
        type,
        description,
        created,
        createdAsString,
        activationTime,
        activationTimeAsString,
        state,
        name,
        manufacturer,
        modelNumber,
        serialNumber,
        hardwareRevision,
        softwareRevision,
        softwareVersion,
        enabled,
        deviceModels
    }
    
    // ICS doesn't properly convert bools; it leaves them as strings.  We need to perform the convertion here.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try? container.decode(String.self, forKey: .id)
        hardwareId = try? container.decode(String.self, forKey: .hardwareId)
        type = try? container.decode(String.self, forKey: .type)
        description = try? container.decode(String.self, forKey: .description)
        created = try? container.decode(Int.self, forKey: .created)
        createdAsString = try? container.decode(String.self, forKey: .createdAsString)
        activationTime = try? container.decode(Int.self, forKey: .activationTime)
        activationTimeAsString = try? container.decode(String.self, forKey: .activationTimeAsString)
        state = try? container.decode(String.self, forKey: .state)
        name = try? container.decode(String.self, forKey: .name)
        manufacturer = try? container.decode(String.self, forKey: .manufacturer)
        modelNumber = try? container.decode(String.self, forKey: .modelNumber)
        serialNumber = try? container.decode(String.self, forKey: .serialNumber)
        hardwareRevision = try? container.decode(String.self, forKey: .hardwareRevision)
        softwareRevision = try? container.decode(String.self, forKey: .softwareRevision)
        softwareVersion = try? container.decode(String.self, forKey: .softwareVersion)
        deviceModels = try? container.decode([DeviceModel].self, forKey: .deviceModels)
        
        if let enabled = try? container.decode(Bool.self, forKey: .enabled) {
            self.enabled = enabled
        }
        else if let enabled = try? container.decode(String.self, forKey: .enabled) {
            self.enabled = enabled.boolValue
        }
    }
}

/**
 Struct to represent the return of multiple IoT Device response
 */
struct IoTDeviceResponse: Decodable {
    var items: [IoTDevice]?
}

/**
 Struct to represent the SensorMessageResponse JSON object returned from ICS
 */
struct SensorMessageResponse : Decodable {
    var items: [SensorMessage]?
}

/**
 Struct to represent the SensorMessage JSON object returned from ICS
 */
struct SensorMessage : Codable {
    enum MessageType: String {
        case bestEffort = "BEST_EFFORT",
        projection = "Projection"
    }
    
    var id: String?
    var clientId: String?
    var source: String?
    var destination: String?
    var priority: String?
    var reliability: String?
    var eventTime: Int?
    var eventTimeAsString: String?
    var sender: String?
    var type: String?
    var direction: String?
    var receivedTime: Int?
    var receivedTimeAsString: String?
    var payload: SensorPayload?
    
    struct SensorPayload : Codable {
        var format: String?
        var data: [String: Any]?
        
        private enum CodingKeys: String, CodingKey {
            case format,
            data
        }
        
        init() {
            
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try? container.decode(String.self, forKey: .format)
            data = try? container.decode([String: Any].self, forKey: .data)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try? container.encode(format, forKey: .format)
            try? container.encode(data, forKey: .data)
        }
    }
}

/**
 Struct to represent the event trigger data that will be sent to ICS to set an IoT event
 */
struct DeviceEventTriggerRequest: Encodable {
    var value: Bool
}
