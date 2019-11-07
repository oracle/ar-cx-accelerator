//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/23/19 9:17 AM
// *********************************************************************************************
// File: OciArFunctions.swift
// *********************************************************************************************
// 

import Foundation

/// Defines the parameters required for OCI functions that proxy requests to other systems.
struct OciProxyRequest: Encodable {
    var path: String = "/"
    var method: String = "GET"
    var payload: String?
}

/// Used to search OCI AR Functions where the functions search by a name parameter.
struct OciNameSearch: Encodable {
    var name: String
}

/// Used to search OCI AR Functions where the functions search by these parameters.
struct OciMajorMinorSearch: Encodable {
    var major: Int
    var minor: Int
}

/// Used to search OCI AR functions where device and application id are query parameters.
struct OciIoTAppAndDeviceRequest: Encodable {
    var deviceId: String
    var applicationId: String
}
