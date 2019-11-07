//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ServiceRequestDetailsNavigationViewController.swift
// *********************************************************************************************
// 

import UIKit

class ServiceRequestDetailsNavigationViewController: UINavigationController , UINavigationControllerDelegate {
    
    // MARK: - UINavigationController Methods
    
    override func viewDidLoad() {
        self.delegate = self
    }
    
    // MARK: - Segue Methods
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "CreateSRSegue":
            guard let svc = sender as? ServiceRequestSplitViewController else { return }
            guard let appId = svc.applicationId else { return }
            guard let device = svc.iotDevice else { return }
            guard let part = svc.selectedPart else { return }
            guard let controller = segue.destination as? CreateServiceRequestViewController else { return }
            
            controller.delegate = svc
            controller.applicationId = appId
            controller.iotDevice = device
            controller.selectedPart = part
            controller.screenshot = svc.screenshot
            controller.lastSensorMessage = svc.lastSensorMessage
            
            break
        default:
            return
        }
    }
    
    // MARK: - UINavigationControllerDelegate Methods
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if let vc = toVC as? ServiceRequestDetailsViewController {
            vc.showOverlay(nil)
            
            self.navigationController?.popToRootViewController(animated: true)
        }
        
        return nil
    }
}
