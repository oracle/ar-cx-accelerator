//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ServiceRequestSplitViewController.swift
// *********************************************************************************************
// 

import UIKit
import os

class ServiceRequestSplitViewController: OverlaySplitViewController, UISplitViewControllerDelegate, CreateServiceRequestViewControllerDelegate, ServiceRequestTableViewControllerDelegate {
    
    // MARK - Properties
    
    /**
     Reference to the navigation controller in the master view.
    */
    weak var masterNavViewController: ServiceRequestNavigationController?
    
    /**
     Reference to the navigation controller in the details view.
     */
    weak var detailsNavViewController: ServiceRequestDetailsNavigationViewController?
    
    /**
     The API response when requesting a list of service requests.
     */
    var serviceRequests: ServiceRequestArrayResponse?
    
    /**
     The IoT Device object used to populate the device ID.
     */
    var iotDevice: IoTDevice?
    
    /**
     The last IoT Sensort message.  This data is used to populate the form.
     */
    var lastSensorMessage: SensorMessage?
    
    /**
     The asset part that was selected from the 3D interaction.
     */
    var selectedPart: String?
    
    /**
     A screenshot to include as an attachment with the SR.
     */
    var screenshot: UIImage?
    
    // MARK - UISplitViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.delegate = self
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.preferredDisplayMode = .allVisible
        }
        
        self.masterNavViewController = self.children.first(where: { $0.restorationIdentifier == "ServiceRequestNavigationController" }) as? ServiceRequestNavigationController
        self.detailsNavViewController = self.children.first(where: { $0.restorationIdentifier == "ServiceRequestDetailsNavigationViewController" }) as? ServiceRequestDetailsNavigationViewController
        
        if let tableVc = masterNavViewController?.children.first(where: { $0 is ServiceRequestTableViewController }) as? ServiceRequestTableViewController {
            tableVc.delegate = self
        }
        
        getServiceRequests(completion: nil)
    }
    
    // MARK: - UISplitViewControllerDelegate Methods
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    // MARK - Integration Methods

    /**
     Gets the list of service request for the device ID from ICS and the service app.
     
     - Parameter completion: A callback method after the request is completed.
    */
    private func getServiceRequests(completion: (() -> ())?) {
        let showCommunicationError: () -> () = {
            guard let detailsVc = self.detailsNavViewController?.children.first as? ServiceRequestDetailsViewController else {
                completion?()
                return
            }
            
            let alert = UIAlertController.init(title: "Communication Error", message: "Error getting service requests. Please check your connection.", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(action)
            
            DispatchQueue.main.async {
                detailsVc.present(alert, animated: true, completion: nil)
            }
        }
        
        guard let device = iotDevice, let deviceId = device.id, let part = self.selectedPart else {
            showCommunicationError()
            return
        }
        
        ICSBroker.shared.getServiceRequestList(for: deviceId, and: part.replacingOccurrences(of: " ", with: "_"), completion: { result in
            #if DEBUG
            os_log("Get Service Request List Completed")
            #endif
            
            switch result {
            case .success(let data):
                self.serviceRequests = data
                break
            case .failure(_):
                break
            }
            
            guard let tableVc = self.masterNavViewController?.children.first as? ServiceRequestTableViewController else {
                completion?()
                return
            }
            
            DispatchQueue.main.async {
                tableVc.didQueryForSrs = true
                tableVc.tableView.reloadData()
            }
            
            completion?()
        })
    }
    
    // MARK: - CreateServiceRequestViewControllerDelegate Methods
    
    /**
     Delegate method that will delete the record from the service application that was deleted from the table view.
     
     - Parameter sr: The sr respose object that was returned from the server after creation.
     - Parameter completion: A method called after the API call completes.
     */
    func serviceRequestCreated(_ sr: ServiceRequestResponse, completion: (() -> ())?) {
        DispatchQueue.main.async {
            self.detailsNavViewController?.popViewController(animated: true)
            self.detailsNavViewController?.navigationController?.popViewController(animated: true)
            
            self.getServiceRequests(completion: completion)
        }
    }
    
    // MARK: - ServiceRequestTableViewControllerDelegate Methods
    
    func closeRequested() {
        self.overlayDelegate?.closeRequested(sender: self.view)
    }
    
    func createServiceRequestRequested() {
        guard let navVc = self.detailsNavViewController else { return }
        
        navVc.performSegue(withIdentifier: "CreateSRSegue", sender: self)
        
        guard let detailsVc = navVc.children.first(where: { $0 is ServiceRequestDetailsViewController }) as? ServiceRequestDetailsViewController else { return }
        detailsVc.showOverlay("Select Service Request", withActivity: false)
        
        self.showDetailViewController(navVc, sender: self)
    }
    
    func deleteSr(at index: Int, completion: (() -> ())?) {
        guard self.serviceRequests?.items != nil, (0..<self.serviceRequests!.items!.count).contains(index) else { completion?(); return }
        guard let srId = self.serviceRequests!.items![index].id else { completion?(); return }
        
        self.serviceRequests!.items?.remove(at: index)
        
        try? ICSBroker.shared.deleteServiceRequest(srId: srId, completion: { result in
            completion?()
        })
    }
    
    func serviceRequestSelected(at index: Int) {
        guard let serviceRequests = serviceRequests?.items, let detailsNavVc = self.detailsNavViewController, let detailsVc = detailsNavVc.children.first as? ServiceRequestDetailsViewController else { return }
        
        if !(detailsNavVc.visibleViewController is ServiceRequestDetailsViewController) {
            detailsNavVc.popToRootViewController(animated: true)
            detailsNavVc.navigationController?.popViewController(animated: true)
        }
        
        guard (0..<serviceRequests.count).contains(index) else { return }
        
        let sr = serviceRequests[index]
        
        detailsVc.displayServiceRequest(sr)
        
        self.showDetailViewController(detailsNavVc, sender: self)
    }
}
