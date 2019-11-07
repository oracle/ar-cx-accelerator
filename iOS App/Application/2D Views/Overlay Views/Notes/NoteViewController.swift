//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 1:56 PM
// *********************************************************************************************
// File: NoteViewController.swift
// *********************************************************************************************
// 

import UIKit

class NoteViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var createdByLabel: UILabel!
    @IBOutlet weak var createdTimeLabel: UILabel!
    @IBOutlet weak var updatedByLabel: UILabel!
    @IBOutlet weak var updatedTimeLabel: UILabel!
    @IBOutlet weak var notesTextView: UITextView!
    
    // MARK: - Properties
    
    // The note to display in this view.
    var note: Note?
    
    // Reference to the overlay view controller
    private weak var overlayVc: ActivityOverlayViewController?
    
    // MARK: - UIViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
        self.navigationItem.leftItemsSupplementBackButton = true
        
        guard note == nil else { return }
        guard let overlay = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateInitialViewController() as? ActivityOverlayViewController else { return }
        
        self.addChild(overlay)
        
        overlay.view.frame = self.view.frame
        self.view.addSubview(overlay.view)
        
        self.overlayVc = overlay
        
        if overlay.isViewLoaded {
            overlay.view.backgroundColor = self.traitCollection.userInterfaceStyle == .light ? .white : .black
            overlay.setLabel("Select Note")
            overlay.activityIndicator.stopAnimating()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        self.displayNote()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        
        guard self.note != nil else { return }
        overlayVc?.view.removeFromSuperview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.note = nil
    }
    
    // MARK: - Custom Methods

    /**
     Displays the note assigned to this view controller by removing the overlay and showing the label fields.
    */
    func displayNote() {
        guard let note = self.note else { return }
        guard self.viewIfLoaded != nil else { return }
        
        self.overlayVc?.view.removeFromSuperview()
        
        let df = DateFormatter()
        df.timeZone = TimeZone.current
        df.dateFormat = "MMM d, h:mm a"
        
        self.createdByLabel.text = note.createdByAccount
        self.createdTimeLabel.text = note.createdTime != nil ? df.string(from: note.createdTime!) : ""
        self.updatedByLabel.text = note.updatedByAccount
        self.updatedTimeLabel.text = note.updatedTime != nil ? df.string(from: note.updatedTime!) : ""
        self.notesTextView.text = note.text
        
        self.scrollView.setContentOffset(CGPoint.zero, animated: true)
    }
    
    /**
     Hides the note and shows the overlay to select a note.
    */
    func hideNote() {
        self.note = nil
            
        self.createdByLabel.text = ""
        self.createdTimeLabel.text = ""
        self.updatedByLabel.text = ""
        self.updatedTimeLabel.text = ""
        self.notesTextView.text = ""
        
        guard let overlay = self.overlayVc else { return }
        self.view.addSubview(overlay.view)
    }
}
