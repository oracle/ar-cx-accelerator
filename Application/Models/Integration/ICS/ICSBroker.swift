//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ICSBroker.swift
// *********************************************************************************************
// 

import Foundation
import os

/**
 Class to broker communication with ICS APIs.
 */
class ICSBroker: IntegrationBroker {
    
    // MARK: - Properties
    
    /**
     Property that holds the singleton instance of this class.
     */
    static let shared = ICSBroker()
    
    /**
     The URL session that this class will use to broker HTTP requests.
     */
    let session: URLSession!
    
    /**
     Server configuration object that indicates how to communicate with ICS.
     */
    private var serverConfigs: ServerConfigs?
    
    // MARK: - Enums
    
    private enum ICSEndpoints : String {
        case configs = "/integration/flowapi/rest/AR_APPLICATIO_CONFIGURAT/v01/ar/configs"
        case deviceData = "/integration/flowapi/rest/AR_GET_IOT_DEVICE_DATA/v01/" //append device ID
        case deviceMessages = "/integration/flowapi/rest/AR_GET_IOT_DEVICE_MESSAG/v01/" //append device ID
        case deviceTriggerIssue = "/integration/flowapi/rest/AR_TRIGGER_DEVICE_ISSUE/v01/" //append application ID - slash - device ID
        case ecServiceRequests = "/integration/flowapi/rest/GETSR_FOR_DEVICE_ENGAGE_CLOUD/v01/serviceRequests"
        case scServiceRequests = "/integration/flowapi/rest/GET_SR_BY_DEVIC_SERVI_CLOUD/v01/serviceRequests"
        case ecServiceRequest = "/integration/flowapi/rest/GET_ENGAGE_CLOUD_SERVIC_REQUES/v01/serviceRequests" // append ID for specific request
        case scServiceRequest = "/integration/flowapi/rest/GET_SERVICE_CLOUD_INCIDENT/v01/incidents" // append ID for specific request
        case ecCreateRequest = "/integration/flowapi/rest/CREATE_SERVIC_REQUES_ENGAGE_CLOU/v01/serviceRequests"
        case scCreateRequest = "/integration/flowapi/rest/CREATE_SERVIC_REQUES_SERVIC_CLOU/v01/serviceRequests"
        case scDeleteServiceRequest = "/integration/flowapi/rest/AR_DELETE_SERVIC_REQUES_OSVC/v01/serviceRequests" // append ID for specific request
        case ecKnowledgebaseAnswerContentList = "/integration/flowapi/rest/ENGAGE_CLOUD_GET_KB_CONTEN/v01/contents"
        case ecKnowledgebaseAnswerContentItem = "/integration/flowapi/rest/ENGAGE_CLOUD_KB_CONTEN_ITEM/v01/content/" // append knowledge ID for content item request
        case scKnowledgebaseAnswerContentList = "/integration/flowapi/rest/AR_KNOWLE_ADVANC_CONTEN_SEARCH/v01/contents"
        case scKnowledgebaseAnswerContentItem = "/integration/flowapi/rest/AR_KNOWL_ADVAN_GET_CONTE_ITEM/v01/contents" // append knowledge ID for content item request
        case scGetDeviceNodeDetails = "/integration/flowapi/rest/AR_GET_DEVIC_NODE_OSVC_SOAP/v01/device/%@/node/%@" // string format this path with device id and node id
        case scGetDeviceNodeNotes = "/integration/flowapi/rest/AR_GET_NOD_DET_BY_DEV_AND_NOD_SO/v01/device/%@/node/%@" // string format this path with device id and node id
        case scCreateDeviceNodeNote = "/integration/flowapi/rest/AR_CREAT_NODE_NOTE_SERVI_CLOUD/v01/node/%d/Notes" // string format this path with proper node id
        case scDeleteNote = "/integration/flowapi/rest/AR_DELETE_NOTE_OSVC/v01/node/%d/note/%d" // string format this path with the proper modelnode and note id
        case scAppEvent = "/integration/flowapi/rest/AR_CREAT_APP_EVENT_SERVI_CLOUD/v01/app-events"
    }
    
    /**
     Errors that can be thrown by methods in this class
    */
    enum ICSError: Error {
        case communicationFailure,
        invalidServiceApp,
        invalidServerConfigs
    }
    
    // MARK: - Init Methods
    
