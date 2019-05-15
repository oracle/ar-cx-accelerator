//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: KnowledgebaseViewController.swift
// *********************************************************************************************
// 

import UIKit
import WebKit

class KnowledgebaseViewController: OverlayViewController, WKNavigationDelegate {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var progressIndicator: UIProgressView!
    @IBOutlet weak var backButton: UIBarButtonItem!
    
    // MARK: - Properties
    
    var baseUrlRequest: URLRequest?
    
    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.webView.navigationDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        
        if baseUrlRequest != nil {
            webView.load(baseUrlRequest!)
            
            // Move the progress bar a bit to show that something is happening
            progressIndicator.setProgress(0.2, animated: true)
        } else {
            overlayDelegate?.closeRequested(sender: self.view)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - IBActions
    
    @IBAction func backButtonHandler(_ sender: Any) {
        overlayDelegate?.closeRequested(sender: self.view)
    }
    
    //MARK: - WebKit Methods
    
    func webView(_ view: WKWebView, didCommit: WKNavigation!){
        progressIndicator.setProgress(0.2, animated: true)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressIndicator.setProgress(0.1, animated: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressIndicator.setProgress(1.0, animated: true)
    }
}
