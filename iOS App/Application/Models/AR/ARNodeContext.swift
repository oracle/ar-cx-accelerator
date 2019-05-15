//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ARNodeContext.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct to represent the metadata that associates the virtual object with its real-world data.  Each node in a 3D model should have corresponding metadata to indicate its name, reference identifiers (SKU, etc. that can be related to database-drive content), AR procedures, and animations that affect it and any sub-nodes under it.
 
 IoTCS does not provide data at the granularity that an AR experience might require.  This object allows for storing that supplementary data in an external data source that call be called via REST APIs and provide the contextual information that an AR experience will need.
 */
struct ARNodeContext: Decodable {
    
    // MARK: Properties
    
    /**
     The ID of this AR node context record (if retrieved from a DB or ID-based platform).
     */
    var id: Int?
    
    /**
     The name of the node.  This should be a case-sensitive mapping to the name of the node in the 3D model used in the AR experience.  This is a required field and should be unique per-model.
    */
    var name: String
    
    /**
     Any description data about the node that could be helpful to display as metadata somewhere in the AR UI.
     */
    var description: String?
    
    /**
     An image of the node that can be used in contextual displays.
     */
    var image: ContextImage?
    
    /**
     An array of images that will display in a collection view in the context pane (a scrolling image collection).
     */
    var images: [ContextImage]?
    
    /**
     An array of specification objects that allows for ordering the specification as opposed to a standard dictionary key/value pair, which would not allow ordering without key sorting and that would break the order of items from the API call.
    */
    var tableSections: [TableSection]?
    
    /**
     An array of the immediate subnodes embedded under this node.
     */
    var subNodes: [ARNodeContext]?
    
    /**
     An array of procedurs that apply to this node and its subnodes.
     */
    var procedures: [ARProcedure]?
    
    /**
     An array of IoT sensors to display when the node is selected.
     */
    var sensors: [ARSensor]?
    
    // MARK: - Structs
    
    /**
     A Struct that represents a context table row.
     */
    struct TableSection: Decodable {
        var name: String?
        
        var rows: [TableRow]?
    }
    
    /**
     A Struct that represents a context table row.
     */
    struct TableRow: Decodable {
        /**
         The name of the specification that will appear in the title.
        */
        var title: String?
        
        /**
         The value of the specification that will appear in the subtext.
         */
        var subtitle: String?
        
        /**
         An image to display next to the specification.
         */
        var image: ContextImage?
        
        /**
         The action that will occur when the row is tapped.
         */
        var action: Action?
        
        /**
         A Struct that represents an action to perform when a row is tapped.
         */
        struct Action: Decodable {
            var type: ActionType?
            
            var url: String?
            
            var applicationFunction: ApplicationFunction?
            
            enum ActionType: String, CaseIterable {
                case url,
                applicationFunction
            }
            
            enum ApplicationFunction: String, CaseIterable {
                case createSr,
                textChat,
                videoChat
            }
            
            enum CodingKeys: String, CodingKey {
                case type,
                url,
                applicationFunction
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
                
                let appFunctionStr = try? container.decode(String.self, forKey: CodingKeys.applicationFunction)
                
                for function in ApplicationFunction.allCases {
                    if function.rawValue == appFunctionStr {
                        self.applicationFunction = function
                        break
                    }
                }
                
                url = try? container.decode(String.self, forKey: CodingKeys.url)
            }
        }
    }
}

/**
 Struct to represent an API call that will return more than one ARNodeContext in its response.
 */
struct ARNodeContextArrayResponse: Decodable {
    var items: [ARNodeContext]?
}
