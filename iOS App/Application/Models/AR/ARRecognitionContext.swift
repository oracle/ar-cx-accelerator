// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 12/11/18 10:13 AM
// *********************************************************************************************
// File: ARRecognitionContext.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct to represent the metadata that associates the virtual object with its real-world data.  When an image or object is recognized, this struct defines metdata related to the item that was recognized.
 */
struct ARRecognitionContext: Decodable {
    
    // MARK: - Properties
    
    /**
     The name of the recognized item. This will likely be provided by ARKit.
    */
    var name: String?
    
    /**
     The SKU/ID of the recognized item.  This should be specific to the device being examined in the ARSpace
     */
    var deviceId: String?
    
    /**
     Sensors that should display in the 3D space when this item is recognized that do not have context to a particular 3D model node.
     */
    var sensors: [ARSensor]?
    
    /**
     An array of animations to play when the application triggers an "action" with three finger tap.
     */
    var actionAnimations: [ARAnimation]?
    
    // MARK: - Enums
    
    /**
     Keys that will be decoded from JSON
    */
    enum CodingKeys: String, CodingKey {
        case name,
        deviceId,
        sensors,
        actionAnimations
    }
    
    // MARK: - Custom Methods
    
    /**
     The name of a node that have "_recognitionNode" appended to the name indicating that it is specifically used as the recognition node.
    */
    func recognitionNodeName() -> String? {
        guard let name = name else { return nil }
        return String(format: "%@_recognitionNode", name)
    }
    
    /**
     The name of the root node that will be used to pull the related 3D model for this recognition context.
     */
    func rootNodeName() -> String? {
        guard let name = self.name else { return nil }
        guard let subStr = name.split(separator: "_").first else { return nil }
        return String(subStr)
    }
}

/**
 Struct to represent an API call that will return more than one ARRecognitionContext in its response.
 */
struct ARRecognitionContextArrayResponse: Decodable {
    var items: [ARRecognitionContext]?
}
