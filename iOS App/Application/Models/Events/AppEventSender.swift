//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 4/1/19 11:43 AM
// *********************************************************************************************
// File: AppEventSender.swift
// *********************************************************************************************
// 

import UIKit
import os

protocol AppEventSenderDelegate {
    /**
     Method called when the send process for one or more events starts.
    */
    func startedSend()
    
    /**
     Called when a single event has successfully remotely posted.
     
     - Parameter event: The event that was sent in the request.
     */
    func eventSent(_ event: AppEvent)
    
    /**
     Called when the send process finishes (either successfully or not).
     
     - Parameter result: The result of the completed process.
     */
    func endedSend(_ result: Result<Bool, AppEventSender.AppEventSenderError>)
}

class AppEventSender {
    
    // MARK: - Properties
    
    /**
     Singleton instance.
     */
    private(set) static var shared = AppEventSender()
    
    /**
     Reference to the delegate.
     */
    var delegate: AppEventSenderDelegate?
    
    /**
     Flag to indicate if sending to remote data sources is in process.
     */
    private(set) var sending: Bool = false
    
    /**
     Type alias for commonly used completion handler.
     */
    typealias AppEventSenderCompletion = ((Result<[AppEvent]?, AppEventSenderError>) -> ())
    
    /**
     Type alias for commonly used completion handler.
     */
    typealias PostCompletion = ((Result<Bool, AppEventSenderError>) -> ())
    
    // MARK: - Properties
    
    /**
     Errors that may be thrown by the AppEventSender class.
     */
    enum AppEventSenderError: Error {
        case sendingInProcess,
        sendError(_ error: IntegrationBrokerError, event: AppEvent),
        coreDataError
    }
    
    // MARK: - Initializers
    
    /**
     Private initializer for singleton.
    */
    private init() {
        
    }
    
    // MARK: - Public Methods
    
    /**
     Establishes the send loop for the events currently being send to remote event services.  Sends one event at a time to reduce network latency.
     
     - Parameter events: The array of events currently being sent to remote data sources.
     - Parameter completion: Completion called when send process has completed or an error has occurred.
     */
    func postEvents(events: [AppEvent], completion: PostCompletion?) {
        if events.count == 0 {
            #if DEBUGEVENTS
            os_log(.debug, "Events post ended")
            #endif
            
            self.delegate?.endedSend(.success(true))
            self.sending = false
            return
        }
        
        self.sending = true
        let event = events[0]
        
        self.postEvent(event: event) { (result) in
            switch result {
            case .success(_):
                var newEventsArr = events
                newEventsArr.removeFirst()
                self.postEvents(events: newEventsArr, completion: completion)
                
                break
            case .failure(let failure):
                completion?(.failure(failure))
                self.sending = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    //TODO: Implement recording to Service Cloud
    /**
     Performs the work for mapping the event to different event services, sending the results, and handling the callback.  This will delete the record from core data cache if post is successful.
     
     - Parameter events: The event currently being sent to remote data sources.
     - Parameter completion: Completion called when send process has completed or an error has occurred.
     */
    private func postEvent(event: AppEvent, completion: @escaping PostCompletion) {
        #if DEBUGEVENTS
        os_log(.debug, "Posting event: %@", (event.name ?? ""))
        #endif
        
        self.postToCxInfinity(event: event) { (result) in
            switch result {
            case .success(_):
                // Delete the record from core data
                self.delegate?.eventSent(event)
                
                // Notify of completion
                completion(.success(true))
                
                break
            case .failure(let failure):
                completion(.failure(failure));
                break
            }
        }
    }
    
    /**
     Posts the passed event to CX infinity using the object mapping defined in this method.
     
     - Parameter event: The app event to pass to the remote service.
     - Parameter completion: The completion callback called once the remote work is done.
     */
    private func postToCxInfinity(event: AppEvent, completion: @escaping PostCompletion) {
        let formatter = ISO8601DateFormatter()
        
        var infinityEvent = InfinityEvent()
        infinityEvent.eventName = event.name
        infinityEvent.eventStart = event.eventStart != nil ? formatter.string(from: event.eventStart!) : nil
        infinityEvent.eventEnd = event.eventEnd != nil ? formatter.string(from: event.eventEnd!) : nil
        infinityEvent.eventLength = Int(event.eventLength)
        infinityEvent.arNode = event.arNode
        infinityEvent.arAnchor = event.arAnchor
        infinityEvent.arData = event.jsonData
        infinityEvent.uiElement = event.uiElement
        infinityEvent.arDemoPerson = UserDefaults.standard.string(forKey: AppConfigs.demoPersonName.rawValue)
        infinityEvent.arDemoPersonEmail = UserDefaults.standard.string(forKey: AppConfigs.demoPersonEmail.rawValue)
        infinityEvent.arDemoName = UserDefaults.standard.string(forKey: AppConfigs.demoName.rawValue)
        infinityEvent.arDemoOrg = UserDefaults.standard.string(forKey: AppConfigs.demoOrg.rawValue)
        
        let request = InfinityRequest(staticProps: nil, events: [infinityEvent])
        
        CXInfinityBroker.shared.logEvents(request) { (result) in
            switch result {
            case .success(_):
                #if DEBUGEVENTS
                os_log(.debug, "%@ - Post to CX Infinity Successful", (event.name ?? "No Event Name"))
                #endif
                
                completion(.success(true))
                
                break
            case .failure(let failure):
                failure.log()
                #if DEBUGEVENTS
                os_log(.debug, "%@ - Post to CX Infinity Failure: %@", event.name ?? "No Event Name", failure.localizedDescription)
                #endif
                
                completion(.failure(.sendError(failure, event: event)))
                
                break
            }
        }
    }
}
