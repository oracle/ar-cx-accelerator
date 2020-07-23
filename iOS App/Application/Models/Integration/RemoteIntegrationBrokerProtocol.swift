//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 7/15/19 3:39 PM
// *********************************************************************************************
// File: RemoteIntegrationBrokerProtocol.swift
// *********************************************************************************************
// 

import Foundation

/**
 Protocol that defines a set of reusable methods with consistant API calls regardless of the back end.
 This is primarily used to switch between back-ends for testing such as ICS, AWS, Azure, MCS, or any other back-end that
 is implemented as an integration broker.
 */
protocol RemoteIntegrationBroker {
    /**
     Get the AR Configuration object that is served by ICS via remote endpoint.
     
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getServerConfigs(completion: @escaping (Result<ServerConfigs, IntegrationBrokerError>) -> ())
    
    /**
     Queries for the device metadata for the recognized image/object.
     
     - Parameter major: The major integer of the identified device. This int corresponds to a model number.
     - Parameter minor: The minor integer of the identified device. This int corresponds to a device SKU.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getRecognitionContext(major: Int, minor: Int, completion: @escaping (Result<ARRecognitionContext, IntegrationBrokerError>) -> ())
    
    /**
     Queries for the IoT CS Device ID from the recognized major/minor values supplied from the recognized object or beacon.
     
     - Parameter major: The major integer of the identified device. This int corresponds to a model number.
     - Parameter minor: The minor integer of the identified device. This int corresponds to a device SKU.
     - Parameter completion: Callback method once the HTTP request completes.  Returns a tuple containing the application id and the device id of the recognized item.
     */
    func getUUIDsForRecognizedDevice(major: Int, minor: Int, completion: @escaping (Result<(String, String), IntegrationBrokerError>) -> ())
    
    /**
     Performs call to query for the AR metadata for the selected node.
     
     - Parameter nodeName: The node to retrieve procedure data for.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getNodeData(nodeName: String, completion: @escaping (Result<ARNodeContext, IntegrationBrokerError>) -> ())
    
    /**
     Performs call to get the IoT device information
     
     - Parameter deviceId: The ID for the device queried for.
     - Parameter completion: Callback method once the HTTP request completes
     */
    func getDeviceInfo(_ deviceId: String, completion: @escaping (Result<IoTDevice, IntegrationBrokerError>) -> ())
    
    /**
     Performs call to get the IoT device messages.
     
     - Parameter applicationId: The application ID that contains the device to get messages for.
     - Parameter deviceId: The device ID to retrieve messages for.
     - Parameter completion: Callback method once the HTTP request completes.
     - Parameter limit: A query limit applied to the number of devices retrieved.
     */
    func getHistoricalDeviceMessages(_ applicationId: String, _ deviceId: String, completion: @escaping (Result<SensorMessageResponse, IntegrationBrokerError>) -> (), limit: Int)
    
    /**
     Gets any mapping between AR application actions and IoTCS actions for this device. This is primarily used to call an IoTCS event after procedures.
     
     - Parameter applicationId: The application id for the device.
     - Parameter deviceId: The id of the device to query for.
     - Parameter completion: Callback method once the HTTP request completes
     */
    func getDeviceArActionMapping(_ applicationId: String, _ deviceId: String, completion: @escaping (Result<ARDeviceActionMapping, IntegrationBrokerError>) -> ())
    
    /**
     Performs call to trigger the filter clogged event or remove it.
     
     - Parameter applicationId: The IoTCS application ID that the device exists under.
     - Parameter deviceId: The device ID to retrieve messages for.
     - Parameter request: Request data to pass to IntegrationBroker.
     - Parameter deviceModel: The URN of the device supplied by IoTCS Apps with colons converted to periods.
     - Parameter action: The action to trigger in IoTCS.
     - Parameter completion: Callback method once the HTTP request completes.
     - Parameter result: The result of the HTTP request.
     */
    func triggerDeviceIssue(applicationId: String, deviceId: String, request: DeviceEventTriggerRequest, deviceModel: String, action: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ())
    
