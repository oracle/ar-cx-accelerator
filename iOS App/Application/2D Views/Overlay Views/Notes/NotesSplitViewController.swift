//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/6/19 1:54 PM
// *********************************************************************************************
// File: NotesSplitViewController.swift
// *********************************************************************************************
// 

import UIKit
import os

class NotesSplitViewController: OverlaySplitViewController, UISplitViewControllerDelegate, CreateNoteViewControllerDelegate, NotesTableViewControllerDelegate {
    
    //MARK: - Properties
    
    /**
     The ID of the device that is currently in view of the AR experience.
     */
    var deviceId: String?
    
    /**
     The name of the node that notes apply to.
     */
    var nodeName: String?
    
    /**
     The array of notes that will display in the table view.
     */
    var notes: [Note]?
    
    /**
     Reference to the master view nav controller
     */
    private weak var masterViewNavController: UINavigationController?
    
    /**
     Reference to the note nav view controller
     */
    private weak var detailsNavViewController: UINavigationController?
    
    //MARK: - UISplitViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.delegate = self
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.preferredDisplayMode = .allVisible
        }
        
        self.masterViewNavController = self.children.first(where: { $0.restorationIdentifier == "NotesMasterNavigationViewController" }) as? UINavigationController
        self.detailsNavViewController = self.children.first(where: { $0.restorationIdentifier == "NotesDetailsNavigationViewController" }) as? UINavigationController
        
        (self.masterViewNavController?.topViewController as? NotesTableViewController)?.delegate = self
    }
    
    // MARK: - UISplitViewControllerDelegate Methods
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    // MARK: - NotesTableViewControllerDelegate Methods
    
    func getNotes() -> [Note]? {
        return self.notes
    }
    
    func getNotes(completion: @escaping (([Note]?) -> ())) {
        self.getNotesFromServer { (results) in
            completion(self.notes)
        }
    }
    
    func getNodeDetails(completion: @escaping (ARNodeDetail?) -> ()) {
        self.getNodeDetailsFromServer { (details) in
            completion(details)
        }
    }
    
    func noteSelected(_ index: Int) {
        self.noteSelected(at: index)
    }
    
    func deleteNote(at index: Int, completion: ((Result<Bool, NotesError>) -> ())?) {
        guard self.notes != nil, (0..<self.notes!.count).contains(index) else { completion?(.failure(.noNotes)); return }
        guard let noteId = self.notes![index].id else { completion?(.failure(.noNotes)); return }
        
        self.notes!.remove(at: index)
        
        DispatchQueue.global(qos: .background).async {
            self.getNodeDetailsFromServer { (details) in
                guard let nodeId = details?.id else { completion?(.failure(.integration)); return }
                
                self.deleteNoteFromServer(nodeId: nodeId, noteId: noteId, completion: { (result) in
                    completion?(.success(true))
                })
            }
        }
    }
    
    /**
     Delegate method to indicate that the close button was selected from the sending controller.
    */
    func closeRequested() {
        self.overlayDelegate?.closeRequested(sender: self.view)
    }
    
    /**
     Delegate method to indicate that the create note button was selected from the sending controller.
     */
    func showCreateNote() {
        guard let navController = self.detailsNavViewController else { return }
        
        if let nvc = navController.children.first(where : { $0 is NoteViewController }) as? NoteViewController {
            nvc.hideNote()
        }
        
        self.showDetailViewController(navController, sender: self)
        navController.performSegue(withIdentifier: "CreateNoteSegue", sender: self)
    }
    
    // MARK: - Event Handler Methods
    
    /**
     Updates the details view with the note that was selected from the table view.
     
     - Parameter index: The index of the note that was selected.
    */
    private func noteSelected(at index: Int) {
        guard let notes = notes else { return }
        guard let navController = self.detailsNavViewController else { return }
        guard let detailsVc = navController.children.first as? NoteViewController else { return }
        
        if navController.visibleViewController is CreateNoteViewController {
            navController.popToRootViewController(animated: true)
        }
        
        guard (0..<notes.count).contains(index) else {
            detailsVc.hideNote()
            return
        }
        
        let note = notes[index]
        detailsVc.note = note
        detailsVc.displayNote()
        
        self.showDetailViewController(navController, sender: self)
    }
    
    // MARK: - Integration Methods
    
    /**
     Gets the list of remote notes and refreshes the note array with the data set
     
     - Parameter completion: Callback called once the API call is finished.
     - Parameter result: Bool to indicate success or failure of the call.
     */
    private func getNotesFromServer(completion: @escaping (_ result: Bool) -> ()) {
        DispatchQueue.main.async {
            guard let nodeName = self.nodeName else { completion(false); return }
            guard let deviceId = self.deviceId else { completion(false); return }
            
            do {
                try (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getNotes(deviceId: deviceId, nodeName: nodeName, completion: { result in
                    switch result {
                    case .success(let data):
                        guard let notes = data.items else { completion(false); return }
                        
                        // Reverse sort chronologically
                        let sorted = notes.sorted(by: { (note1, note2) -> Bool in
                            guard let t1 = note1.createdTime, let t2 = note2.createdTime else {
                                return false
                            }
                            
                            return t1 > t2
                        })
                        
                        self.notes = sorted
                        
                        completion(true);
                        
                        break
                    case .failure(let failure):
                        failure.log()
                        completion(false);
                        break
                    }
                    
                })
            } catch {
                completion(false);
            }
        }
    }
    
    /**
     Calls ICS to delete the defined node.
     
     - Parameter nodeId: The ID of the model node record.
     - Parameter nodeIt: The ID of the note record.
     - Parameter completion: A an optional callback that is called after the API call is completed.
     - Parameter result: The result of the method.
     */
    private func deleteNoteFromServer(nodeId: Int, noteId: Int, completion: ((_ result: Bool) -> ())?) {
        DispatchQueue.main.async {
            do {
                try (UIApplication.shared.delegate as! AppDelegate).integrationBroker.deleteNote(modelNodeId: nodeId, noteId: noteId, completion: { result in
                    switch result {
                    case .success(_):
                        completion?(true)
                        break
                    default:
                        completion?(false)
                        break
                    }
                })
            } catch {
                error.log()
                completion?(false)
            }
        }
    }
    
    /**
     Gets the node details from the server based on the device id and the node.
     
     - Parameter completion: Completion method called after this method has finished.
     - Parameter object: The ARNodeDetail object returned.
     */
    private func getNodeDetailsFromServer(completion: @escaping (_ object: ARNodeDetail?) -> ()) {
        guard let deviceId = self.deviceId else { completion(nil); return }
        guard let nodeName = self.nodeName else { completion(nil); return }
        
        DispatchQueue.main.async {
            do {
                try (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getModelNodeDetails(deviceId: deviceId, nodeName: nodeName) { result in
                    switch result {
                    case .success(let data):
                        completion(data.items?.first)
                        break
                    case .failure(let failure):
                        failure.log()
                        os_log(.error, "Unable to get details about node for not capture.")
                        completion(nil)
                        break
                    }
                }
            } catch {
                error.log()
                os_log(.error, "Unable to get details about node for not capture.")
                completion(nil)
            }
        }
    }
    
    // MARK: - NoteDelegate Methods
    
    /**
     Method called when a note is added so that we can re-query the server for the server-side data for the new set of notes.
     
     - Parameter sender: The object sending the notification.
     */
    func noteCreated(_ sender: CreateNoteViewController?) {
        // Pop the create view
        if let createVc = sender, let navController = self.detailsNavViewController, navController.topViewController == createVc {
            self.detailsNavViewController?.popViewController(animated: true)
            self.detailsNavViewController?.navigationController?.popViewController(animated: true)
        }
        
        // Set current array to nil
        self.notes = nil
        
        guard let tableVc = self.masterViewNavController?.children.first(where: { $0 is NotesTableViewController }) as? NotesTableViewController else { return }
        
        tableVc.gettingNotes = true
        tableVc.tableView.reloadData()
        
        DispatchQueue.global(qos: .background).async {
            self.getNotesFromServer { (results) in
                tableVc.gettingNotes = false
                
                DispatchQueue.main.async {
                    tableVc.tableView.reloadData()
                }
            }
        }
    }
}
