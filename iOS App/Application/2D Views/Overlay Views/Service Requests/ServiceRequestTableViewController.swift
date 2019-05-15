//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ServiceRequestTableViewController.swift
// *********************************************************************************************
// 

import UIKit

protocol ServiceRequestTableViewControllerDelegate: class {
    /**
     Delegate method to indicate that a create service request button was tapped from the ServiceRequestTableViewController
     */
    func createServiceRequestRequested()
    
    /**
     Delegate method to indicate that a close button was tapped from the ServiceRequestTableViewController
     */
    func closeRequested()
    
    /**
     Delegate method that will delete the record from the service application that was deleted from the table view.
     
     - Parameter index: The index of the record that was deleted from the service request array.
     - Parameter completion: A method called after the API call completes.
     */
    func deleteSr(at index: Int, completion: (() -> ())?)
    
    /**
     Delegate method that is fired when a service request is selected.
     
     - Parameter index: The index of the record that was selected from the service request array.
     */
    func serviceRequestSelected(at index: Int)
}

class ServiceRequestTableViewController: UITableViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    // MARK: - Properties
    
    /**
     Reference to the delegate for this class.
    */
    weak var delegate: ServiceRequestTableViewControllerDelegate?
    
    /**
     Flag to indicate if a query for Srs was performed by the current instance of this class.
     */
    var didQueryForSrs: Bool = false
    
    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - IBAction Methods
    
    @IBAction private func navigateBack(_ sender: UIBarButtonItem){
        self.delegate?.closeRequested()
    }
    
    @IBAction private func addButtonHandler(_ sender: UIBarButtonItem){
        if let path = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: path, animated: true)
        }
        
        self.delegate?.createServiceRequestRequested()
    }

    // MARK: - TableViewDataSource Methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let parent = self.parent?.parent as? ServiceRequestSplitViewController, let serviceRequests = parent.serviceRequests?.items else { return 1 }
        
        return serviceRequests.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
        
        if let parent = self.parent?.parent as? ServiceRequestSplitViewController, let serviceRequests = parent.serviceRequests?.items, serviceRequests.count > indexPath.row {
            let srCell = tableView.dequeueReusableCell(withIdentifier: "ServiceRequestCell", for: indexPath)
            let sr = serviceRequests[indexPath.row]
            
            srCell.textLabel?.text = sr.subject
            srCell.detailTextLabel?.text = sr.referenceNumber
            
            cell = srCell
        }
        else if !self.didQueryForSrs {
            cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath)
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.delegate?.serviceRequestSelected(at: indexPath.row)
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
            self.delegate?.deleteSr(at: indexPath.row, completion: nil)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
}