    private init(){
        self.session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: nil)
    }
    
    // MARK: - Private Methods
    
    /**
     Convenience method to get ICS parameters that are stored in application settings for use in API calls.
     
     - Returns: A tuple containing the ICS hostname, username, and password for integration.
    */
    private func getLocalICSCredentials() throws -> (String, String, String)  {
        guard let hostname = UserDefaults.standard.string(forKey: ICSConfigs.hostname.rawValue),
            let username = UserDefaults.standard.string(forKey: ICSConfigs.username.rawValue),
            let password = UserDefaults.standard.string(forKey: ICSConfigs.password.rawValue) else {
                throw ICSError.invalidServerConfigs
        }
        
        return (hostname, username, password)
    }
    
    // MARK: - Public Methods
    
    /**
     Get the AR Configuration object that is served by ICS via remote endpoint.
     
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getServerConfigs(completion: @escaping (Result<ServerConfigs, IntegrationBrokerError>) -> ()) {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            guard let messages = DataSimulator.performGet(object: ServerConfigs.self) else { completion(.failure(.noDataReturned)); return }
            completion(.success(messages))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else {
            os_log("Could not obtain credentials to integrate with ICS.")
            completion(.failure(.requestCreationError))
            return
        }
        
        let urlStr = String(format: "https://%@%@", credentials.0, ICSEndpoints.configs.rawValue)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            os_log("Could not create url request for application settings.")
            completion(.failure(.requestCreationError))
            return
        }
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: ServerConfigs.self, data: data) else { completion(.failure(.noDataReturned)); return }
                self.serverConfigs = parsedResponse
                completion(.success(parsedResponse))
                
                break
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to get the IoT device information
     
     - Parameter deviceId: The ID for the device queried for.
     - Parameter completion: Callback method once the HTTP request completes
     */
    func getDeviceInfo(_ deviceId: String, completion: @escaping (Result<IoTDevice, IntegrationBrokerError>) -> ()) {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            guard let messages = DataSimulator.performGet(object: IoTDevice.self) else { completion(.failure(.noDataReturned)); return }
            completion(.success(messages))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        
        let urlStr = String(format: "https://%@%@%@", credentials.0, ICSEndpoints.deviceData.rawValue, deviceId)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: IoTDevice.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
                
                break
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to get the IoT device messages.
     
     - Parameter deviceId: The device ID to retrieve messages for.
     - Parameter completion: Callback method once the HTTP request completes.
     - Parameter limit: A query limit applied to the number of devices retrieved.
     */
    func getHistoricalDeviceMessages(_ deviceId: String, completion: @escaping (Result<SensorMessageResponse, IntegrationBrokerError>) -> (), limit: Int = 1) {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            var messages = SensorMessageResponse()
            messages.items = DataSimulator.createTemperatureProjectionModel(dataMin: 0, dataMax: 500, recordsToCreate: limit, createAnomalies: false)
            completion(.success(messages))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        
        let urlStr = String(format: "https://%@%@%@?limit=%d&sortBy=eventTime:desc", credentials.0, ICSEndpoints.deviceMessages.rawValue, deviceId, limit)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: SensorMessageResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
                
                break
            case .failure(let failure):
                completion(.failure(failure))
            }
            
        }
    }
    
    /**
     Performs call to ICS to trigger the filter clogged event or remove it.
     
     - Parameter applicationId: The IoTCS application ID that the device exists under.
     - Parameter deviceId: The device ID to retrieve messages for.
     - Parameter request: Request data to pass to ICSBroker.
     - Parameter completion: Callback method once the HTTP request completes.
     - Parameter result: The result of the HTTP request.
     */
    func triggerDeviceIssue(applicationId: String, deviceId: String, request: DeviceEventTriggerRequest, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            // This method does nothing when simulator is on
            completion(.success(true))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        
        let urlStr = String(format: "https://%@%@%@/%@", credentials.0, ICSEndpoints.deviceTriggerIssue.rawValue, applicationId, deviceId)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        
        urlRequest.httpBody = try? encoder.encode(request)
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(_):
                completion(.success(true))
                break
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to get the IoT device's service request list from the configured service application.  This call only has limited information and inteded for list views.
     
     - Parameter deviceId: The device ID used for the service request.
     - Parameter partId: The part ID used for the service request.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getServiceRequestList(for deviceId: String, and partId: String, completion: @escaping (Result<ServiceRequestArrayResponse, IntegrationBrokerError>) -> ()) {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            let messages = DataSimulator.performGet(object: ServiceRequestArrayResponse.self)
            let items = messages?.items?.filter({ $0.device?.partId == partId })
            var srArrResponse = ServiceRequestArrayResponse()
            srArrResponse.items = items
            completion(.success(srArrResponse))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = app == .engagementCloud ? .ecServiceRequests : .scServiceRequests
        let idLabel = app == .engagementCloud ? "SrNumber" : "id"
        let urlStr = String(format: "https://%@%@?deviceId=%@&partId=%@&orderBy=%@:desc", credentials.0, appPath.rawValue, deviceId, partId, idLabel)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        urlRequest.httpMethod = "GET"
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: ServiceRequestArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to get a specific service request from the configured service application.
     
     - Parameter id: The ID of the service request to retrieve.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getServiceRequest(_ id: String, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ()) {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            let messages = DataSimulator.performGet(object: ServiceRequestArrayResponse.self)
            guard let item = messages?.items?.first(where: { $0.id == id }) else { completion(.failure(.noDataReturned)); return }
            completion(.success(item))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = app == .engagementCloud ? .ecServiceRequest : .scServiceRequest
        let urlStr = String(format: "https://%@%@/%@", credentials.0, appPath.rawValue, id)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        urlRequest.httpMethod = "GET"
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: ServiceRequestResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to create a service request for the IoT device for the configured service application.
     
     - Parameter request: The ServiceRequest request object.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func createServiceRequest(with request: ServiceRequestRequest, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ()) {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            // In the case of a create, just get the simulated service request response since it will be the same format as the results of an actual creation.
            guard let messages = DataSimulator.performGet(object: ServiceRequestResponse.self) else { completion(.failure(.noDataReturned)); return }
            completion(.success(messages))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = app == .engagementCloud ? .ecCreateRequest : .scCreateRequest
        let urlStr = String(format: "https://%@%@", credentials.0, appPath.rawValue)
        
        #if DEBUGNETWORK
        os_log(urlStr)
        #endif
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        
        let jsonEncoder = JSONEncoder()
        guard let json = try? jsonEncoder.encode(request) else {
            #if DEBUG
            os_log("Could not encode JSON request.")
            #endif
            completion(.failure(.jsonParseError))
            return
        }
        
        
        let jsonStr = String(data: json, encoding: .utf8)
        
        #if DEBUGNETWORK
        // If there is an image, then do not show JSON as the Base64 string pollutes the output
        if jsonStr != nil && request.image == nil {
            os_log("JSON:")
            os_log(jsonStr!)
        }
        #endif
        
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = json
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: ServiceRequestResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to delete a service request.
     
     - Parameter modelNodeId: Model node ID to post the note to.
     - Parameter noteId: The note ID.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: ICSError.invalidServiceApp when Service Cloud is not used because only Service Cloud serves notes currently.
     */
    func deleteServiceRequest(srId: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws {
        // If the local data flag is set to true, then do not make external calls.  This results in some hard-coded logic in later methods when the answer attachments (PDFs) are used.
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            completion(.success(true))
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        //TODO: Add delete SR functionality to Engagement Cloud
        // Ensure that the current app is OSvC, otherwise stop.
        guard app == .serviceCloud else {
            #if DEBUG
            os_log("Delete SR is not currently implemented in Engagement Cloud.")
            #endif
            
            throw ICSError.invalidServiceApp
        }
        
        guard let id = Int(srId) else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = .scDeleteServiceRequest
        let urlStr = String(format: "https://%@%@/%d", credentials.0, appPath.rawValue, id)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        urlRequest.httpMethod = "DELETE"
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(_):
                completion(.success(true))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to query for answers.
     
     - Parameter contentType: The Engagement Cloud answer content type used in the search filter
     - Parameter titleSearch: An array of titles that can be matched in the KB search.
     - Parameter limit: Record query limit
     - Parameter offset: Record query offset
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: `ICSError.invalidServiceApp` if an incorrect service app setting is used.
     */
    func getAnswers(contentType: String, titleSearch: [String], limit: Int, offset: Int, completion: @escaping (Result<AnswerArrayResponse, IntegrationBrokerError>) -> ()) throws {
        // If the local data flag is set to true, then do not make external calls
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            guard var messages = DataSimulator.performGet(object: AnswerArrayResponse.self) else { completion(.failure(.noDataReturned)); return }
            let searchStr = titleSearch[0].trimmingCharacters(in: CharacterSet(charactersIn: "*")).lowercased()
            let filteredItems = messages.items?.filter({ ($0.xml?.contains(contentType.uppercased()) ?? false) && ($0.title?.lowercased().contains(searchStr) ?? false) })
            messages.items = filteredItems
            completion(.success(messages))
            
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = app == .serviceCloud ? .scKnowledgebaseAnswerContentList : .ecKnowledgebaseAnswerContentList
        let titles = titleSearch.joined(separator: "','")
        let urlStr = String(format: "https://%@%@?q=contentType.referenceKey eq '%@' and title likeAny ('%@')&limit=%d&offset=%d", credentials.0, appPath.rawValue, contentType, titles, limit, offset)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        urlRequest.httpMethod = "GET"
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: AnswerArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to query for a specific answer.
     
     - Parameter id: The recordId of the answer to query for.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: `ICSError.invalidServiceApp` if Service Cloud is used and a knowledge call is made.  Engagement Cloud is used for knowledge.
     */
    func getAnswer(id: String, completion: @escaping (Result<AnswerResponse, IntegrationBrokerError>) -> ()) throws {
        // If the local data flag is set to true, then do not make external calls.  This results in some hard-coded logic in later methods when the answer attachments (PDFs) are used.
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            let messages = DataSimulator.performGet(object: AnswerArrayResponse.self)
            guard let item = messages?.items?.first(where: { $0.recordId == id }) else { completion(.failure(.noDataReturned)); return }
            completion(.success(item))
            
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = app == .serviceCloud ? .scKnowledgebaseAnswerContentItem : .ecKnowledgebaseAnswerContentItem
        let urlStr = String(format: "https://%@%@/%@", credentials.0, appPath.rawValue, id)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        urlRequest.httpMethod = "GET"
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: AnswerResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /**
     Performs call to ICS to query for the AR metadata for the recognized image/object.
     
     - Parameter name: The name of the object that was recognized in the AR space.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getRecognitionData(name: String, completion: @escaping (Result<ARRecognitionContext, IntegrationBrokerError>) -> ()) {
        //Procedure data is currently stored locally in this app.
        //TODO: Move procedure definition to an application / API that can serve the request dynamically.
        let messages = DataSimulator.performGet(object: ARRecognitionContextArrayResponse.self)
        guard let context = messages?.items?.first(where: { $0.name == name }) else { completion(.failure(.noDataReturned)); return }
        completion(.success(context))
        return
    }
    
    /**
     Performs call to ICS to query for the AR metadata for the selected node.
     
     - Parameter nodeName: The node to retrieve procedure data for.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getNodeData(nodeName: String, completion: @escaping (Result<ARNodeContext, IntegrationBrokerError>) -> ()) {
        //Procedure data is currently stored locally in this app.
        //TODO: Move procedure definition to an application / API that can serve the request dynamically.
        let messages = DataSimulator.performGet(object: ARNodeContextArrayResponse.self)
        guard let assetNode = messages?.items?.first(where: { $0.name == nodeName }) else { completion(.failure(.noDataReturned)); return }
        completion(.success(assetNode))
        return
    }
    
    /**
     Performs call to ICS to query for the modelnode record details.  This is required to submit notes for a specific node in other API calls.
     
     - Parameter deviceId: Of the device in the AR experience.
     - Parameter nodeName: The node to retrieve notes data for.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: ICSError.invalidServiceApp when Service Cloud is not used because only Service Cloud serves notes currently.
     */
    func getModelNodeDetails(deviceId: String, nodeName: String, completion: @escaping (Result<ARNodeDetailArrayResponse, IntegrationBrokerError>) -> ()) throws {
        // If the local data flag is set to true, then do not make external calls.  This results in some hard-coded logic in later methods when the answer attachments (PDFs) are used.
        let dataSimulator = UserDefaults.standard.bool(forKey: AppConfigs.dataSimulator.rawValue)
        if dataSimulator {
            let response = DataSimulator.performGet(object: ARNodeDetailArrayResponse.self)?.items?.filter({ $0.node == nodeName })
            var newResponse = ARNodeDetailArrayResponse()
            newResponse.items = response
            completion(.success(newResponse))
            
            return
        }
        
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        //TODO: Add notes functionality to Engagement Cloud
        // Ensure that the current app is OSvC, otherwise stop.
        guard app == .serviceCloud else {
            #if DEBUG
            os_log("Notes are not currently implemented in Engagement Cloud.")
            #endif
            
            throw ICSError.invalidServiceApp
        }
        
        let appPath: ICSEndpoints = .scGetDeviceNodeDetails
        let formattedEndpoint = String(format: appPath.rawValue, deviceId, nodeName)
        let urlStr = String(format: "https://%@%@", credentials.0, formattedEndpoint)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        urlRequest.httpMethod = "GET"
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: ARNodeDetailArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
}
