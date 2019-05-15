//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 4/30/19 9:49 AM
// *********************************************************************************************
// File: HelpViewController.swift
// *********************************************************************************************
// 

import UIKit
import WebKit

class HelpViewController: OverlayViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var webView: WKWebView!
    
    // MARK: - UIViewController Methods
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let url = Bundle.main.url(forResource: "help", withExtension: "html") else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    // MARK: - IBActions
    
    @IBAction func backButtonHandler(_ sender: Any) {
        overlayDelegate?.closeRequested(sender: self.view)
    }
    
}
