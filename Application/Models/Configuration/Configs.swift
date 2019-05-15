//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: Configs.swift
// *********************************************************************************************
// 

import Foundation

/**
 Enum that maps UserDefaults keys to for application settings
 */
enum AppConfigs: String {
    case dataSimulator = "data_simulator",
    noAppSleep = "no_sleep",
    showHelpOnAppStart = "show_help_on_start"
}

/**
 Enum that maps UserDefaults keys to for ICS settings
 */
enum ICSConfigs: String {
    case hostname = "ics_hostname",
    username = "ics_username",
    password = "ics_password"
}

/**
 Enum that maps UserDefaults keys to for sensor config settings
 */
enum SensorConfigs: String {
    case sensorRequestInterval = "sensor_request_interval"
}

/**
 Enum that provides URL formats for deep SR links into service apps
 */
enum ServiceRequestDeepLinkFormat: String {
    case engagementCloud = "https://%@/fscmUI/faces/deeplink?objType=SVC_SERVICE_REQUEST&objKey=srNumber%%3D%@&action=EDIT_IN_TAB"
    case serviceCloud = "https://%@/AgentWeb/Bookmark/Incident/%@"
}

/**
 Struct that defines the server configs object that will be returned from ICSBroker.
 */
struct ServerConfigs: Decodable {
    
    /**
     Variable that stores the service data as mapped by the server configs JSON structure.
     */
    var service: Service?
    
    /**
     Variable that stores the IoT data as mapped by the server configs JSON structure.
     */
    var iot: IoT?
    
    /**
     Struct to define the "service" object defined in server configs.
     */
    struct Service: Decodable {
        /**
         Enum to define the service applications that are supported in the configs and used in the HTTP header for requests to ICSBroker.
         */
        enum Application : String, Codable {
            case engagementCloud = "ec"
            case serviceCloud = "osvc"
        }
        
        /**
         Enum to define the full names of the service applications in the configs
         */
        enum ApplicationName : String {
            case engagementCloud = "Engagement Cloud"
            case serviceCloud = "Service Cloud"
        }
        
        /**
         The current service applicaiton as defined by the server configs
         */
        var application: Application?
        
        /**
         The hostname of the service application as defined by the server configs
         */
        var applicationHostName: String?
        
        /**
         The contact ID that will be used to assign service requests to as defined in the server configs.
         */
        var contactId: Int?
    }
    
    struct IoT: Decodable {
        /**
         We pull the application ID from a server config until this app has the ability to scan a device and determine unique Ids from the device.
         */
        var applicationId: String?
        
        //TODO: Implement a scanning process to identify not only the physical object for AR, but also the serial number for a unique device.
        /**
         We pull the device ID from a server config until this app has the ability to scan a device and determine unique Ids from the device.
         */
        var deviceId: String?
    }
}
