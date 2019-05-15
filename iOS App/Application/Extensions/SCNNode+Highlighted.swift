// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/2/18 1:25 PM
// *********************************************************************************************
// File: SCNNode+Highlighted.swift
// *********************************************************************************************
// 

import SceneKit

extension SCNNode {
    
    /**
     Indicates a highlighted state for the node for shaders around the selected node.
     
     - Parameter highlighted: Bool to set the highlighted mask on a the current node.
     */
    func setHighlighted(_ highlighted : Bool = true) {
        self.categoryBitMask = highlighted ? 2 : 1
        
        // Ensure children are not highlighted when this node is unhighlighted
        if !highlighted {
            for child in self.childNodes {
                child.setHighlighted(highlighted)
            }
        }
    }
}
