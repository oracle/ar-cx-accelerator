//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/15/19 9:59 AM
// *********************************************************************************************
// File: GenericIntegrationBroker.swift
// *********************************************************************************************
// 

import Foundation

/**
 Integration broker that provide methods to make HTTP calls that don't require specific implementation.
 */
class GenericIntegrationBroker: IntegrationBroker {
    
    // MARK: - Properties
    
    /**
     Property that holds the singleton instance of this class.
     */
    static let shared = GenericIntegrationBroker()
    
    /**
     The URL session that this class will use to broker HTTP requests.
     */
    let session: URLSession!
    
    //MARK: - Init Methods
    
    private init() {
        self.session = URLSession(configuration: .ephemeral)
    }
    
    //MARK: - Generic Methods
    
    /**
     Performs an URL request and returns the response.  It is up to the calling class to implement how to handle the resulting response.
     
     - Parameter request: The URL request to submit.
     - Parameter completion: Callback method called when URL request is finished.
    */
    func performRequest(request: URLRequest, completion: @escaping IntegrationCompletion) {
        self.asyncHttpRequest(session: self.session, request: request, completion: completion)
    }
}
