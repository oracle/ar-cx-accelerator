//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/20/19 3:42 PM
// *********************************************************************************************
// File: OciBroker.swift
// *********************************************************************************************
// 

import Foundation
import os
import OciRequestSigner

/**
 Class to broker communication with OCI functions for data.
 */
class OciBroker: IntegrationBroker, RemoteIntegrationBroker {
    
    // MARK: - Properties
    
    /**
     Property that holds the singleton instance of this class.
     */
    static let shared = OciBroker()
    
    /**
     The URL session that this class will use to broker HTTP requests.
     */
    let session: URLSession!
    
    /**
     Server configuration object that indicates how to communicate with ICS and other applications.
     */
    private var serverConfigs: ServerConfigs?
    
    /**
     An array that stores the function details returned from OCI.
     */
    private var ociFunctions: [OciFunction]?
    
    /**
     Stores the F(n) application details endpoint so that we can query for the functions withing that application.
     */
    private var applicationInfoEndpoint: String?
    
    /**
     Enum that represents the functions exposed via OCI functions that are used for integration within this application.
    */
    private enum OciFunctions: String, CaseIterable {
        case arConfigs = "ar-configs",
        arDeviceActionMapping = "ar-deviceactionmapping",
        arNodeContexts = "ar-nodecontexts",
        arRecognitionContexts = "ar-recognitioncontexts",
        arRecognitionMapping = "ar-recognitionmapping",
        ecProxy = "ec-proxy",
        iotProxy = "iot-proxy",
        kaProxy = "ka-proxy",
        osvcProxy = "osvc-proxy"
    }
    
    /**
    OciBroker specific errors.
     */
    enum OciBrokerError: Error {
        case applicationUnavailable,
        invokationEndpointUnavailable,
        invalidServiceApp
    }
    
    // MARK: - Init Methods
    
    private init() {
        self.session = URLSession(configuration: .ephemeral)
        
        self.reloadCredentialsFromSettings()
    }
    
    // MARK: - Credentials Methods
    
    /**
     Convenience method to get OCI parameters that are stored in application settings for use in API calls.
     
     - Returns: A tuple containing the OCI app details endpoint, tenancy id, auth user id, public key fingerprint, and private key for integration.
    */
    private func getLocalCredentials() throws -> (String, String, String, String, String)  {
        guard let appEndpoint = UserDefaults.standard.string(forKey: OciFnConfigs.arFnApplicationDetailsEndpoint.rawValue),
            let tenancyId = UserDefaults.standard.string(forKey: OciFnConfigs.tenancyId.rawValue),
            let authUserId = UserDefaults.standard.string(forKey: OciFnConfigs.authUserId.rawValue),
            let publicKeyFingerprint = UserDefaults.standard.string(forKey: OciFnConfigs.publicKeyFingerprint.rawValue),
            let privateKey = UserDefaults.standard.string(forKey: OciFnConfigs.privateKey.rawValue) else {
                throw IntegrationError.invalidServerConfigs
        }
        
        return (appEndpoint, tenancyId, authUserId, publicKeyFingerprint, privateKey)
    }
    
    /// Function to reload the settings cached in this singleton from the values in settings.
    func reloadCredentialsFromSettings() {
        // Get the local configuration details and setup OCI URL Signer
        if let credentials = try? self.getLocalCredentials() {
            self.applicationInfoEndpoint = credentials.0
            
            let signer = OciRequestSigner.shared
            signer.tenancyId = credentials.1
            signer.userId = credentials.2
            signer.thumbprint = credentials.3
            try? signer.setKey(key: credentials.4)
        }
    }
    
    // MARK: - OCI Functions Methods
    
