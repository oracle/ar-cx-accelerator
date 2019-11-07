//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 2/11/19 9:38 AM
// *********************************************************************************************
// File: CXInfinityBroker.swift
// *********************************************************************************************
// 

import Foundation
import os

/**
 Class to broker communication with CX Infinity APIs.
 */
class CXInfinityBroker: IntegrationBroker {
    
    // MARK: - Properties
    
    /**
     Property that holds the singleton instance of this class.
     */
    static let shared = CXInfinityBroker()
    
    /**
     The URL session that this class will use to broker HTTP requests.
     */
    let session: URLSession!
    
    //MARK: - Init Methods
    
    private init() {
        self.session = URLSession(configuration: .ephemeral)
    }
    
    //MARK: - Create Events Methods
    
    /**
     Method that will send a CX Infinity request with one or more events to CX Infinity.
     
     - Parameter infinityRequest: The CX Infinity request object to send in the API call.
     - Parameter completion: An event handler called once work is completed (success or failure).
    */
    func logEvents(_ infinityRequest: InfinityRequest, completion: ((_ result: Result<Bool, IntegrationBrokerError>) -> ())?) {
        
        guard let hostname = UserDefaults.standard.string(forKey: InfinityConfigs.hostname.rawValue) else { return }
        guard let backendId = UserDefaults.standard.string(forKey: InfinityConfigs.backendid.rawValue) else { return }
        
        let endpoint = String(format: "https://%@%@", hostname, backendId)
        guard let url = URL(string: endpoint) else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 15)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(infinityRequest)
            
            request.httpBody = encoded
        } catch {
            #if DEBUG
            os_log(.debug, "Unable to encode CX Infinity request.")
            #endif
            
            completion?(.failure(.requestCreationError))
            return
        }
        
        self.asyncHttpRequest(session: self.session, request: request) { result in
            switch result {
            case .success(_):
                completion?(.success(true))
                
                break
            case .failure(let failure):
                completion?(.failure(failure))
                break
            }
        }
    }
}
