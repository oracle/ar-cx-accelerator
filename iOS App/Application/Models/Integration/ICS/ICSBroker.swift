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
class ICSBroker: IntegrationBroker, RemoteIntegrationBroker {
    
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
     Server configuration object that indicates how to communicate with ICS and other applications.
     */
    private var serverConfigs: ServerConfigs?
    
    // MARK: - Enums
    
    private enum ICSEndpoints : String {
        case configs = "/ic/api/integration/v1/flows/rest/AR_APPLICATIO_CONFIGURAT/1.0/ar/configs"
        case arRecognitionContexts = "/ic/api/integration/v1/flows/rest/AR_RECOGNITIO_CONTEXTS/1.0/"
        case arRecognitionDeviceMappings = "/ic/api/integration/v1/flows/rest/AR_DEVICE_RECOGNIT_MAPPING/1.0/"
        case deviceData = "/ic/api/integration/v1/flows/rest/AR_GET_IOT_DEVICE_DATA/1.0/" //append device ID
        case deviceMessages = "/ic/api/integration/v1/flows/rest/AR_GET_IOT_DEVICE_MESSAG/1.0/" //append device ID
        case deviceTriggerIssue = "/ic/api/integration/v1/flows/rest/AR_TRIGGER_DEVICE_ISSUE/1.0/" //append application ID - slash - device ID
        case ecServiceRequests = "/ic/api/integration/v1/flows/rest/GETSR_FOR_DEVICE_ENGAGE_CLOUD/1.0/serviceRequests"
        case scServiceRequests = "/ic/api/integration/v1/flows/rest/GET_SR_BY_DEVIC_SERVI_CLOUD/1.0/serviceRequests"
        case ecServiceRequest = "/ic/api/integration/v1/flows/rest/GET_ENGAGE_CLOUD_SERVIC_REQUES/1.0/serviceRequests" // append ID for specific request
        case scServiceRequest = "/ic/api/integration/v1/flows/rest/GET_SERVICE_CLOUD_INCIDENT/1.0/incidents" // append ID for specific request
        case ecCreateRequest = "/ic/api/integration/v1/flows/rest/CREATE_SERVIC_REQUES_ENGAGE_CLOU/1.0/serviceRequests"
        case scCreateRequest = "/ic/api/integration/v1/flows/rest/CREATE_SERVIC_REQUES_SERVIC_CLOU/1.0/serviceRequests"
        case scDeleteServiceRequest = "/ic/api/integration/v1/flows/rest/AR_DELETE_SERVIC_REQUES_OSVC/1.0/serviceRequests" // append ID for specific request
        //TODO: Add AR_DELETE_SERVIC_REQUES_OSVC Engagement Cloud
        case ecKnowledgebaseAnswerContentList = "/ic/api/integration/v1/flows/rest/ENGAGE_CLOUD_GET_KB_CONTEN/1.0/contents"
        case ecKnowledgebaseAnswerContentItem = "/ic/api/integration/v1/flows/rest/ENGAGE_CLOUD_KB_CONTEN_ITEM/1.0/content/" // append knowledge ID for content item request
        case scKnowledgebaseAnswerContentList = "/ic/api/integration/v1/flows/rest/AR_KNOWLE_ADVANC_CONTEN_SEARCH/1.0/contents"
        case scKnowledgebaseAnswerContentItem = "/ic/api/integration/v1/flows/rest/AR_KNOWL_ADVAN_GET_CONTE_ITEM/1.0/contents" // append knowledge ID for content item request
        case scGetDeviceNodeDetails = "/ic/api/integration/v1/flows/rest/AR_GET_DEVIC_NODE_OSVC_SOAP/1.0/device/%@/node/%@" // string format this path with device id and node id
        //TODO: Add scGetDeviceNodeDetails Engagement Cloud
        case scGetDeviceNodeNotes = "/ic/api/integration/v1/flows/rest/AR_GET_NOD_DET_BY_DEV_AND_NOD_SO/1.0/device/%@/node/%@" // string format this path with device id and node id
        //TODO: Add scGetDeviceNodeNotes Engagement Cloud
        case scCreateDeviceNodeNote = "/ic/api/integration/v1/flows/rest/AR_CREAT_NODE_NOTE_SERVI_CLOUD/1.0/node/%d/Notes" // string format this path with proper node id
        //TODO: Add scCreateDeviceNodeNote Engagement Cloud
        case scDeleteNote = "/ic/api/integration/v1/flows/rest/AR_DELETE_NOTE_OSVC/1.0/node/%d/note/%d" // string format this path with the proper modelnode and note id
        //TODO: Add scDeleteNote Engagement Cloud
        case scAppEvent = "/ic/api/integration/v1/flows/rest/AR_CREAT_APP_EVENT_SERVI_CLOUD/1.0/app-events"
        //TODO: Add scAppEvent Engagement Cloud
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
                throw IntegrationError.invalidServerConfigs
        }
        
