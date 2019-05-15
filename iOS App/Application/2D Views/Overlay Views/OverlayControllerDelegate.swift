//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: OverlayControllerDelegate.swift
// *********************************************************************************************
// 

import UIKit

protocol OverlayControllerDelegate: class {
    
    /**
     Delegate method for chart views that will remove them from the current view
     
     - Parameter sender: The view that is sending the close request.
     */
    func closeRequested(sender: UIView)
}
