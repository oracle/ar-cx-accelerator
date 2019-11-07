//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 9/25/19 11:06 AM
// *********************************************************************************************
// File: OCIBrokerTests.swift
// *********************************************************************************************
// 

import XCTest
import os
import OciRequestSigner
@testable import Augmented_CX

class OCIBrokerTests: XCTestCase {
    
    private(set) var bundle: Bundle!
    #warning("Set these OCI values to properly run test cases.")
    let functionsHost = ""
    let tenancyOCID = ""
    let userOCID = ""
    let certFingerprint = ""

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        bundle = Bundle(for: type(of: self))
        
        let signer = OciRequestSigner.shared
        signer.tenancyId = self.tenancyOCID
        signer.userId = self.userOCID
        signer.thumbprint = self.certFingerprint
        
        do {
            try signer.setKey(fileName: "oci", fileExtention: "pem", bundle: bundle)
        } catch {
            os_log(.error, "%@", error.localizedDescription)
            XCTFail()
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGetApplicationDetails() {
        let expectation = XCTestExpectation(description: "Download server configs")
        
        OciBroker.shared.getApplicationFunctions { (result) in
            switch result {
            case .success(let data):
                XCTAssertNotNil(data, "No data was downloaded.")
                
                break
            case .failure(_):
                XCTFail()
                break
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }

    func testGetServerConfigs() {
        let expectation = XCTestExpectation(description: "Download server configs")
        
        OciBroker.shared.getServerConfigs { (result) in
            switch result {
            case .success(let data):
                XCTAssertNotNil(data, "No data was downloaded.")
                
                guard let serviceApp = data.service?.application else { XCTFail(); return}
                XCTAssert((serviceApp == .serviceCloud || serviceApp == .engagementCloud), "Service app is not set.")
                
                break
            case .failure(_):
                XCTFail()
                break
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }

}
