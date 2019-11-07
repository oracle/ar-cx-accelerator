//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 2:01 PM
// *********************************************************************************************
// File: OverlayPageViewController.swift
// *********************************************************************************************
// 

import UIKit
#warning("Uncomment when LX supports Swift 5.1 and removes x386 support in dependent frameworks that brake IPA distribution in Xcode 11.")
//import OracleLive

class OverlayPageViewController: UIPageViewController {
    
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

        #warning("Uncomment when LX supports Swift 5.1 and removes x386 support in dependent frameworks that brake IPA distribution in Xcode 11.")
        //Controller.shared.addComponent(viewController: self)
        //Controller.shared.settings.startVideoWithFrontCamera = true
        
        self.logViewAppeared()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.logViewDisappeared()
    }
}
