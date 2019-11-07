//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/8/19 11:59 AM
// *********************************************************************************************
// File: AppServerConfigs.swift
// *********************************************************************************************
// 

import UIKit

protocol AppServerConfigsDelegate: class {
    /**
     Notifies the delegate when configs are being retrieved from the server.
    */
    func gettingServerConfigs()
    
    /**
     Notifies the delegate that the configs request is completed.
     
     - Parameter result: Flag to indicate that configs were successfully received.
    */
    func serverConfigsRetrieved(_ result: Bool)
}

/**
 This extension will provide default implementation for the delegate allowing the methods to be optional for the implementing class.
 */
extension AppServerConfigsDelegate {
    func gettingServerConfigs() {}
}

class AppServerConfigs {
    
    /**
     Delegate for this class.
    */
    weak var delegate: AppServerConfigsDelegate?
    
    /**
     Variable to get server configs from different components of the application.
     */
    private(set) var serverConfigs: ServerConfigs?
    
    /**
     Variable to indicate if getting server configs.
     */
    private(set) var gettingServerConfigs: Bool = false
    
    // MARK: - Object Methods
    
    /**
     Convenience initialization method that assigns a delegate to this class during init.
     
     - Parameter delegate: The instance of the delegate to assign to this class.
    */
    convenience init(delegate: AppServerConfigsDelegate) {
        self.init()
        self.delegate = delegate
        
        self.delegate?.gettingServerConfigs()
        
        self.gettingServerConfigs = true
        
        (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getServerConfigs { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let configs):
                    self.gettingServerConfigs = false
                    self.serverConfigs = configs
                    self.delegate?.serverConfigsRetrieved(true)
                default:
                    self.delegate?.serverConfigsRetrieved(false)
                }
            }
        }
    }
}
