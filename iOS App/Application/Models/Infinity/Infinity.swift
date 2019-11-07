//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 2/11/19 8:47 AM
// *********************************************************************************************
// File: Infinity.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct that represents a request to send to CX Infinity.
 */
struct InfinityRequest: Codable {
    var staticProps: InfinityStatic?
    
    var events: [InfinityEvent]?
    
    enum CodingKeys: String, CodingKey {
        case staticProps = "static",
        events
    }
}

struct InfinityStatic: Codable {
    var appName: String?
    var wtCt: String?
    var wtDm: String?
    var language: String?
    var wtDid: String?
    var mobileCarrier: String?
    var wtGco: String?
    var conversion: String?
    var wtCof: String?
    
    enum CodingKeys: String, CodingKey {
        case appName = "wt.a_nm",
        wtCt = "wt.ct",
        wtDm = "wt.dm",
        language = "wt.ul",
        wtDid = "wt.d_id",
        mobileCarrier = "wt.a_dc",
        wtGco = "wt.g_co",
        conversion = "wt.co",
        wtCof = "wt.co_f"
    }
    
    init(){
        self.appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
}

struct InfinityEvent: Codable {
    var appName: String?
    var appVersion: String?
    var demoId: String?
    var eventName: String?
    var eventStart: String?
    var eventEnd: String?
    var eventLength: Int?
    var uiElement: String?
    var arAnchor: String?
    var arNode: String?
    var arScreenshot: String?
    var arData: String?
    var arDemoPerson: String?
    var arDemoPersonEmail: String?
    var arDemoName: String?
    var arDemoOrg: String?
    
    enum CodingKeys: String, CodingKey {
        case appName = "wt.a_nm",
        appVersion = "wt.av",
        demoId = "ora.demo_id",
        eventName = "ar.event_name",
        eventStart = "ar.event_start",
        eventEnd = "ar.event_end",
        eventLength = "ar.event_length",
        uiElement = "ar.ui_element",
        arNode = "ar.node",
        arAnchor = "ar.anchor",
        arScreenshot = "ar.screenshot",
        arData = "ar.data",
        arDemoPerson = "ar.demo_person_name",
        arDemoPersonEmail = "ar.demo_person_email",
        arDemoName = "ar.demo_name",
        arDemoOrg = "ar.demo_org"
    }
    
    init(){
        self.appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}
