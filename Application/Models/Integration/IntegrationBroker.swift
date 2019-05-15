//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 3/13/19 9:17 PM
// *********************************************************************************************
// File: IntegrationBroker.swift
// *********************************************************************************************
// 

import Foundation
import os

/**
 Type alias that can be inherited for all generic integraiton requests that should return data.
 */
typealias IntegrationCompletion = (Result<Data, IntegrationBrokerError>) -> ()

/**
 Enum that defines errors globally for all integration brokers.
 */
enum IntegrationBrokerError: Error {
    case errorReturned(_ error: Error),
    invalidHttpResponse,
    invalidHttpStatus(_ statusCode: Int),
    jsonParseError,
    noDataReturned,
    requestCreationError
}

/**
 Defines prototype functions that all integration brokers should implement.
 */
protocol IntegrationBroker {
    /**
     Performs an asynchronous HTTP request based on the URLRequest object provided.
     
     - Parameter session: The URLSession to submit the request with.
     - Parameter request: The URL request to perform in the background.
     - Parameter completion: A callback called when this method is finished performing work.
     - Parameter data: Any data returned from the request.
     - Parameter response: The response from the server.
     - Parameter error: Any error generated during the request.
    */
    func asyncHttpRequest(session: URLSession, request: URLRequest, completion: @escaping IntegrationCompletion)
    
    /**
     Creates a URLRequest object using base64 / basic auth.
     
     - Parameter endPoint: The URL endpoint to hit in the request.
     - Parameter username: The username to provide for authentication.
     - Parameter password: The password to provide for authentication.
     - Parameter timeoutInterval: The timeout interval assigned to the request.
     
     - Returns: A URLRequest object if successful or nil.
    */
    func getRestRequestWithAuthHeader(endPoint: String, username: String, password: String, timeoutInterval: Double) -> URLRequest?
    
    /**
     Method to decode JSON into the encodable struct class type provided.
     
     - Parameter decodableType: The object type to attempt to decode JSON into.
     - Parameter data: The data to decode.
     
     - Returns: The encodable type that was passed with data populated from the API response.
    */
    func jsonDataHandler <T: Decodable>(decodableType: T.Type, data: Data?) -> T?
}

/**
 Basic implementation of IntegrationBroker methods
 */
extension IntegrationBroker {
    
    func asyncHttpRequest(session: URLSession, request: URLRequest, completion: @escaping IntegrationCompletion) {
        #if DEBUGNETWORK
        os_log(request.url ?? "No URL in HTTP request")
        #endif
        
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                os_log("Data not returned from URL request")
                completion(.failure(.noDataReturned))
                return
            }
            guard error == nil else {
                error?.log()
                completion(.failure(.errorReturned(error!)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                os_log("URL response not returned as HTTP response")
                completion(.failure(.invalidHttpResponse))
                return
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                os_log("HTTP Response Code: %d\nFor URL: %@", httpResponse.statusCode, request.url?.absoluteString ?? "No URL")
                completion(.failure(.invalidHttpStatus(httpResponse.statusCode)))
                return
            }
            
            completion(.success(data))
        }
        
        task.resume()
    }
    
    func getRestRequestWithAuthHeader(endPoint: String, username: String, password: String, timeoutInterval: Double = 60) -> URLRequest? {
        guard let endPoint = endPoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            else {
                return nil
        }
        
        if let connectRootUrl = URL(string: endPoint) {
            var urlRequest = URLRequest(url: connectRootUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeoutInterval)
            let authHeaderStr = String(format: "%@:%@", username, password)
            guard let authHeaderVal = authHeaderStr.base64Encoded else { return nil }
            
            urlRequest.setValue("Basic " + authHeaderVal, forHTTPHeaderField: "Authorization")
            
            return urlRequest
        }
        
        return nil
    }
    
    func jsonDataHandler <T: Decodable>(decodableType: T.Type, data: Data?) -> T? {        
        guard let data = data else {
            #if DEBUG
            os_log("No data returned with the request.")
            #endif
            
            return nil
        }
        
        #if DEBUGNETWORK
        if let json = String(data: data, encoding: .utf8) {
            os_log(json)
        }
        #endif
        
        let objectStr = String(describing: T.self)
        let jsonDecoder = JSONDecoder()
        
        do {
            let object = try jsonDecoder.decode(T.self, from: data)
            
            #if DEBUGNETWORK
            os_log("Get \(objectStr) Successful:\n%@", String(data: data, encoding: .utf8) ?? "")
            #endif
            
            return object
        } catch {
            error.log()
        }
        
        return nil
    }
}
