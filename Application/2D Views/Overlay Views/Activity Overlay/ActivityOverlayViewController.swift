//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ActivityOverlayViewController.swift
// *********************************************************************************************
// 

import UIKit

class ActivityOverlayViewController: UIViewController {

    // MARK: - Properties
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityLabel: UILabel!
    
    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Custom Methods
    
    /**
     Sets the activity label with new text.
     
     - Parameter text: The string to update the label to.
    */
    func setLabel(_ text: String) {
        self.activityLabel.text = text
    }
}
