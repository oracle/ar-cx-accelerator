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
 Enum that maps UserDefaults keys to for ICS settings
 */
enum ICSConfigs: String {
    case hostname = "ics_hostname",
    username = "ics_username",
    password = "ics_password"
}

/**
 Enum that defines the integration configuration options for OCI F(n) services.
*/
enum OciFnConfigs: String {
    case arFnApplicationDetailsEndpoint = "oci_fn_app_endpoint",
    tenancyId = "oci_tenancy_id",
    authUserId = "oci_auth_user_id",
    publicKeyFingerprint = "oci_pub_key_fingerprint",
    privateKey = "oci_private_key"
}

/**
 Enum that maps UserDefaults keys to for CX Inifinity settings
 */
enum InfinityConfigs: String {
    case hostname = "infinity_hostname",
    backendid = "infinity_backendid"
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

/// Defines applicable links in the Oracle App Store
enum OracleAppStore: String {
    case appPage = "https://bit.ly/augmented-cx",
    appPageDirect = "https://mobileappstore.oracleads.com:7777/store#/index/5bc4dc66103c56624a3e0124"
}

/**
 Struct that defines the server configs object that will be returned from IntegrationBroker.
 */
struct ServerConfigs: Decodable {
    
    /**
     Variable that stores the service data as mapped by the server configs JSON structure.
     */
    var service: Service?
    
    /**
     Struct to define the "service" object defined in server configs.
     */
    struct Service: Decodable {
        /**
         Enum to define the service applications that are supported in the configs and used in the HTTP header for requests to IntegrationBroker.
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
}
