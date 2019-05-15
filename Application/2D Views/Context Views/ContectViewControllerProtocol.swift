// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/11/18 8:37 AM
// *********************************************************************************************
// File: ContectViewControllerProtocol.swift
// *********************************************************************************************
// 

import Foundation

protocol ContextViewController {
    /**
     Moves the frame to the bottom of the screen to the pixel just below the last displayed pixel row.
     */
    func moveFrameOutOfView()
    
    /**
     Resizes the display area based on the width of the screen.
     
     - Parameter duration: The duration of the movement animation in seconds.
     - Parameter completion: A callback method called after animation is completed.
     */
    func resizeForContent(_ duration: Double, completion: (() -> ())?)
    
    /**
     Animates the view off screen and then removes from view.
     
     - Parameter completion: A callback method called after the action is completed.
     */
    func removeView(completion: (() -> ())?)
}
