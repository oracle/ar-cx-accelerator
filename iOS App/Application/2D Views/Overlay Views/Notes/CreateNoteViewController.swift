//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 1:56 PM
// *********************************************************************************************
// File: CreateNoteViewController.swift
// *********************************************************************************************
// 

import UIKit
import os

protocol CreateNoteViewControllerDelegate: class {
    /**
     Notifies the delegate that a note was created.
     
     - Parameter sender: The sending controller.
    */
    func noteCreated(_ sender: CreateNoteViewController?)
    
    /**
     Requests the note details object for the selected node from the delegate.
     
     - Parameter completion: The callback method called when the node detail object is found.
     - Parameter object: The ar node details object found.
    */
    func getNodeDetails(completion: @escaping (_ object: ARNodeDetail?) -> ())
}

class CreateNoteViewController: OverlayViewController, UITextViewDelegate {
    
    //MARK: - Properties
    
    // Reference to this class's delegate.
    weak var delegate: CreateNoteViewControllerDelegate?
    
    // Reference to the create button
    private weak var createButton: UIBarButtonItem?
    
    // Reference to the create button
    @IBOutlet weak var noteTextView: UITextView!
    
    // The node name to apply the note to
    var nodeName: String?
    
    // The record ID of the device/node pair (ModelNode).
    private var modelNodeId: Int?
    
    //MARK: - IBActions
    
    @IBAction func createHandler(_ sender: UIBarButtonItem) {
        sender.logClick()
        
        guard let activityOverlayVc = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateInitialViewController() as? ActivityOverlayViewController else { return }
        
        sender.isEnabled = false
        self.noteTextView.isEditable = false
        
        let resetView: () -> () = {
            DispatchQueue.main.async {
                activityOverlayVc.view.removeFromSuperview()
                activityOverlayVc.removeFromParent()
                sender.isEnabled = true
                self.noteTextView.isEditable = true
            }
        }
        
        let errorHandler: () -> () = {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Error", message: "There was an error creating the note.", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: { (action) in
                    resetView()
                })
                alert.addAction(action)
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        activityOverlayVc.view.frame = self.view.frame
        activityOverlayVc.setLabel("Creating Note")
        
        self.addChild(activityOverlayVc)
        self.view.addSubview(activityOverlayVc.view)
        
        self.createNote { (result) in
            guard result else {
                errorHandler()
                return
            }
            
            resetView()
            
            DispatchQueue.main.async {
                self.delegate?.noteCreated(self)
            }
        }
    }
    
    //MARK: - UIViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let createButton = UIBarButtonItem(title: "Create", style: .plain, target: self, action: #selector(self.createHandler(_:)))
        createButton.isEnabled = false
        self.navigationItem.rightBarButtonItem = createButton
        self.createButton = createButton
        
        self.delegate?.getNodeDetails { (details) in
            
            DispatchQueue.main.async {
                guard let id = details?.id else {
                    let alert = UIAlertController(title: "Error", message: "Error getting node data from server. Cannot create a note for the selected model node.", preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(action)
                    self.present(alert, animated: true, completion: nil)
                    
                    return
                }
            
                createButton.isEnabled = true
                self.modelNodeId = id
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.noteTextView.becomeFirstResponder()
    }
    
    //MARK: - UITextViewDelegate Methods
    
    func textViewDidChange(_ textView: UITextView) {
        guard !self.noteTextView.text.isEmpty, self.modelNodeId != nil else {
            self.createButton?.isEnabled = false
            return
        }
        
        self.createButton?.isEnabled = true
    }
    
    //MARK: - Custom Methods

    /**
     Creates a note for the device/node pair based on the text in the noteTextView.
     
     - Parameter completion: Completion method called after this method has finished.
     - Parameter result: Flag indicating if the request was a success or failure.
    */
    private func createNote(completion: @escaping (_ result: Bool) -> ()) {
        guard let modelNodeId = self.modelNodeId else { completion(false); return }
        guard let text = self.noteTextView.text, !text.isEmpty else { completion(false); return }
        
        do {
            try (UIApplication.shared.delegate as! AppDelegate).integrationBroker.createNote(modelNodeId: modelNodeId, text: text) { result in
                switch result {
                case .success(let data):
                    completion(data)
                    break
                default:
                    completion(false)
                    break
                }
            }
        } catch {
            error.log()
            completion(false)
        }
    }
}
