// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 12/4/18 2:40 PM
// *********************************************************************************************
// File: ARSensor.swift
// *********************************************************************************************
// 

import Foundation
import ARKit

/**
 A struct that defines the display of a sensor that is related to a selected node in the AR space.
 */
struct ARSensor: Decodable {
    /**
     The name of the sensor that will be displayed.  This is also used as the "key" in IoTCS message data calls to determine if IoTCS returned data.
    */
    var name: String?
    
    /**
     Dimentions of the scene for the sensor.
     */
    var sceneFrame: ARRect?
    
    /**
     The definition of the background for the sensor.
    */
    var background: Background?
    
    /**
     Coordinates for positioning the gauage in 3d space.
    */
    var position: ARVector?
    
    /**
     Controls if the sensor will always face the view port.
     */
    var alwaysFaceViewPort: Bool?
    
    /**
     Default text to apply to the sensor label. This will be overriden if the sensor updates via the sensor timer.
     */
    var label: Label?
    
    /**
     Dimentions for the sensor plane in the AR experience.
     */
    var sensorPlane: ARRect?
    
    /**
     Change the scale of the node that will contain the plane showing the sensor sprite.
     */
    var scale: ARVector?
    
    /**
     Euler angles (degrees) for positioning plane.
     */
    var eulerAngles: ARVector?
    
    /**
     Defines the min and max boundaries for alerts in the UI.
     */
    var operatingLimits: OperatingLimits?
    
    /**
     Defines how tapping on the sensor in the UI will behave.
     */
    var action: SensorAction?
    
    /**
     Helper to decode background data from JSON.
     */
    struct Background: Decodable {
        var type: BackgroundType?
        var image: ContextImage?
        var video: String?
        
        enum BackgroundType: String, CaseIterable {
            case image,
            video
        }
        
        enum CodingKeys: String, CodingKey {
            case type,
            image,
            video
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // set type
            let backgroundTypeStr = try? container.decode(String.self, forKey: CodingKeys.type)
            for type in BackgroundType.allCases {
                if type.rawValue == backgroundTypeStr {
                    self.type = type
                    break
                }
            }
            
            // set image
            image = try? container.decode(ContextImage.self, forKey: CodingKeys.image)
            
            // set video
            video = try? container.decode(String.self, forKey: CodingKeys.video)
        }
    }
    
    /**
     Helper to decode label data from JSON.
     */
    struct Label: Decodable {
        var text: String?
        var font: Font?
        var position: ARPoint?
        var rotation: Double?
        var formatter: String?
        
        struct Font: Decodable {
            var name: String?
            var size: CGFloat?
            var color: Color?
            
            struct Color: Decodable {
                var red: CGFloat
                var green: CGFloat
                var blue: CGFloat
                var alpha: CGFloat
                
                func getUIColor() -> UIColor {
                    return UIColor(displayP3Red: red, green: green, blue: blue, alpha: alpha)
                }
            }
        }
    }
    
    /**
     Struct to define the min/max operating limits for a sensor.
     */
    struct OperatingLimits: Decodable {
        var min: Double?
        var max: Double?
    }
    
    /**
     Defines how tapping on the sensor in the UI will behave.
    */
    struct SensorAction: Decodable {
        var type: ActionType?

        var url: String?
        
        enum ActionType: String, CaseIterable {
            case lineChart,
            url,
            volume
        }
        
        enum CodingKeys: String, CodingKey {
            case type,
            url,
            volume
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let actionTypeStr = try? container.decode(String.self, forKey: CodingKeys.type)
            
            for type in ActionType.allCases {
                if type.rawValue == actionTypeStr {
                    self.type = type
                    break
                }
            }
            
            url = try? container.decode(String.self, forKey: CodingKeys.url)
        }
    }
}
