//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/28/19 2:46 PM
// *********************************************************************************************
// File: AppEventRecorder.swift
// *********************************************************************************************
// 

import UIKit
import CoreData
import os

class AppEventRecorder: AppEventSenderDelegate {
    
    // MARK: - Properties
    
    /**
     Singleton instance of the AppEventRecorder class.
    */
    private(set) static var shared = AppEventRecorder()
    
    /**
     Reference to the managed object context on a background thread.
     */
    private lazy var context: NSManagedObjectContext? = {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return nil }
        let context = appDelegate.appEventsPersistentContainer.viewContext
        let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        moc.parent = context
        
        return moc
    }()
    
    /**
     Alias of the EventCompletion return type.
     
     - Parameter result: Result object passed during completion.
     */
    typealias EventCompletion = ((_ result: Result<Bool, AppEventError>) -> ())
    
    // MARK: - Enums
    
    /**
     Enum to identify if the save context should occur on a certain thread.
     */
    enum SaveThread {
        case main,
        background
    }
    
    /**
     Identifies the various errors that can return from this class through a Swift Result object (see Swift 5 docs).
     */
    enum AppEventError: Error {
        case saveError,
        countError,
        objectContextError,
        sendError,
        sendInProcess
    }
    
    /**
     Identifies the various managed objects that the AppEvents managed object context exposes.
     */
    enum AppEventEntities: String {
        case event = "AppEvent"
    }
    
    // MARK: - Initializers
    
    /**
     Internal initializer for singleton.
     */
    private init() {
        AppEventSender.shared.delegate = self
        
        #if DEBUGEVENTS
        switch self.getEventCount() {
        case .success(let count):
            os_log(.debug, "Cached event count: %d", count)
            break
        case .failure(_):
            break
        }
        #endif
    }
    
    // MARK: - Event Recording Methods
    
    /**
     Record a record object. This implementatoin records just the name of an event.  The calling timestamp will be used for start and end; the length will be zero.
     
     - Parameter name: The name of the event.
     - Parameter completion: A completion block called when the save process is completed or fails.
     */
    func record(name: String, completion: EventCompletion?) {
        DispatchQueue.main.async {
            guard let obj = self.getObjectOnContext(type: AppEvent.self, entity: AppEventEntities.event) else { completion?(.failure(.objectContextError)); return }
            
            obj.name = name
            obj.eventStart = Date()
            obj.eventEnd = nil
            obj.eventLength = 0.0
            obj.readyToSend = true
            
            self.save(completion: completion)
        }
    }
    
    /**
     Record a record object. This implementatoin allows passing a string to store in the jsonData parameter.
     
     - Parameter name: The name of the event.
     - Parameter eventStart: The time of the event start.
     - Parameter eventEnd: The time of the event end.
     - Parameter eventLength: The length of time that the event took in seconds.
     - Parameter uiElement: The name of the UI element involved in the event.
     - Parameter arAnchor: The name of the AR anchor that was recognized at the time the event occurred.
     - Parameter arNode: The name of the AR node that was selected at the time the event occurred.
     - Parameter screenshot: A screenshot captured at the end of the event.
     - Parameter jsonString: Any JSON encoded data that the implementer wishes to include with the event.
     - Parameter completion: A completion block called when the save process is completed or fails.
     */
    func record(name: String, eventStart: Date?, eventEnd: Date?, eventLength: Float, uiElement: String?, arAnchor: String?, arNode: String?, jsonString: String?, completion: EventCompletion?) {
        // Put screenshot scaling and longer work on background thread.
        DispatchQueue.main.async {
            guard let obj = self.getObjectOnContext(type: AppEvent.self, entity: AppEventEntities.event) else { completion?(.failure(.objectContextError)); return }
            
            obj.name = name
            obj.eventStart = eventStart
            obj.eventEnd = eventEnd
            obj.eventLength = eventLength
            obj.uiElement = uiElement ?? ""
            obj.arAnchor = arAnchor
            obj.arNode = arNode
            obj.jsonData = jsonString
            obj.readyToSend = true
            
            self.save(completion: completion)
        }
    }
    
    /**
     Record a record object that is ready to send now. This implementatoin allows passing a string to store in the jsonData parameter.
     
     - Parameter name: The name of the event.
     - Parameter eventStart: The time of the event start.
     - Parameter eventEnd: The time of the event end.
     - Parameter eventLength: The length of time that the event took in seconds.
     - Parameter uiElement: The name of the UI element involved in the event.
     - Parameter arAnchor: The name of the AR anchor that was recognized at the time the event occurred.
     - Parameter arNode: The name of the AR node that was selected at the time the event occurred.
     - Parameter screenshot: A screenshot captured at the end of the event.
     - Parameter encodableData: Any JSON encodable object that the implementor wishes to include in the event.
     - Parameter completion: A completion block called when the save process is completed or fails.
     */
    func record<T: Encodable>(name: String, eventStart: Date?, eventEnd: Date?, eventLength: Float, uiElement: String?, arAnchor: String?, arNode: String?, encodableData: T, completion: EventCompletion?) {
        // Put screenshot scaling and longer work on background thread.
        DispatchQueue.main.async {
            guard let obj = self.getObjectOnContext(type: AppEvent.self, entity: AppEventEntities.event) else { completion?(.failure(.objectContextError)); return }
            
            obj.name = name
            obj.eventStart = eventStart
            obj.eventEnd = eventEnd
            obj.eventLength = eventLength
            obj.uiElement = uiElement
            obj.arAnchor = arAnchor
            obj.arNode = arNode
            obj.readyToSend = true
            
            let encoder = JSONEncoder()
            if let encodedData = try? encoder.encode(encodableData) {
                obj.jsonData = String(data: encodedData, encoding: .utf8)
            }
            
            self.save(completion: completion)
        }
    }
    
    /**
     Records an app event record on the context that was assigned to it on creation.  This method should be used for storing events in core data that are not ready to send at the point that core data is saved.
     
     - Parameter event: The event to record.
     - Parameter completion: The completion callback that is called after the save method runs.
    */
    func record(event: AppEvent, completion: EventCompletion?) {
        if event.eventEnd != nil && event.eventStart != nil && event.eventLength <= 0 {
            let diff = event.eventEnd!.timeIntervalSince1970 - event.eventStart!.timeIntervalSince1970
            event.eventLength = Float(diff)
        }
        
        DispatchQueue.main.async {
            self.save(completion: completion)
        }
    }
    
    /**
     Helper method to get the number of events currently stored in the Events object table.
     
     - Returns: The count of the table or count error.
    */
    func getEventCount() -> Result<Int, AppEventError> {
        guard let context = self.context else { return .failure(.countError) }
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: AppEventEntities.event.rawValue)
        request.returnsObjectsAsFaults = false
        
        guard let count = try? context.count(for: request) else { return .failure(.countError) }
        
        return .success(count)
    }
    
    /**
     Either creates a new AppEvent object or finds an existing record in the eventsInProcess array and returns it.
     
     This method is useful for starting event recording where a stop data will occur later in time.  This single event can record the start and end times.
     
     - Parameter name: The name of the event to return.
     
     - Returns: An AppEvent object.
    */
    public func getEvent(name: String) throws -> AppEvent {
        guard let context = self.context else { throw AppEventError.objectContextError }
        
        let predicate = NSPredicate(format: "name == %@ AND readyToSend == NO", name)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AppEvent")
        fetchRequest.predicate = predicate
        
        guard let results = try? context.fetch(fetchRequest) as? [AppEvent], results.count > 0 else {
            let newEvent = AppEvent(context: context)
            newEvent.eventStart = Date()
            newEvent.name = name
            
            self.save(completion: nil)
            
            return newEvent
        }
        
        var event: AppEvent! = results.first
        
        // If there is more than one open record, then there is a bug somewhere.  Delete extras just in case.
        if results.count > 1 {
            let sorted = results.sorted { (evt1, evt2) -> Bool in
                guard let date1 = evt1.eventStart, let date2 = evt2.eventStart else { return false }
                return date1 >= date2
            }
            
            for index in (1...sorted.count-1) {
                let eventToDelete = sorted[index]
                context.delete(eventToDelete)
            }
            
            event = sorted.first
        }
        
        self.save(completion: nil)
        
        return event
    }
    
    // MARK: - Private Methods
    
    /**
     Retrieves the desired object context and an object to operate on that contact.
     
     - Parameter type: The type of object to create.
     - Parameter entity: The entity of the managed object entity that the object represents.
     
     - Returns: The a tuple containing the created object on the background context.
     */
    private func getObjectOnContext<T: NSManagedObject>(type: T.Type, entity: AppEventEntities) -> T? {
        guard let context = self.context else { return nil }
        
        guard let newEntity = NSEntityDescription.entity(forEntityName: entity.rawValue, in: context) else {
            os_log(.error, "Could not get entity for event.")
            return nil
        }
        
        let obj: T = type.init(entity: newEntity, insertInto: context)
        
        return obj
    }
    
    /**
     Performs the save action on the context that is passed. This method implements debugging that could become cumbersome if not managed by a single method.
     
     - Parameter context: The context to save.
     - Parameter completion: Completion callback that will return the success or failure result of the save.
     */
    private func save(completion: EventCompletion?) {
        guard let context = self.context else { completion?(.failure(.saveError)); return }
        
        context.perform {
            do {
                if context.hasChanges {
                    try context.save()
                    try context.parent?.save()
                    
                    #if DEBUGEVENTS
                    os_log(.debug, "Managed Object Context Save Success")
                    #endif
                    
                    self.sendEvents(completion: nil)
                }
            } catch {
                error.log()
                completion?(.failure(.saveError))
                return
            }
            
            #if DEBUGEVENTS
            // Use the private context to get count since this operation is running on the background thread
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: AppEventEntities.event.rawValue)
            request.returnsObjectsAsFaults = false
            
            guard let result = (try? context.fetch(request))?.count else { os_log("Could not get event count."); return }
            os_log(.debug, "Cached event count after save: %d", result)
            #endif
            
            completion?(.success(true))
        }
    }
    
    /**
     Starts the process of sending events to the remote services configured in the AppEventSender.
     
     - Parameter completion: Completion called on success or failure.
    */
    private func sendEvents(completion: EventCompletion?) {
        // Only start sending if previous send process is completed
        if !AppEventSender.shared.sending {
            #if DEBUGEVENTS
            os_log(.debug, "Attempting to send events.")
            #endif
            
            self.getEventsToSend { (result) in
                switch result{
                case .success(let events):
                    AppEventSender.shared.postEvents(events: events, completion: { result in
                        switch result {
                        case .success(let res):
                            completion?(.success(res))
                        case .failure(let failure):
                            // Delete a failed post to prevent a record from sitting in cache forever.
                            switch failure{
                            case .sendError(_, let event):
                                self.delete(event: event)
                                break
                            default:
                                break
                            }
                            completion?(.failure(.sendError))
                            break
                        }
                    })
                    break
                default:
                    completion?(.failure(.sendError))
                }
            }
        } else {
            #if DEBUGEVENTS
            os_log(.debug, "App Events Send Already in Process")
            #endif
            
            completion?(.failure(.sendInProcess))
        }
    }
    
    /**
     Retrieves events from the core data cache and starts the post process to remote event services.
     
     - Parameter completion: Completion called when send process has completed or an error has occurred.
     */
    private func getEventsToSend(completion: ((Result<[AppEvent], AppEventError>) -> ())?) {
        // Use the private context to get count since this operation is running on the background thread
        guard let context = self.context else { completion?(.failure(.objectContextError)); return }
        
        context.perform {
            let predicate = NSPredicate(format: "readyToSend == YES")
            let request = NSFetchRequest<AppEvent>(entityName: AppEventEntities.event.rawValue)
            request.predicate = predicate
            
            guard let events = try? context.fetch(request) else { completion?(.failure(.objectContextError)); return }
            
            #if DEBUGEVENTS
            os_log(.debug, "Sending %d events", events.count)
            #endif
            
            completion?(.success(events))
        }
    }
    
    /**
     Deletes the passed event on the background object context.
     
     - Parameter event: The app event to delete from the local cache.
     */
    private func delete(event: AppEvent) {
        guard let context = self.context else { return }
        
        context.perform {
            
            context.delete(event)
            
            self.save(completion: nil)
            
            #if DEBUGEVENTS
            // Use the private context to get count since this operation is running on the background thread
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: AppEventEntities.event.rawValue)
            request.returnsObjectsAsFaults = false
            guard let result = (try? context.count(for: request)) else { os_log(.debug, "Could not get event count."); return }
            os_log(.debug, "Cached event count after delete: %d", result)
            #endif
        }
    }
    
    // MARK: - AppEventSenderDelegate Methods
    
    func startedSend() {
        // Do something when AppEventSender starts sending messages
    }
    
    func endedSend(_ result: Result<Bool, AppEventSender.AppEventSenderError>) {
        // Do something when AppEventSender is finished sending messages
    }
    
    func eventSent(_ event: AppEvent) {
        self.delete(event: event)
    }
}
