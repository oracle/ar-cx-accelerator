//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ServiceRequestDetailsViewController.swift
// *********************************************************************************************
// 

import UIKit

class ServiceRequestDetailsViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var serviceRequestIdLabel: UILabel!
    @IBOutlet weak var referenceNumberLabel: UILabel!
    @IBOutlet weak var subjectLabel: UILabel!
    @IBOutlet weak var deviceIdLabel: UILabel!
    @IBOutlet weak var partIdLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var soundLabel: UILabel!
    @IBOutlet weak var vibrationLabel: UILabel!
    @IBOutlet weak var rpmLabel: UILabel!
    
    // MARK: - Properties
    
    /**
     Reference to the overlay view controller
    */
    private var overlayVc: ActivityOverlayViewController?
    
    /**
     Reference to the service request that will be displayed.
     */
    private var selectedServiceRequest: ServiceRequestResponse?
    
    // MARK: - UIViewController Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
        self.navigationItem.leftItemsSupplementBackButton = true
        
        guard let overlay = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateInitialViewController() as? ActivityOverlayViewController else { return }
        
        self.addChild(overlay)
        self.view.addSubview(overlay.view)
        
        self.overlayVc = overlay
        
        if overlay.isViewLoaded {
            overlay.view.backgroundColor = .gray
            overlay.setLabel("Select Service Request")
            overlay.activityIndicator.stopAnimating()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UI Methods
    
    /**
     Show an activity overlay above the view to indicate that an activity is occuring.
     
     - Parameter message: The text to set the activity label to.
     - Parameter withActivity: Flag to indicate if an activity spinner should be displayed and spinning.
    */
    func showOverlay(_ message: String?, withActivity: Bool = false) {
        guard let overlay = self.overlayVc else { return }
        
        DispatchQueue.main.async {
            if !self.view.subviews.contains(overlay.view) {
                self.view.addSubview(overlay.view)
            }
            
            if let message = message {
                overlay.setLabel(message)
            }
            
            switch withActivity {
            case true:
                overlay.activityIndicator.startAnimating()
            default:
                overlay.activityIndicator.stopAnimating()
            }
        }
    }
    
    /**
     Remove the overlay view from view and show the label fields..
    */
    func removeOverlay() {
        guard let overlay = self.overlayVc else { return }
        
        DispatchQueue.main.async {
            if self.view.subviews.contains(overlay.view) {
                overlay.view.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Data Methods
    
    /**
     Displays a service request by removing any overlay views and setting lebel values as required.
     
     - Parameter request: The service request response from the API.
    */
    func displayServiceRequest(_ request: ServiceRequestResponse?) {
        guard let request = request else { removeServiceRequest(); return }
        guard let id = request.id else { return }
        
        self.showOverlay("Getting SR Data", withActivity: true)
        
        self.selectedServiceRequest = request
        
        ICSBroker.shared.getServiceRequest(id, completion: { result in
            DispatchQueue.main.async {
                self.removeOverlay()
            }
            
            let showError: () -> () = {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error", message: "There was an error getting SR details. Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
                        // Do something when alert finished
                    }))
                    self.present(alert, animated: true)
                }
            }
            
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self.serviceRequestIdLabel.text = data.id
                    self.referenceNumberLabel.text = data.referenceNumber
                    self.subjectLabel.text = data.subject
                    self.deviceIdLabel.text = data.device?.deviceId
                    self.partIdLabel.text = data.device?.partId
                    self.temperatureLabel.text = data.device?.temperature
                    self.soundLabel.text = data.device?.sound
                    self.vibrationLabel.text = data.device?.vibration
                    self.rpmLabel.text = data.device?.rpm
                }
                
                break
            default:
                showError()
                break
            }
        })
    }
    
    /**
     Removes any currently set service request data and resets the label fields to empty strings.
    */
    func removeServiceRequest() {
        self.showOverlay("Select Service Request", withActivity: false)
        
        selectedServiceRequest = nil
        
        self.serviceRequestIdLabel.text = ""
        self.referenceNumberLabel.text = ""
        self.subjectLabel.text = ""
        self.deviceIdLabel.text = ""
        self.temperatureLabel.text = ""
        self.soundLabel.text = ""
        self.vibrationLabel.text = ""
        self.rpmLabel.text = ""
    }
}
