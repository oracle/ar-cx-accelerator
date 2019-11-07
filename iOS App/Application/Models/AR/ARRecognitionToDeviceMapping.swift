//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 7/5/19 11:46 AM
// *********************************************************************************************
// File: ARRecognitionToDeviceMapping.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct to represent a mapping object between a locally recognized entity that follows iBeacon data schema and maps it to a remote UUID supplied by IoTCS.
 */
struct ARRecognitionToDeviceMapping: Decodable {
    /**
     The major value in iBeacon schema format.
    */
    var major: Int
    
    /**
     The minor value in iBeacon schema format.
     */
    var minor: Int
    
    /**
     The IoTCS device UUID that maps to the major/minor pair.
     */
    var deviceId: String
    
    /**
     The IoTCS application UUID that maps to the device id.
     */
    var applicationId: String
}

struct ARRecognitionToDeviceMappingArrayResponse: Decodable {
    var items: [ARRecognitionToDeviceMapping]?
}