    /**
     Performs an API call to OCI to get all of the functions of a given F(n) project application.
     The AR accelerator uses all of the functions in the "ar-accelerator" app on OCI.
     
     - Parameter completion: A completion callback returning the successful application results or an integration broker error.
     - Parameter result: The result object.
     */
    func getApplicationFunctions(completion: @escaping (_ result: Result<[OciFunction]?, IntegrationBrokerError>) -> ()) {
        guard let applicationInfoEndpoint = self.applicationInfoEndpoint else {
            os_log(.error, "Could not obtain credentials to integrate with OCI.")
            completion(.failure(.requestCreationError))
            return
        }
        
        do {
            let urlStr = String(format: "https://%@", applicationInfoEndpoint)
            
            guard let urlRequest = try OciRequestSigner.shared.getUrlRequest(endPoint: urlStr, timeoutInterval: 15) else {
                os_log(.error, "Could not create url request for application settings.")
                completion(.failure(.requestCreationError))
                return
            }
            
            let signedUrlRequest = try OciRequestSigner.shared.sign(urlRequest)
            
            self.asyncHttpRequest(session: self.session, request: signedUrlRequest) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: OciFunctionsApplicationFunctionsResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    completion(.success(parsedResponse.items))
                    
                    break
                case .failure(let failure):
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    /**
     Returns the invocation endpoint for an OCI function based on the name that is passed.
     
     - Parameter name: The name of the function to get the endpoint for.
     
     - Returns: The string value of the invokation endpoint if the function is found. Otherwise, nil.
     */
    private func getInvokeEndpointByFunctionName(_ name: OciFunctions) -> String? {
        return self.getInvokeEndpointByFunctionName(name.rawValue)
    }
    
    /**
     Returns the invocation endpoint for an OCI function based on the name that is passed.
     
     - Parameter name: The name of the function to get the endpoint for.
     
     - Returns: The string value of the invokation endpoint if the function is found. Otherwise, nil.
     */
    private func getInvokeEndpointByFunctionName(_ name: String) -> String? {
        return self.ociFunctions?.first(where: { $0.name == name} )?.annotations.fnprojectIoFnInvokeEndpoint
    }
    
    // MARK: - RemoteIntegrationBroker Methods
    
    func getServerConfigs(completion: @escaping (Result<ServerConfigs, IntegrationBrokerError>) -> ()) {
        // Get the application functions from OCI before we do anything to ensure that the functions list exists
        self.getApplicationFunctions { (result) in
            switch result {
            case .success(let data):
                guard let funcArr = data else { completion(.failure(.errorReturned(OciBrokerError.applicationUnavailable))); return }
                self.ociFunctions = funcArr
                
                // Now get server configs
                do {
                    guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.arConfigs) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                    guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                    request.httpMethod = "POST"
                    request = try OciRequestSigner.shared.sign(request)
                    
                    self.asyncHttpRequest(session: self.session, request: request) { result in
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
                } catch {
                    error.log()
                    completion(.failure(.errorReturned(error)))
                }
                
                break
            case .failure(let failure):
                failure.log()
                completion(.failure(failure))
                break
            }
        }
    }
    
    func getRecognitionContext(major: Int, minor: Int, completion: @escaping (Result<ARRecognitionContext, IntegrationBrokerError>) -> ()) {
        do {
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.arRecognitionContexts) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            let encoder = JSONEncoder()
            let search = try encoder.encode(OciMajorMinorSearch(major: major, minor: minor))
            
            request.httpBody = search
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: ARRecognitionContextArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    guard let item = parsedResponse.items?.first else { completion(.failure(.noDataReturned)); return }
                    completion(.success(item))
                    
                    break
                case .failure(let failure):
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    func getNodeData(nodeName: String, completion: @escaping (Result<ARNodeContext, IntegrationBrokerError>) -> ()) {
        do {
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.arNodeContexts) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            let encoder = JSONEncoder()
            let search = try encoder.encode(OciNameSearch(name: nodeName))
            
            request.httpBody = search
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: ARNodeContextArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    guard let item = parsedResponse.items?.first else { completion(.failure(.noDataReturned)); return }
                    completion(.success(item))
                    
                    break
                case .failure(let failure):
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    func getUUIDsForRecognizedDevice(major: Int, minor: Int, completion: @escaping (Result<(String, String), IntegrationBrokerError>) -> ()) {
        do {
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.arRecognitionMapping) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            let encoder = JSONEncoder()
            let search = try encoder.encode(OciMajorMinorSearch(major: major, minor: minor))
            
            request.httpBody = search
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: ARRecognitionToDeviceMappingArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    guard let item = parsedResponse.items?.first else { completion(.failure(.noDataReturned)); return }
                    completion(.success((item.applicationId, item.deviceId)))
                    
                    break
                case .failure(let failure):
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    func getDeviceInfo(_ deviceId: String, completion: @escaping (Result<IoTDevice, IntegrationBrokerError>) -> ()) {
        do {
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.iotProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            // Configure request to proxy to IoTCS
            let proxyPath = String(format: "/iot/api/v2/devices/%@", deviceId)
            let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
            
            let encoder = JSONEncoder()
            let search = try encoder.encode(proxyRequest)
            
            request.httpBody = search
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: IoTDevice.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    completion(.success(parsedResponse))
                    
                    break
                case .failure(let failure):
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    func getHistoricalDeviceMessages(_ applicationId: String, _ deviceId: String, completion: @escaping (Result<SensorMessageResponse, IntegrationBrokerError>) -> (), limit: Int) {
        do {
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.iotProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            // Configure request to proxy to IoTCS
            let proxyPath = String(format: "/iot/api/v2/apps/%@/messages?device=%@&limit=%d&sortBy=desc", applicationId, deviceId, limit)
            let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
            
            let encoder = JSONEncoder()
            let search = try encoder.encode(proxyRequest)
            
            request.httpBody = search
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: SensorMessageResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    completion(.success(parsedResponse))
                    
                    break
                case .failure(let failure):
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    func getDeviceArActionMapping(_ applicationId: String, _ deviceId: String, completion: @escaping (Result<ARDeviceActionMapping, IntegrationBrokerError>) -> ()) {
        do {
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.arDeviceActionMapping) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            let actionQuery = OciIoTAppAndDeviceRequest(deviceId: deviceId, applicationId: applicationId)
            
            let encoder = JSONEncoder()
            let search = try encoder.encode(actionQuery)
            
            request.httpBody = search
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: ARDeviceActionMappingArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    guard let item = parsedResponse.items?.first else { completion(.failure(.noDataReturned)); return }
                    completion(.success(item))
                    
                    break
                case .failure(let failure):
                    failure.log()
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    func triggerDeviceIssue(applicationId: String, deviceId: String, request: DeviceEventTriggerRequest, deviceModel: String, action: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) {
        do {
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.iotProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            // Configure request to proxy to IoTCS
            let proxyPath = String(format: "/iot/api/v2/apps/%@/devices/%@/deviceModels/%@/actions/%@", applicationId, deviceId, deviceModel, action)
            let proxyRequest = OciProxyRequest(path: proxyPath, method: "POST")
            
            let encoder = JSONEncoder()
            let search = try encoder.encode(proxyRequest)
            
            request.httpBody = search
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(_):
                    completion(.success(true))
                    
                    break
                case .failure(let failure):
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    func getServiceRequestList(for deviceId: String, and partId: String, completion: @escaping (Result<ServiceRequestArrayResponse, IntegrationBrokerError>) -> ()) {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                guard let encodedQuery = String(format: "customFields.AR.deviceId='%@' AND customFields.AR.partId='%@'", deviceId, partId).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { completion(.failure(.requestCreationError)); return }
                let proxyPath = String(format: "/services/rest/connect/latest/incidents?&q=%@&fields=subject,referenceNumber&orderBy=id:desc", encodedQuery)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
                
                let encoder = JSONEncoder()
                let search = try encoder.encode(proxyRequest)
                
                request.httpBody = search
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(let data):
                        
                        guard let parsedResponse = self.jsonDataHandler(decodableType: IncidentArrayResponse.self, data: data)?.items else { completion(.failure(.noDataReturned)); return }
                        let srs = self.convertIncidentsToArServiceRequests(parsedResponse)
                        let srResponse = ServiceRequestArrayResponse(items: srs)
                        completion(.success(srResponse))
                        
                        break
                    case .failure(let failure):
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func getServiceRequest(_ id: String, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ()) {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                let proxyPath = String(format: "/services/rest/connect/latest/incidents/%@", id)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
                
                let encoder = JSONEncoder()
                let search = try encoder.encode(proxyRequest)
                
                request.httpBody = search
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(let data):
                        
                        guard let parsedResponse = self.jsonDataHandler(decodableType: IncidentResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                        let srs = self.convertIncidentsToArServiceRequests([parsedResponse])
                        guard let srResponse = ServiceRequestArrayResponse(items: srs).items?.first else { completion(.failure(.noDataReturned)); return }
                        completion(.success(srResponse))
                        
                        break
                    case .failure(let failure):
                        failure.log()
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func createServiceRequest(with srRequest: ServiceRequestRequest, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ()) {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            self.createIncidentFromServiceRequest(srRequest) { (result) in
                switch result {
                case .success(let incident):
                    guard let id = incident.id else { completion(.failure(.noDataReturned)); return }
                    
                    var threadFinished = false
                    var attachmentFinished = false
                    let subCallsCompleted: () -> () = {
                        guard threadFinished && attachmentFinished else { return }
                        
                        // Convert the retured incident into a generic SR response object that this app understands.
                        var srResponse = ServiceRequestResponse()
                        srResponse.id = incident.id != nil ? String(incident.id!) : nil
                        srResponse.referenceNumber = incident.referenceNumber
                        srResponse.subject = incident.subject
                        
                        completion(.success(srResponse))
                    }
                    
                    if let image = srRequest.image {
                        let fa = FileAttachment(fileName: "ar_image.png", data: image)
                        
                        self.createIncidentAttachment(incidentId: incident.id!, attachment: fa) { (result) in
                            switch result {
                            case .success(_):
                                break
                            case .failure(let failure):
                                failure.log()
                                break
                            }
                            
                            attachmentFinished = true
                            subCallsCompleted()
                        }
                    }
                    
                    if let note = srRequest.notes {
                        var thread = IncidentThread()
                        thread.entryType = NamedID(id: nil, lookupName: "Note")
                        // Notes are base64 encoded, but Service Cloud accepts plain text. Decode.
                        thread.text = note.base64Decoded
                        
                        self.createIncidentThread(incidentId: id, thread: thread) { (result) in
                            switch result {
                            case .success(_):
                                break
                            case .failure(let failure):
                                failure.log()
                                break
                            }
                            
                            threadFinished = true
                            subCallsCompleted()
                        }
                    }
                    
                    break
                case .failure(let failure):
                    failure.log()
                    completion(.failure(failure))
                    break
                }
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func deleteServiceRequest(srId: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                let proxyPath = String(format: "/services/rest/connect/latest/incidents/%@", srId)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "DELETE")
                
                let encoder = JSONEncoder()
                let encodedPayload = try encoder.encode(proxyRequest)
                
                request.httpBody = encodedPayload
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(_):
                        completion(.success(true))
                        
                        break
                    case .failure(let failure):
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func getAnswers(contentType: String, titleSearch: [String], limit: Int, offset: Int, completion: @escaping (Result<AnswerArrayResponse, IntegrationBrokerError>) -> ()) throws {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.kaProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                guard let query = String(format: "contentType.referenceKey eq '%@' and title likeAny ('*%@*')", contentType, titleSearch.joined(separator: "*','*")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { completion(.failure(.requestCreationError)); return }
                let proxyPath = String(format: "/km/api/latest/content?q=%@&limit=%d&offset=%d", query, limit, offset)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
                
                let encoder = JSONEncoder()
                let encodedPayload = try encoder.encode(proxyRequest)
                
                request.httpBody = encodedPayload
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(let data):
                        guard let parsedResponse = self.jsonDataHandler(decodableType: AnswerArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                        completion(.success(parsedResponse))
                        
                        break
                    case .failure(let failure):
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func getAnswer(id: String, completion: @escaping (Result<AnswerResponse, IntegrationBrokerError>) -> ()) throws {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.kaProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                let proxyPath = String(format: "/km/api/latest/content/%@", id)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
                
                let encoder = JSONEncoder()
                let encodedPayload = try encoder.encode(proxyRequest)
                
                request.httpBody = encodedPayload
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(let data):
                        guard let parsedResponse = self.jsonDataHandler(decodableType: AnswerResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                        completion(.success(parsedResponse))
                        
                        break
                    case .failure(let failure):
                        failure.log()
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func getModelNodeDetails(deviceId: String, nodeName: String, completion: @escaping (Result<ARNodeDetailArrayResponse, IntegrationBrokerError>) -> ()) throws {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                guard let query = String(format: "Node='%@' AND Model.DeviceId='%@'", nodeName, deviceId).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { completion(.failure(.requestCreationError)); return }
                let proxyPath = String(format: "/services/rest/connect/latest/AR.ModelNodes?q=%@", query)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
                
                let encoder = JSONEncoder()
                let encodedPayload = try encoder.encode(proxyRequest)
                
                request.httpBody = encodedPayload
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(let data):
                        guard let parsedResponse = self.jsonDataHandler(decodableType: ARNodeDetailArrayResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                        completion(.success(parsedResponse))
                        
                        break
                    case .failure(let failure):
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func getNotes(deviceId: String, nodeName: String, completion: @escaping (Result<NoteArrayResponse, IntegrationBrokerError>) -> ()) throws {
       guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                guard let query = String(format: "SELECT Notes.id, Notes.text, Notes.createdTime, Notes.createdByAccount.lookupName, Notes.updatedTime, Notes.updatedByAccount.lookupName, Notes.channel.lookupName as channel FROM AR.ModelNodes WHERE Model.DeviceId = '%@' AND Node = '%@' ORDER BY createdTime DESC", deviceId, nodeName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { completion(.failure(.requestCreationError)); return }
                let proxyPath = String(format: "/services/rest/connect/latest/queryResults?query=%@", query)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "GET")
                
                let encoder = JSONEncoder()
                let encodedPayload = try encoder.encode(proxyRequest)
                
                request.httpBody = encodedPayload
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(let data):
                        guard let parsedResponse = self.jsonDataHandler(decodableType: RoqlQueryResultResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                        guard let roqlTable = parsedResponse.items?[0], let rows = roqlTable.rows else { completion(.failure(.noDataReturned)); return }
                        
                        var notes = NoteArrayResponse(items: [])
                        let df = ISO8601DateFormatter()
                        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        for row in rows {
                            guard let id = row[0], let base64Text = row[1], let text = base64Text.base64Decoded else { continue }
                            var note = Note(text)
                            note.id = Int(id)
                            note.createdByAccount = row[3]
                            note.updatedByAccount = row[5]
                            
                            if let ct = row[2] {
                                note.createdTime = df.date(from: ct)
                            }
                            
                            if let ut = row[4] {
                                note.updatedTime = df.date(from: ut)
                            }
                            
                            notes.items!.append(note)
                        }
                        
                        completion(.success(notes))
                        
                        break
                    case .failure(let failure):
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func createNote(modelNodeId: Int, text: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                let encoder = JSONEncoder()
                
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                let proxyPath = String(format: "/services/rest/connect/latest/AR.ModelNodes/%d", modelNodeId)
                var proxyRequest = OciProxyRequest(path: proxyPath, method: "PATCH")
                
                let note = NoteRequest(text)
                
                proxyRequest.payload = try String(data: encoder.encode(note), encoding: .utf8)?.base64Encoded
                
                let encodedPayload = try encoder.encode(proxyRequest)
                
                request.httpBody = encodedPayload
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(_):
                        completion(.success(true))
                        break
                    case .failure(let failure):
                        failure.log()
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    func deleteNote(modelNodeId: Int, noteId: Int, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws {
        guard let app = self.serverConfigs?.service?.application else { completion(.failure(.requestCreationError)); return }
        
        switch app {
        case .serviceCloud:
            do {
                guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
                guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
                request.httpMethod = "POST"
                
                // Configure request to proxy to IoTCS
                let proxyPath = String(format: "/services/rest/connect/latest/AR.ModelNodes/%d/Notes/%d", modelNodeId, noteId)
                let proxyRequest = OciProxyRequest(path: proxyPath, method: "DELETE")
                
                let encoder = JSONEncoder()
                let encodedPayload = try encoder.encode(proxyRequest)
                
                request.httpBody = encodedPayload
                
                request = try OciRequestSigner.shared.sign(request)
                
                self.asyncHttpRequest(session: self.session, request: request) { result in
                    switch result {
                    case .success(_):
                        completion(.success(true))
                        break
                    case .failure(let failure):
                        completion(.failure(failure))
                    }
                }
            } catch {
                error.log()
                completion(.failure(.errorReturned(error)))
            }
            
            break
        case .engagementCloud:
            // TODO: Implement Engagement Cloud code
            completion(.failure(.errorReturned(OciBrokerError.invalidServiceApp)))
            break
        }
    }
    
    // MARK: - Service Cloud and Engagement Cloud Conversation Methods
    
    /**
     Converts a Service Cloud incident array into an array of ServiceRequestResponse records.
     
     - Parameter incidents: An array of incident response objects from Service Cloud.
     
     - Returns: An array of ServiceRequestResponse objects.
     */
    private func convertIncidentsToArServiceRequests(_ incidents: [IncidentResponse]) -> [ServiceRequestResponse] {
        var srs: [ServiceRequestResponse] = []
        
        for incident in incidents {
            var sr = ServiceRequestResponse()
            sr.id = incident.id != nil ? String(incident.id!) : nil
            sr.referenceNumber = incident.lookupName
            sr.subject = incident.subject
            sr.device = ARDevice()
            sr.device!.deviceId = incident.customFields?.ar?.deviceId
            sr.device!.partId = incident.customFields?.ar?.partId
            sr.device!.sensors = incident.customFields?.ar?.sensors
            
            srs.append(sr)
        }
        
        return srs
    }
    
    /**
     Creates a Service Cloud incident based on the local srRequest object.
     
     - Parameter srRequest: The ServiceRequestRequest object created by this application.
     - Parameter completion: A callback when the integration is finished.
     - Parameter result: The result object containing etiher the newly created incident data or an integration broker error.
     */
    private func createIncidentFromServiceRequest(_ srRequest: ServiceRequestRequest, completion: @escaping (_ result: Result<IncidentResponse, IntegrationBrokerError>) -> ()) {
        do {
            let encoder = JSONEncoder()
            
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            // Configure request to proxy to IoTCS
            let proxyPath = String(format: "/services/rest/connect/latest/incidents")
            var proxyRequest = OciProxyRequest(path: proxyPath, method: "POST")
            
            let pcId = srRequest.primaryContact.id ?? 0
            let subject = srRequest.subject ?? "AR Incident"
            var incident = IncidentRequest(primaryContactId: pcId, subject: subject)
            
            let ar = IncidentRequest.CustomFields.AR(deviceId: srRequest.device?.deviceId, partId: srRequest.device?.partId, sensors: srRequest.device?.sensors)
            let cf = IncidentRequest.CustomFields(ar: ar)
            incident.customFields = cf
            
            proxyRequest.payload = try String(data: encoder.encode(incident), encoding: .utf8)?.base64Encoded
            
            let encodedPayload = try encoder.encode(proxyRequest)
            
            request.httpBody = encodedPayload
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(let data):
                    guard let parsedResponse = self.jsonDataHandler(decodableType: IncidentResponse.self, data: data) else { completion(.failure(.noDataReturned)); return }
                    completion(.success(parsedResponse))
                    
                    break
                case .failure(let failure):
                    failure.log()
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    /**
     Creates an attachment for a Service Cloud incident.
     
     - Parameter incidentId: The ID of the incident to attach to.
     - Parameter attachment: The attachment data.
     - Parameter completion: A callback when the integration is finished.
     - Parameter result: The result object containing etiher true for success or an integration broker error.
     */
    private func createIncidentAttachment(incidentId: Int, attachment: FileAttachment, completion: @escaping (_ result: Result<Bool, IntegrationBrokerError>) -> ()) {
        do {
            let encoder = JSONEncoder()
            
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            // Configure request to proxy to IoTCS
            let proxyPath = String(format: "/services/rest/connect/latest/incidents/%d/fileAttachments", incidentId)
            var proxyRequest = OciProxyRequest(path: proxyPath, method: "PATCH")
            
            proxyRequest.payload = try String(data: encoder.encode(attachment), encoding: .utf8)?.base64Encoded
            
            let encodedPayload = try encoder.encode(proxyRequest)
            
            request.httpBody = encodedPayload
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(_):
                    completion(.success(true))
                    
                    break
                case .failure(let failure):
                    failure.log()
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
    
    /**
     Creates an attachment for a Service Cloud incident.
     
     - Parameter incidentId: The ID of the incident to attach to.
     - Parameter thread: The text to add as an incident thread.
     - Parameter completion: A callback when the integration is finished.
     - Parameter result: The result object containing etiher true for success or an integration broker error.
     */
    private func createIncidentThread(incidentId: Int, thread: IncidentThread, completion: @escaping (_ result: Result<Bool, IntegrationBrokerError>) -> ()) {
        do {
            guard thread.text != nil, thread.text!.count > 0 else { completion(.success(true)); return }
            
            let encoder = JSONEncoder()
            
            guard let invokationEndpoint = self.getInvokeEndpointByFunctionName(.osvcProxy) else { completion(.failure(.errorReturned(OciBrokerError.invokationEndpointUnavailable))); return }
            guard var request = try OciRequestSigner.shared.getUrlRequest(endPoint: invokationEndpoint) else { completion(.failure(.requestCreationError)); return }
            request.httpMethod = "POST"
            
            // Configure request to proxy to IoTCS
            let proxyPath = String(format: "/services/rest/connect/latest/incidents/%d/threads", incidentId)
            var proxyRequest = OciProxyRequest(path: proxyPath, method: "PATCH")
            
            proxyRequest.payload = try String(data: encoder.encode(thread), encoding: .utf8)?.base64Encoded
            
            let encodedPayload = try encoder.encode(proxyRequest)
            
            request.httpBody = encodedPayload
            
            request = try OciRequestSigner.shared.sign(request)
            
            self.asyncHttpRequest(session: self.session, request: request) { result in
                switch result {
                case .success(_):
                    completion(.success(true))
                    
                    break
                case .failure(let failure):
                    failure.log()
                    completion(.failure(failure))
                }
            }
        } catch {
            error.log()
            completion(.failure(.errorReturned(error)))
        }
    }
}
