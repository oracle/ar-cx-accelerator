//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: SCNNode+NonSensorNodes.swift
// *********************************************************************************************
// 

import SceneKit

extension SCNNode {
    /**
     Array of all nodes that are not sensors.
     */
    var nonSensorChildNodes: [SCNNode]? {
        return self.childNodes.filter { $0.name != nil && !$0.name!.contains("_Sensor") }
    }
    
    /**
     Sets the opacity of this node and all child nodes to the given opacity value.
     
     - Parameter opacity: The opacity to set the node to.
    */
    func setChildNodeOpacity(opacity: CGFloat) {
        self.setChildNodeOpacity(node: self, opacity: opacity)
    }
    
    /**
     Sets the opacity of this node and all child nodes to the given opacity value.
     
     - Parameter node: The node to apply the change to. All children will be upated too.
     - Parameter opacity: The opacity to set the node to.
     */
    func setChildNodeOpacity(node: SCNNode, opacity: CGFloat) {
        node.opacity = opacity
        for childNode in node.childNodes {
            setChildNodeOpacity(node: childNode, opacity: opacity)
        }
    }
}
