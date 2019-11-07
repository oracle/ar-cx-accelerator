//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 4/19/19 8:56 AM
// *********************************************************************************************
// File: UIBarButtonItem+AppEvent.swift
// *********************************************************************************************
// 

import UIKit

extension UIBarButtonItem {
    func logClick() {
        DispatchQueue.main.async {
            AppEventRecorder.shared.record(name: "Clicked", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: self.title, arAnchor: nil, arNode: nil, jsonString: nil, completion: nil)
        }
    }
}
