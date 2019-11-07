//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 1:55 PM
// *********************************************************************************************
// File: NotesTableViewController.swift
// *********************************************************************************************
// 

import UIKit

enum NotesError: Error {
    case noNotes,
    integration
}

protocol NotesTableViewControllerDelegate: class {
    /**
     Notifies the delegate of a close request.
    */
    func closeRequested()
    
    /**
     Notifies the delegate of a request to delete a note.
     
     - Parameter index: The index of the note to delete in the Note array.
     - Parameter completion: A callback method called after the delete operation has completed.
     */
    func deleteNote(at index: Int, completion: ((_ result: Result<Bool, NotesError>) -> ())?)
    
    /**
     Notifies the delegate that the table view is requesting the Notes array.
     
     - Returns: An array of Note objects or nil.
    */
    func getNotes() -> [Note]?
    
    /**
     Notifies the delegate that the table view is requesting the Notes array.
     
     - Parameter completion: Callback method called once the notes array is available.
     - Parameter notes: The notes array or nil.
     */
    func getNotes(completion: @escaping ((_ notes: [Note]?) -> ()))
    
    /**
     Notifies the delegate that a note was selected in the table view and the details have been requested.
     
     - Parameter completion: A callback method containing the details of the note once the API call is complete.
     - Parameter details: The ARNodeDetail object or nil.
     */
    func getNodeDetails(completion: @escaping (_ details: ARNodeDetail?) -> ())
    
    /**
     Notifies the delegate that a table row has been selected.
     
     - Parameter index: The index of the row selected.
     */
    func noteSelected(_ index: Int)
    
    /**
     Notifies the delegate that the create note button on the NotesTableViewController has been pressed.
     
     - Returns: An array of Note objects or nil.
     */
    func showCreateNote()
}

class NotesTableViewController: UITableViewController {
    
    //MARK: - IBOutlets
    
    // Reference to the back button in the UI
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIBarButtonItem!
    
    //MARK: - Properties
    
    // Delegate
    weak var delegate: NotesTableViewControllerDelegate?
    
    // Indicator if the notes request is in process
    var gettingNotes: Bool = false
    
    //MARK: - UITableViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if delegate?.getNotes() == nil {
            self.gettingNotes = true
            tableView.reloadData()
            
            delegate?.getNotes(completion: { (result) in
                self.gettingNotes = false
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            })
        }
    }
    
    // MARK: - IBAction Methods
    
    @IBAction private func navigateBack(_ sender: UIBarButtonItem){
        sender.logClick()
        
        self.delegate?.closeRequested()
    }
    
    @IBAction private func createNote(_ sender: UIBarButtonItem){
        sender.logClick()
        
        delegate?.showCreateNote()
        
        guard let path = tableView.indexPathForSelectedRow else { return }
        tableView.deselectRow(at: path, animated: true)
    }

    // MARK: - TableViewDataSource Methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.gettingNotes {
            return 1
        }
        
        guard let notes = self.delegate?.getNotes() else {
            return 1 
        }
        
        return notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
        
        if self.gettingNotes {
            cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath)
        }
        else if let notes = (self.parent?.parent as? NotesSplitViewController)?.notes, notes.count > indexPath.row {
            let noteCell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath)
            let note = notes[indexPath.row]
            
            noteCell.textLabel?.text = note.text
            noteCell.detailTextLabel?.text = note.createdByAccount
            
            if let time = note.createdTime {
                let df = DateFormatter()
                df.timeZone = TimeZone.current
                df.dateFormat = "MMM d yyyy, h:mm a"
                noteCell.detailTextLabel?.text = String(format: "%@" , df.string(from: time))
            }
            
            cell = noteCell
        }
        
        return cell
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            self.delegate?.deleteNote(at: indexPath.row, completion: nil)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    // Override to support row selection
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        AppEventRecorder.shared.record(name: "Note Selected", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: String(describing: type(of: self)), arAnchor: nil, arNode: nil, jsonString: nil, completion: nil)
        
        delegate?.noteSelected(indexPath.row)
    }
    
}