        return (hostname, username, password)
    }
    
    // MARK: - RemoteIntegrationBrokerProtocol Methods
    
    func getServerConfigs(completion: @escaping (Result<ServerConfigs, IntegrationBrokerError>) -> ()) {
        guard let credentials = try? self.getLocalICSCredentials() else {
            os_log(.error, "Could not obtain credentials to integrate with ICS.")
            completion(.failure(.requestCreationError))
            return
        }
        
        let urlStr = String(format: "https://%@%@", credentials.0, ICSEndpoints.configs.rawValue)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2, timeoutInterval: 15) else {
            os_log(.error, "Could not create url request for application settings.")
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
    
    func getRecognitionContext(major: Int, minor: Int, completion: @escaping (Result<ARRecognitionContext, IntegrationBrokerError>) -> ()) {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        
        let urlStr = String(format: "https://%@%@", credentials.0, ICSEndpoints.arRecognitionContexts.rawValue)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2, timeoutInterval: 15) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: ARRecognitionContextArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                guard let modelContext = parsedResponse.items?.first(where: { $0.major == major }) else { completion(.failure(.noDataReturned)); return }
                
                completion(.success(modelContext))
                
                break
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    func getUUIDsForRecognizedDevice(major: Int, minor: Int, completion: @escaping (Result<(String, String), IntegrationBrokerError>) -> ()) {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        
        let urlStr = String(format: "https://%@%@", credentials.0, ICSEndpoints.arRecognitionDeviceMappings.rawValue)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2, timeoutInterval: 15) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(let data):
                guard let parsedResponse = self.jsonDataHandler(decodableType: ARRecognitionToDeviceMappingArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                guard let mapping = parsedResponse.items?.first(where: { $0.major == major && $0.minor == minor }) else { completion(.failure(.noDataReturned)); return }
                completion(.success((mapping.applicationId, mapping.deviceId)))
                
                break
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    func getNodeData(nodeName: String, completion: @escaping (Result<ARNodeContext, IntegrationBrokerError>) -> ()) {
        // This method serves data from a JSON file locally when ICS is used.  Try OCI F(n) for the actual implementation.
        let messages = DataSimulator.performGet(object: ARNodeContextArrayResponse.self)
        guard let assetNode = messages?.items?.first(where: { $0.name == nodeName }) else { completion(.failure(.noDataReturned)); return }
        completion(.success(assetNode))
    }
    
    func getDeviceInfo(_ deviceId: String, completion: @escaping (Result<IoTDevice, IntegrationBrokerError>) -> ()) {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        
        let urlStr = String(format: "https://%@%@%@", credentials.0, ICSEndpoints.deviceData.rawValue, deviceId)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2, timeoutInterval: 15) else {
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
    
    func getHistoricalDeviceMessages(_ applicationId: String, _ deviceId: String, completion: @escaping (Result<SensorMessageResponse, IntegrationBrokerError>) -> (), limit: Int = 1) {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        
        let urlStr = String(format: "https://%@%@%@?limit=%d&sortBy=eventTime:desc", credentials.0, ICSEndpoints.deviceMessages.rawValue, deviceId, limit)
        
        guard let urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2, timeoutInterval: 15) else {
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
    
    func getDeviceArActionMapping(_ applicationId: String, _ deviceId: String, completion: @escaping (Result<ARDeviceActionMapping, IntegrationBrokerError>) -> ()) {
        guard let messages = DataSimulator.performGet(object: ARDeviceActionMappingArrayResponse.self)?.items?.first(where: { $0.deviceId == deviceId && $0.applicationId == applicationId }) else { completion(.failure(.noDataReturned)); return }
        completion(.success(messages))
        return
    }
    
    func triggerDeviceIssue(applicationId: String, deviceId: String, request: DeviceEventTriggerRequest, deviceModel: String = "urn:com:blue:pump:data", action: String = "resetFilter", completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) {
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
    
    func getServiceRequestList(for deviceId: String, and partId: String, completion: @escaping (Result<ServiceRequestArrayResponse, IntegrationBrokerError>) -> ()) {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = app == .engagementCloud ? .ecServiceRequests : .scServiceRequests
        let idLabel = app == .engagementCloud ? "SrNumber" : "id"
        let urlStr = String(format: "https://%@%@?deviceId=%@&partId=%@&orderBy=%@:desc", credentials.0, appPath.rawValue, deviceId, partId, idLabel)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2, timeoutInterval: 15) else {
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
    
    func getServiceRequest(_ id: String, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ()) {
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
    
    func createServiceRequest(with request: ServiceRequestRequest, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ()) {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        let appPath: ICSEndpoints = app == .engagementCloud ? .ecCreateRequest : .scCreateRequest
        let urlStr = String(format: "https://%@%@", credentials.0, appPath.rawValue)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        let jsonEncoder = JSONEncoder()
        guard let json = try? jsonEncoder.encode(request) else {
            #if DEBUG
            os_log(.debug, "Could not encode JSON request.")
            #endif
            completion(.failure(.jsonParseError))
            return
        }
        
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
    
    func deleteServiceRequest(srId: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        //TODO: Add delete SR functionality to Engagement Cloud
        // Ensure that the current app is OSvC, otherwise stop.
        guard app == .serviceCloud else {
            #if DEBUG
            os_log(.debug, "Delete SR is not currently implemented in Engagement Cloud.")
            #endif
            
            throw IntegrationError.invalidServiceApp
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
    
    func getAnswers(contentType: String, titleSearch: [String], limit: Int, offset: Int, completion: @escaping (Result<AnswerArrayResponse, IntegrationBrokerError>) -> ()) throws {
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
    
    func getAnswer(id: String, completion: @escaping (Result<AnswerResponse, IntegrationBrokerError>) -> ()) throws {
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
    
    func getModelNodeDetails(deviceId: String, nodeName: String, completion: @escaping (Result<ARNodeDetailArrayResponse, IntegrationBrokerError>) -> ()) throws {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        //TODO: Add notes functionality to Engagement Cloud
        // Ensure that the current app is OSvC, otherwise stop.
        guard app == .serviceCloud else {
            #if DEBUG
            os_log(.debug, "Notes are not currently implemented in Engagement Cloud.")
            #endif
            
            throw IntegrationError.invalidServiceApp
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
    
    func getNotes(deviceId: String, nodeName: String, completion: @escaping (Result<NoteArrayResponse, IntegrationBrokerError>) -> ()) throws {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        //TODO: Add notes functionality to Engagement Cloud
        // Ensure that the current app is OSvC, otherwise stop.
        guard app == .serviceCloud else {
            #if DEBUG
            os_log(.debug, "Notes are not currently implemented in Engagement Cloud.")
            #endif
            
            throw IntegrationError.invalidServiceApp
        }
        
        let appPath: ICSEndpoints = .scGetDeviceNodeNotes
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
                guard let parsedResponse = self.jsonDataHandler(decodableType: NoteArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                completion(.success(parsedResponse))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    func createNote(modelNodeId: Int, text: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        //TODO: Add notes functionality to Engagement Cloud
        // Ensure that the current app is OSvC, otherwise stop.
        guard app == .serviceCloud else {
            #if DEBUG
            os_log(.debug, "Notes are not currently implemented in Engagement Cloud.")
            #endif
            
            throw IntegrationError.invalidServiceApp
        }
        
        let appPath: ICSEndpoints = .scCreateDeviceNodeNote
        let formattedEndpoint = String(format: appPath.rawValue, modelNodeId)
        let urlStr = String(format: "https://%@%@", credentials.0, formattedEndpoint)
        
        guard var urlRequest = self.getRestRequestWithAuthHeader(endPoint: urlStr, username: credentials.1, password: credentials.2) else {
            completion(.failure(.requestCreationError))
            return
        }
        
        let encoder = JSONEncoder()
        let request = NoteRequest(text)
        guard let requestBody = try? encoder.encode(request) else {
            os_log(.error, "Could not encode request into JSON.")
            completion(.failure(.jsonParseError))
            return
        }
        
        urlRequest.httpMethod = "PATCH"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = requestBody
        
        self.asyncHttpRequest(session: self.session, request: urlRequest) { result in
            switch result {
            case .success(_):
                completion(.success(true))
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    func deleteNote(modelNodeId: Int, noteId: Int, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws {
        guard let credentials = try? self.getLocalICSCredentials() else { completion(.failure(.requestCreationError)); return }
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        //TODO: Add notes functionality to Engagement Cloud
        // Ensure that the current app is OSvC, otherwise stop.
        guard app == .serviceCloud else {
            #if DEBUG
            os_log(.debug, "Notes are not currently implemented in Engagement Cloud.")
            #endif
            
            throw IntegrationError.invalidServiceApp
        }
        
        let appPath: ICSEndpoints = .scDeleteNote
        let formattedEndpoint = String(format: appPath.rawValue, modelNodeId, noteId)
        let urlStr = String(format: "https://%@%@", credentials.0, formattedEndpoint)
        
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
}
