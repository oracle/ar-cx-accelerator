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

/// Struct to represent the metadata that associates the virtual object with its real-world data.  When an image or object is recognized, this struct defines metdata related to the item that was recognized.
struct ARRecognitionContext: Decodable {
    
    // MARK: - Properties

    /// The name of the recognized item. This will likely be provided by ARKit.
    var name: String?

    /// An integer value that corresponds to the model of the device. This number should be shared for visual (AR) recognition and beacon recognition.
    var major: Int?

    /// An array of integer values that corresponds to the SKUs of the device. This number should be shared for visual (AR) recognition and beacon recognition. Each unique minor value corresponds to an individual device ID in IoTCS.
    var minor: [Int]?

    /// Sensors that should display in the 3D space when this item is recognized that do not have context to a particular 3D model node.
    var sensors: [ARSensor]?

    /// An array of animations to play when the application triggers an "action" with three finger tap.
    var actionAnimations: [ARAnimation]?
    
    /// A vector that can be supplied to alter the default scale of the model for this recognition context.
    var modelScale: ARVector?
    
    /// A vector that can be supplied to alter the default rotation of the model for this recognition context.
    var modelRotation: ARVector?
    
    /// A vector that can be supplied to alter the default position of the model for this recognition context.
    var modelPosition: ARVector?
    
    // MARK: - Enums

    /// Keys that will be decoded from JSON
    enum CodingKeys: String, CodingKey {
        case name,
        major,
        minor,
        sensors,
        actionAnimations,
        modelScale,
        modelRotation,
        modelPosition
    }
    
    // Mark: - Methods
    
    func nodeName() -> String? {
        guard let name = self.name else { return nil }
        guard let subStr = name.split(separator: "_").first else { return name }
        let nodeName = String(subStr)
        
        return nodeName
    }
}

    /// Struct to represent an API call that will return more than one ARRecognitionContext in its response.
struct ARRecognitionContextArrayResponse: Decodable {
    var items: [ARRecognitionContext]?
}
