// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/4/18 9:25 AM
// *********************************************************************************************
// File: ARProcedure.swift
// *********************************************************************************************
// 

import UIKit
import ARKit
import os

/**
 Struct to represent declared procedures that can be pulled via API calls and then applied to nodes or sub-nodes in the AR 3D model(s).
 
 This struct will compliment the ARNodeContext struct in that the procedures target a node and it's child node and will apply contextual actions and data to assist in field service procedures.
 */
struct ARProcedure: Decodable {
    
    // MARK: Properties
    
    /**
     The name of the procedure. This is a required field.
     */
    var name: String
    
    /**
     Any description data about the procedure that could be helpful to display as metadata somewhere in the AR UI. This is a required field.
     */
    var description: String
    
    /**
     The steps that this procedure applies.
     */
    var steps: [ProcedureStep]?
    
    /**
     Nodes that can be interacted with using guestures during the procedure.
     */
    var interactionNodes: [String]?
    
    /**
     Flag that can be set during the procedure process to indicate if the user has started to move items from their standard positions and therefor animations should stop.
     */
    var interactionOccurred: Bool = false
    
    /**
     Image to display in the procedures table view.
    */
    var image: ContextImage?
    
    // MARK: - Enums
    
    /**
     Coding keys for JSON deconstruction.
     */
    enum CodingKeys: String, CodingKey {
        case name,
        description,
        steps,
        interactionNodes,
        image
    }
    
    // MARK: - Sub-Structs
    
    struct ProcedureStep: Decodable {
        /**
         The title of the step that will display in the procedures view. This is a required field.
         */
        var title: String
        
        /**
         The text of this step in the procedure. This is a required field.
         */
        var text: String
        
        /**
         A string that can be used to supply information to developers or used elsewhere in the app. It is not currently used in the UI,.
         */
        var details: String?
        
        /**
         The name of a node to select and highlight when this step appears.
         */
        var highlightNode: String?
        
        /**
         An array of of arrays animations to play when this step appears.
         The parent array contains a list of arrays.  Each child array has a set of animations that play simultaenously
         */
        var animations: [[ARAnimation]]?
        
        /**
         An image to display during this procedure step.
         */
        var image: ContextImage?
        
        /**
         Confirmation message to display when the next button is pressed.
         */
        var confirmationMessage: String?
        
        /// An object that defines a timer overlay for a given step.
        var timer: StepTimer?
        
        /**
         A dictionary that can be used to track the original position of nodes at this step so that they may be returned once the step is completed.
         */
        var nodeOriginalPositions: [String: SCNVector3]?
        
        /// A dictionary that can be used to track the original opacity of nodes at this step so that they may be returned to the original value when the step is completed.
        var nodeOriginalOpacity: [String: CGFloat]?
        
        /**
         Coding keys for JSON deconstruction.
         */
        enum CodingKeys: String, CodingKey {
            case title,
            text,
            highlightNode,
            details,
            animations,
            image,
            confirmationMessage,
            timer
        }
        
        public init(from decoder: Decoder) throws {
            do {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                title = try container.decode(String.self, forKey: .title)
                text = try container.decode(String.self, forKey: .text)
                details = try? container.decode(String.self, forKey: .details)
                highlightNode = try? container.decode(String.self, forKey: .highlightNode)
                image = try? container.decode(ContextImage.self, forKey: .image)
                confirmationMessage = try? container.decode(String.self, forKey: .confirmationMessage)
                timer = try? container.decode(StepTimer.self, forKey: .timer)
                
                // At one point, this app only allowed for a single animation at a time.
                // To add multiple simultaneous animations, we now have an array of arrays.
                // This decode logic should convert legacy step definitions into the array of arrays that the application expects now.
                var animations: [[ARAnimation]]? = nil
                
                // Try to decode an array of arrays first.
                do {
                    animations = try container.decode([[ARAnimation]].self, forKey: .animations)
                } catch {
                    do {
                        let animation = try container.decode([ARAnimation].self, forKey: .animations)
                        animations = [animation]
                    } catch {
                        os_log(.error, "Animations for set '%@' could not be decoded as an array or array of arrays!", self.title)
                    }
                }
                
                self.animations = animations
            } catch {
                error.log()
                throw error
            }
        }
        
        // Sub Structs
        
        /// A struct that represents a timer defined in a procedure.
        struct StepTimer: Decodable {
            
            /// The duration of the timer in seconds.
            var duration: Int
            
            /// A message that should display in the UI during the timer.
            var text: String?
        }
    }
}
