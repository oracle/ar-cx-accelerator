//
// *********************************************************************************************
// This file is part of the Augmented CX accelerator published by Oracle Corporation under
// the Universal Permissive License (UPL), Version 1.0
// Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 1/21/19 10:30 AM
// *********************************************************************************************
// File: Prediction.swift
// *********************************************************************************************
// 

import Foundation

#warning("PROD_DEVDEMO_ONLY: Delete this file for branches other than prod_dev_demo.")

struct Prediction: Decodable {
    var details: Details?
    var predictedLabel: String?
    var predictedScores: [String:Double]?
    
    struct Details: Decodable {
        var algorithm: String?
        var predictiveModelType: String?
        
        /**
         Coding keys for JSON deconstruction.
         */
        enum CodingKeys: String, CodingKey {
            case algorithm = "Algorithm",
            predictiveModelType = "PredictiveModelType"
        }
    }
}

struct PredictionResponse: Decodable {
    var prediction: Prediction?
    
    /**
     Coding keys for JSON deconstruction.
     */
    enum CodingKeys: String, CodingKey {
        case prediction = "Prediction"
    }
}

struct PredictionRequest: Encodable {
    var mlModelId: String
    var record: [String: String]
    var predictEndpoint: String
    
    /**
     Coding keys for JSON deconstruction.
     */
    enum CodingKeys: String, CodingKey {
        case mlModelId = "MLModelId",
        record = "Record",
        predictEndpoint = "PredictEndpoint"
    }
}
