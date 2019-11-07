//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/23/19 8:17 PM
// *********************************************************************************************
// File: RoqlQuery.swift
// *********************************************************************************************
// 

import Foundation

struct RoqlQueryResult: Decodable {
    let tableName: String
    let count: Int
    let columnNames: [String]?
    let rows: [[String?]]?
}

struct RoqlQueryResultResponse: Decodable {
    let items: [RoqlQueryResult]?
}
