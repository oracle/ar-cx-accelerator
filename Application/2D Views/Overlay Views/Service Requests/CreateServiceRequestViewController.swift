//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: CreateServiceRequestViewController.swift
// *********************************************************************************************
// 

import UIKit
import os

protocol CreateServiceRequestViewControllerDelegate: class {
    /**
     Notifies the delegate that a service request has been created.
     
     - Parameter sr: The service request response after the record has been created.
     - Parameter completion: A callback method that is called after the delegate is done performing any work with the new service request.
    */
    func serviceRequestCreated(_ sr: ServiceRequestResponse, completion: (() -> ())?)
}

class CreateServiceRequestViewController: OverlayViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIBarButtonItem!
    @IBOutlet weak var subjectTextField: UITextField!
    @IBOutlet weak var contactIdTextField: UITextField!
    @IBOutlet weak var assetIdTextField: UITextField!
    @IBOutlet weak var partIdTextField: UITextField!
    @IBOutlet weak var tempTextField: UITextField!
    @IBOutlet weak var soundTextField: UITextField!
    @IBOutlet weak var vibrationTextField: UITextField!
    @IBOutlet weak var rpmTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextView!
    @IBOutlet weak var screenshotImageView: UIImageView!
    
    // MARK: - Properties
    
    /**
     Service request delegate that will take action on SR events.
     */
    weak var delegate: CreateServiceRequestViewControllerDelegate?
    
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
    
    /**
     Variable indicating if a service request creation is currently in process
     */
    private var creatingSr: Bool = false
    
    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup navigation button to create the SR
        let createButton = UIBarButtonItem(title: "Create", style: .plain, target: self, action: #selector(self.createHandler(_:)))
        self.navigationItem.rightBarButtonItem = createButton
        self.createButton = createButton

        // Do any additional setup after loading the view.
        notesTextField.layer.borderWidth = 0.5
        notesTextField.layer.borderColor = UIColor.lightGray.cgColor
        notesTextField.layer.cornerRadius = 8
        
        // Set Selected Part
        self.partIdTextField.text = selectedPart
        
        // Set Screenshot
        self.screenshotImageView.image = screenshot
        
        // Populate data
        guard let serverConfigs = (UIApplication.shared.delegate as? AppDelegate)?.appServerConfigs?.serverConfigs, let deviceId = self.iotDevice?.id else { return }
        
        let lastMessageHandler: (SensorMessage) -> () = { lastSensorMessage in
            guard let data = lastSensorMessage.payload?.data else { return }
            
            DispatchQueue.main.async {
                //TODO: Convert to generic custom fields for service apps so that sensor types do not have to be hard-coded or simply pass the last sensor message for context instead
                self.tempTextField.text = data["Bearing_Temperature"] != nil ? String(format: "%.2f", data["Bearing_Temperature"]!) : ""
                self.soundTextField.text = data["Pump_Noise_Level"] != nil ? String(format: "%.2f", data["Pump_Noise_Level"]!) : ""
                self.vibrationTextField.text = data["Pump_Vibration"] != nil ? String(format: "%.2f", data["Pump_Vibration"]!) : ""
                self.rpmTextField.text = data["Pump_RPM"] != nil ? String(format: "%.2f", data["Pump_RPM"]!) : ""
            }
        }
        
        if self.lastSensorMessage == nil {
            ICSBroker.shared.getHistoricalDeviceMessages(deviceId, completion: { result in
                let showError: () -> () = {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Error", message: "There was an error getting the latest IoTCS data for the form. You may continue to enter data manually.", preferredStyle: .alert)
                        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(action)
                        
                        self.present(alert, animated: true, completion: nil)
                    }
                }
                
                switch result {
                case .success(let data):
                    guard let items = data.items, items.count > 0 else { showError(); return }
                    
                    lastMessageHandler(items[0])
                    
                    break
                default:
                    showError()
                    break
                }
            }, limit: 1)
        } else {
            lastMessageHandler(self.lastSensorMessage!)
        }
        
        DispatchQueue.main.async {
            self.contactIdTextField.text = String(serverConfigs.service?.contactId ?? 1)
            self.assetIdTextField.text = deviceId
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation
    
    /**
    Create SR IBAction event handler
     
     - Parameter sender: The button that sent the request
     */
    @IBAction func createHandler(_ sender: UIBarButtonItem) {
        guard sender == createButton else { return }
        
        #if DEBUG
        os_log("Creating Service Request")
        #endif
        
        self.createButton.isEnabled = false
        
        createServiceRequest { sr in
            DispatchQueue.main.async {
                guard let sr = sr, let _ = sr.referenceNumber else {
                    os_log("SR response is empty")
                    
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Error", message: "There was an error creating your service request. Please ensure the environment is available and try again.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: {
                            DispatchQueue.main.async {
                                self.createButton.isEnabled = true
                            }
                        })
                    }
                    
                    return
                }
                
                self.delegate?.serviceRequestCreated(sr, completion: nil)
            }
        }
    }
    
    // MARK: CreateSr Methods
    
    /**
     Method used to create a service request for the AR device.
     
     - Parameter completion: Completion handler that is called when the process finishes in either success or failure.
     - Parameter response: The service request response if the creation was successful or nil.
     */
    private func createServiceRequest(completion: ((_ response: ServiceRequestResponse?) -> ())?) {
        guard creatingSr == false else { return }
        guard let contactIdText = self.contactIdTextField.text else { return }
        guard let contactId = Int(contactIdText) else { return }
        guard let device = self.assetIdTextField.text else { return }
        guard let overlayVc = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateInitialViewController() as? ActivityOverlayViewController else { return }
        
        DispatchQueue.main.async {
            self.view.endEditing(true) // Hide the keyboard if displayed.
            self.creatingSr = true
            
            overlayVc.view.frame = self.view.frame
            overlayVc.setLabel("Creating Service Request")
            
            self.view.addSubview(overlayVc.view)
            self.addChild(overlayVc)
        }
        
        var sr = ServiceRequestRequest()
        sr.subject = self.subjectTextField.text != nil && !self.subjectTextField.text!.isEmpty ? self.subjectTextField.text : "AR Service Request"
        sr.primaryContact.id = contactId
        sr.notes = self.notesTextField.text.data(using: .utf8)?.base64EncodedString()
        sr.device = ARDevice()
        sr.device?.deviceId = device
        sr.device?.partId = self.partIdTextField.text?.replacingOccurrences(of: " ", with: "_")
        sr.device?.temperature = self.tempTextField.text
        sr.device?.sound = self.soundTextField.text
        sr.device?.vibration = self.vibrationTextField.text
        sr.device?.rpm = self.rpmTextField.text
        
        if let imageData = self.screenshotImageView.image?.scaleImage(toWidth: 640)?.pngData() {
            sr.image = imageData.base64EncodedString()
        }
        
        ICSBroker.shared.createServiceRequest(with: sr) { result in
            #if DEBUG
            os_log("SR Request Completed")
            #endif
            
            self.creatingSr = false
            
            DispatchQueue.main.async {
                overlayVc.view.removeFromSuperview()
                overlayVc.removeFromParent()
            }
            
            switch result {
            case .success(let data):
                completion?(data)
                break
            default:
                completion?(nil)
                break
            }
        }
    }
}
