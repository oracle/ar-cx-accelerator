//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: PDFViewController.swift
// *********************************************************************************************
// 

import UIKit
import PDFKit

class PDFViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var pdfView: PDFView!
    
    // MARK: - Properties
    
    var pdfDoc: PDFDocument?
    
    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = self.traitCollection.userInterfaceStyle == .light ? .white : .black
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let document = self.pdfDoc else {
            if let navVc = self.parent as? OverlayNavigationController {
                navVc.overlayDelegate?.closeRequested(sender: navVc.view)
            }
            return
        }
        
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.document = document
    }
    
    // MARK: - IBActions
    
    @IBAction func backButton(_ sender: Any) {
        guard let navVc = self.parent as? OverlayNavigationController else { return }
        navVc.overlayDelegate?.closeRequested(sender: navVc.view)
    }
}
