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
    var enabled: String?
    var deviceModels: [DeviceModel]?
    
    struct DeviceModel : Decodable {
        var urn: String?
        var name: String?
        var description: String?
        var system: String?
        var draft: String?
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
                    var optional: String?
                    var type: String?
                }
            }
        }
        
        struct DeviceAttribute : Codable {
            var description: String?
            var name: String?
            var range: String?
            var type: String?
            var writable: String?
        }
    }
    
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
struct SensorMessage : Decodable {
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
    
    struct SensorPayload : Decodable {
        var format: String?
        var data: [String: Double]?
    }
}

/**
 Struct to represent the event trigger data that will be sent to ICS to set an IoT event
 */
struct DeviceEventTriggerRequest: Encodable {
    var value: Bool
}
