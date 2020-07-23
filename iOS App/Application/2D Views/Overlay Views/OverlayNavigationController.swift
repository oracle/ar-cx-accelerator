//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 10/4/19 1:24 PM
// *********************************************************************************************
// File: OverlayNavigationController.swift
// *********************************************************************************************
// 

import UIKit

class OverlayNavigationController: UINavigationController {
    
    //MARK: - Properties
    
    weak var overlayDelegate: OverlayControllerDelegate?
    
    // MARK: - Navigation
    
    /**
     IBAction handler for back buttons on overlay views.
     
     - Parameter sender: The button that sent the request
     */
    @IBAction func backHandler(_ sender: UIBarButtonItem) {
        sender.logClick()
        
        overlayDelegate?.closeRequested(sender: self.view)
    }
    
    // MARK: Init Methods
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.logViewAppeared()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.logViewDisappeared()
    }
}
