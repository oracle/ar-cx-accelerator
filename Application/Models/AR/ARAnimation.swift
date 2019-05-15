// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/8/18 8:59 AM
// *********************************************************************************************
// File: ARAnimation.swift
// *********************************************************************************************
// 

import Foundation

/**
 Struct to represent an AR animation definition that will be decoded from JSON.
 */
struct ARAnimation: Decodable {
    /**
     The name of the Animation.  This name should map to the Animation enum in the ARViewController. This is a required field.
     */
    var name: String
    
    /**
     The value of the movement to apply.
     */
    var value: Double?
    
    /**
     The duration that the animation should run in seconds.
     */
    var duration: Double?
    
    /**
     The name of the nodes in the 3D model to apply to animation to. This is a required field.
     */
    var nodes: [String]
    
    /**
     An array of SpriteKit attributes for the nodes in the animation.  These are typically arrow and/or motion graphics to depict how to interact with the node in question.
    */
    var attributions: [Attribution]?
    
    /**
     Struct that represents an attribute for a node in an animation.
    */
    struct Attribution: Decodable {
        
        /**
         An identifier for the attribution that can be used to identify its node in the scene's node tree.
         */
        var name: String
        
        /**
         The image to present as the attribution to the 3D node.
         */
        var image: ContextImage?
        
        /**
         Dimentions of the scene for the image.
         */
        var sceneFrame: ARRect?
        
        /**
         Flag to indicate whether to remove the attribution after an animation has played.
         */
        var removeAttributionsAfterAnimation: Bool? = true
        
        /**
         Angles to position which way the node faces.
         */
        var eulerAngles: ARVector?
        
        /**
         The position to place the node in relation to the nodes in the animation.
         */
        var position: ARVector?
        
        /**
         The scale of the dimentions of the spritekit node.
         */
        var scale: ARVector?
    }
}
