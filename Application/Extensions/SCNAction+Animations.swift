// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 11/7/18 9:14 AM
// *********************************************************************************************
// File: SCNAction+Animations.swift
// *********************************************************************************************
// 

import SceneKit
import os

extension SCNAction {
    
    // MARK - Enums
    
    /**
     Enum of errors that migth be thrown by this class.
     */
    enum ActionError: Error {
        case emptyActionArray
        case cannotMapAction(nodeCountExpected: Int, nodeCountCalculted: Int)
    }
    
    // MARK: - Methods
    
    /**
     Animation that changes colors / materials to allow the user to identify it on screen.
     
     - Paramter duration: The length of time that the animation will play in seconds.
    */
    static func identify(duration: Double) -> SCNAction {
        let 🦄 = SCNAction.customAction(duration: 0) { (node, elapsedtime) in
            guard let defaultMaterial = node.geometry?.material(named: "DefaultMaterial"), let highlightMaterial = node.geometry?.material(named: "HighlightMaterial") else { return }
            
            node.geometry?.firstMaterial = highlightMaterial
            node.geometry?.insertMaterial(defaultMaterial, at: 1)
        }
        
        let original = SCNAction.customAction(duration: 0) { (node, elapsedtime) in
            guard let defaultMaterial = node.geometry?.material(named: "DefaultMaterial"), let highlightMaterial = node.geometry?.material(named: "HighlightMaterial") else { return }
            
            node.geometry?.firstMaterial = defaultMaterial
            node.geometry?.insertMaterial(highlightMaterial, at: 1)
        }
        
        // 4 movements...each movement gets 25% of the action
        let moveDuration = duration / 4.0
        
        let bounce: SCNAction = .sequence([
            🦄,
            .move(by: SCNVector3(0, 0.05, 0), duration: moveDuration),
            .move(by: SCNVector3(0, -0.025, 0), duration: moveDuration),
            .move(by: SCNVector3(0, 0.025, 0), duration: moveDuration),
            .move(by: SCNVector3(0, -0.05, 0), duration: moveDuration),
            original
            ])
        
        return bounce
    }
    
    /**
     Changes the materials opacity over time.  Does not change the object opacity.
     
     - Parameter duration: The length of time that the animation will play.
     - Parameter opacity: The opacity to change the materials to.
    */
    static func materialsOpacity(duration: Double, opacity: CGFloat) -> SCNAction {
        return SCNAction.customAction(duration: duration, action: { (node, elapsedTime) in
            node.geometry?.firstMaterial?.transparency = opacity
        })
    }
    
    /**
     Pulses the alpha transparency.
     
     - Parameter duration: The length that the animation should play.
     */
    static func pulsingAlpha(duration: Double) -> SCNAction {
        // 4 changes...each movement gets 25% of the action
        let shiftDuration = duration / 4.0
        
        return .sequence([
            .fadeOpacity(to: 0.15, duration: shiftDuration),
            .fadeOpacity(to: 0.85, duration: shiftDuration),
            .fadeOpacity(to: 0.15, duration: shiftDuration),
            .fadeIn(duration: shiftDuration)
            ])
    }
    
    /**
     Pulses between the default material and the highlight material of the selected node.
     
     - Paramter duration: The length of time that the animation should play.
     */
    static func pulsingHighlight(duration: Double) -> SCNAction {
        let pulseMaterialName = "PulseMaterial"
        let newMaterial = SCNMaterial()
        newMaterial.name = pulseMaterialName
        newMaterial.diffuse.contents = UIColor.black
        
        let changeColor: (SCNNode, UIColor) -> () = { (node, color) in
            guard let pulseMaterial = node.geometry?.materials.first(where: { $0.name == pulseMaterialName }) else {
                if node.geometry == nil {
                    node.geometry = SCNGeometry()
                }
                
                newMaterial.diffuse.contents = color
                node.geometry!.materials.insert(newMaterial, at: 0)
                
                #if DEBUG
                os_log("Added new material to node: %@", node.name!)
                #endif
                
                return
            }
            
            pulseMaterial.diffuse.contents = color
        }
        
        // three colors...each color gets 1/3 of the total duration
        let colorDuration = duration / 3.0
        
        let toRed = SCNAction.customAction(duration: colorDuration) { (node, elapsedTime) in
            let percentage = elapsedTime / CGFloat(colorDuration)
            let color = UIColor(red: percentage, green: 0, blue: 0, alpha: 1)
            changeColor(node, color)
        }
        
        let toGreen = SCNAction.customAction(duration: colorDuration) { (node, elapsedTime) in
            let percentage = elapsedTime / CGFloat(colorDuration)
            let color = UIColor(red: 0, green: percentage, blue: 0, alpha: 1)
            changeColor(node, color)
        }
        
        let toBlue = SCNAction.customAction(duration: colorDuration) { (node, elapsedTime) in
            let percentage = elapsedTime / CGFloat(colorDuration)
            let color = UIColor(red: 0, green: 0, blue: percentage, alpha: 1)
            changeColor(node, color)
        }
        
        let removePulse = SCNAction.customAction(duration: 0) { (node, elapsedTime) in
            guard let pulseMaterial = node.geometry?.materials.first(where: { $0.name == pulseMaterialName }) else { return }
            
            guard let index = node.geometry?.materials.firstIndex(of: pulseMaterial), index > -1 else { return }
            
            #if DEBUG
            os_log("Removing material at index: %d", index)
            #endif
            
            node.geometry?.removeMaterial(at: index)
        }
        
        return .sequence([
            toRed,
            toGreen,
            toBlue,
            toRed,
            toGreen,
            toBlue,
            removePulse
            ])
    }
}
