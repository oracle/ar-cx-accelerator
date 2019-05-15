// 
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/28/18 9:57 AM
// *********************************************************************************************
// File: DataSimulator.swift
// *********************************************************************************************
// 

import Foundation

/**
 This class is used to construct data locally that simulates the return value of API calls made to ICS and other applications that this app integrates with.  This is used for demonstrating the capabilities of the application when network connections are weak or not available.
 */
class DataSimulator {
    
    /**
     Attempts to perform a translation from the name of the Decodable object passed to a JSON file that matches the class name.  This will return the contents of the file decoded into the object passed.  This method should only be used when local data is turned on.
     Data is simulated from JSON files included in this project.  Edit those files if you wish to change the data displayed in the app.
     
     - Parameter object: The object type to perform a GET request for.  The type name should map to a JSON file of the same name in this project.  The contents of that file will be returned as the decoded structure of this object.
     
     - Returns: A Decodable object with data that API calls throughout this application will beleive are real data.
     */
    public static func performGet<T: Decodable>(object: T.Type) -> T? {
        let name = String(describing: T.self)
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            return nil
        }
        
        var response: T?
        
        do {
            let data = try Data(contentsOf: url)
            
            let jsonDecoder = JSONDecoder()
            response = try jsonDecoder.decode(T.self, from: data)
        } catch {
            error.log()
        }
        
        return response
    }
    
    /**
     Generates a SensorMessage projection model with simulated anomalies that exceed the max threshold.
     
     - Parameter dataMin: The value that sets the minimum temperature threshold without anomalies.
     - Parameter dataMax: The value that sets the maximum temperature threshold without anomalies.
     - Parameter recordsToCreate: The number of records to return in the array.
     - Parameter createAnomalies: Indicates whether to create anomalies in the data set.
     
     - Returns: An array of SensorMessage objects.
     */
    public static func createTemperatureProjectionModel(dataMin: Double = 280, dataMax: Double = 400, recordsToCreate: Int = 50, createAnomalies: Bool = false) -> [SensorMessage] {
        var messages: [SensorMessage] = []
        
        var spikePoints: [Int] = []
        
        if createAnomalies {
            repeat {
                let index = arc4random_uniform(60) + 15
                spikePoints.append(Int(index))
            } while spikePoints.count < 4
        }
        
        var index = 0
        repeat {
            var newMessage = DataSimulator.createTemperatureProjection(dataMin: dataMin, dataMax: dataMax, type: .projection)
            
            if spikePoints.contains(index) {
                // convert string to double for addition
                let newVal = newMessage.payload!.data!["Bearing_Temperature"]! + 250
                
                // add back to dictionary as a string
                newMessage.payload!.data!["Bearing_Temperature"] = newVal
            }
            
            messages.append(newMessage)
            
            index = index + 1
        } while (index < recordsToCreate)
        
        return messages
    }
    
    /**
     Generates a single SensorMessage object with psuedo-random temperature data.
     
     - Parameter dataMin: The value that sets the minimum temperature threshold without anomalies.
     - Parameter dataMax: The value that sets the maximum temperature threshold without anomalies.
     - Parameter type: The reliability of the message (historical or projection).
     
     - Returns: A SensorMessage object.
     */
    public static func createTemperatureProjection(dataMin: Double = 280, dataMax: Double = 400, type: SensorMessage.MessageType = .bestEffort) -> SensorMessage {
        let randNum: Double = Double(Double(arc4random_uniform(UInt32(dataMax))) + dataMin)
        
        var message: SensorMessage! = SensorMessage()
        message.payload = SensorMessage.SensorPayload()
        message.payload!.data = [:]
        message.payload!.data!["Bearing_Temperature"] = randNum
        message.payload!.data!["Pump_Noise_Level"]  = 11.54766418190123
        message.payload!.data!["Pump_RPM"]  = 1700
        message.payload!.data!["Pump_Vibration"]  = 1.8669084221976542
        message.reliability = type.rawValue
        message.direction = "N/A"
        
        return message
    }
}
