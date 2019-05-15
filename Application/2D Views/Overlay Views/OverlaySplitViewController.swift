//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 2:01 PM
// *********************************************************************************************
// File: OverlaySplitViewController.swift
// *********************************************************************************************
// 

import UIKit

class OverlaySplitViewController: UISplitViewController {
    
    //MARK: - Properties
    
    weak var overlayDelegate: OverlayControllerDelegate?
    
    // MARK: - Navigation
    
    /**
     IBAction handler for back buttons on overlay views.
     
     - Parameter sender: The button that sent the request
     */
    @IBAction func backHandler(_ sender: UIBarButtonItem) {
        overlayDelegate?.closeRequested(sender: self.view)
    }
    
    // MARK: Init Methods
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
    }
}
