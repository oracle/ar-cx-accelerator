/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

export as namespace ARDeviceActionMapping;

export interface ARDeviceActionMappingResponse {
    items: DeviceActionMapping[];
}

export interface DeviceActionMapping {
    deviceId: string;
    applicationId: string;
    arAppEvent: string;
    iotTriggerName: string;
}