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