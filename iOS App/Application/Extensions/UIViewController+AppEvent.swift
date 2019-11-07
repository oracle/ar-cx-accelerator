//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 4/2/19 1:11 PM
// *********************************************************************************************
// File: UIViewController+AppEvent.swift
// *********************************************************************************************
// 

import UIKit

extension UIViewController {
    /**
     Create a log event that the view controller has diplayed its view.
    */
    func logViewAppeared() {
        DispatchQueue.main.async {
            let className = String(describing: type(of: self))
            let eventName = String(format: "%@ Visible", className)
            
            guard let event = try? AppEventRecorder.shared.getEvent(name: eventName) else { return }
            event.eventStart = Date()
            event.uiElement = className
            AppEventRecorder.shared.record(event: event, completion: nil)
        }
    }
    
    /**
     Create a log event that the view controller has removed its view.
     */
    func logViewDisappeared() {
        DispatchQueue.main.async {
            let className = String(describing: type(of: self))
            let eventName = String(format: "%@ Visible", className)
            
            guard let event = try? AppEventRecorder.shared.getEvent(name: eventName) else { return }
            event.eventEnd = Date()
            event.readyToSend = true
            
            AppEventRecorder.shared.record(event: event, completion: nil)
        }
    }
}