    /**
     Performs call to ICS to get the IoT device's service request list from the configured service application.  This call only has limited information and inteded for list views.
     
     - Parameter deviceId: The device ID used for the service request.
     - Parameter partId: The part ID used for the service request.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getServiceRequestList(for deviceId: String, and partId: String, completion: @escaping (Result<ServiceRequestArrayResponse, IntegrationBrokerError>) -> ())
    
    /**
     Performs call to ICS to get a specific service request from the configured service application.
     
     - Parameter id: The ID of the service request to retrieve.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func getServiceRequest(_ id: String, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ())
    
    /**
     Performs call to create a service request.
     
     - Parameter request: The ServiceRequest request object.
     - Parameter completion: Callback method once the HTTP request completes.
     */
    func createServiceRequest(with srRequest: ServiceRequestRequest, completion: @escaping (Result<ServiceRequestResponse, IntegrationBrokerError>) -> ())
    
    /**
     Performs call to delete a service request.
     
     - Parameter srId: The SR to delete.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: IntegrationError.invalidServiceApp when Service Cloud is not used because only Service Cloud serves notes currently.
     */
    func deleteServiceRequest(srId: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws
    
    /**
     Performs call to ICS to query for answers.
     
     - Parameter contentType: The Engagement Cloud answer content type used in the search filter
     - Parameter titleSearch: An array of titles that can be matched in the KB search.
     - Parameter limit: Record query limit
     - Parameter offset: Record query offset
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: `IntegrationError.invalidServiceApp` if an incorrect service app setting is used.
     */
    func getAnswers(contentType: String, titleSearch: [String], limit: Int, offset: Int, completion: @escaping (Result<AnswerArrayResponse, IntegrationBrokerError>) -> ()) throws
    
    /**
     Performs call to ICS to query for a specific answer.
     
     - Parameter id: The recordId of the answer to query for.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: `IntegrationError.invalidServiceApp` if Service Cloud is used and a knowledge call is made.  Engagement Cloud is used for knowledge.
     */
    func getAnswer(id: String, completion: @escaping (Result<AnswerResponse, IntegrationBrokerError>) -> ()) throws
    
    /**
     Performs call to query for the modelnode record details.  This is required to submit notes for a specific node in other API calls.
     
     - Parameter deviceId: Of the device in the AR experience.
     - Parameter nodeName: The node to retrieve notes data for.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: IntegrationError.invalidServiceApp when Service Cloud is not used because only Service Cloud serves notes currently.
     */
    func getModelNodeDetails(deviceId: String, nodeName: String, completion: @escaping (Result<ARNodeDetailArrayResponse, IntegrationBrokerError>) -> ()) throws
    
    /**
     Performs call to query for notes assigned to this device and node.  This method looks up the node ID first before querying for notes.
     
     - Parameter deviceId: Of the device in the AR experience.
     - Parameter nodeName: The node to retrieve notes data for.
     - Parameter completion: Callback method once the HTTP request completes.
     - Parameter object: The results of the decode process.
     - Parameter urlResponse: The URL response from the request.
     - Parameter error: The error from the request.
     
     - throws: IntegrationError.invalidServiceApp when Service Cloud is not used because only Service Cloud serves notes currently.
     */
    func getNotes(deviceId: String, nodeName: String, completion: @escaping (Result<NoteArrayResponse, IntegrationBrokerError>) -> ()) throws
    
    /**
     Performs call to ICS to create a note assigned to this device and node.
     
     - Parameter modelNodeId: Model node ID to post the note to.
     - Parameter text: The note text.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: IntegrationError.invalidServiceApp when Service Cloud is not used because only Service Cloud serves notes currently.
     */
    func createNote(modelNodeId: Int, text: String, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws
    
    /**
     Performs call to ICS to delete a note assigned to this device and node.
     
     - Parameter modelNodeId: Model node ID to post the note to.
     - Parameter noteId: The note ID.
     - Parameter completion: Callback method once the HTTP request completes.
     
     - throws: IntegrationError.invalidServiceApp when Service Cloud is not used because only Service Cloud serves notes currently.
     */
    func deleteNote(modelNodeId: Int, noteId: Int, completion: @escaping (Result<Bool, IntegrationBrokerError>) -> ()) throws
}
