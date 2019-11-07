export as namespace ARRecognitionMapping;

export interface ARRecognitionMappingResponse {
  items: Item[];
}

export interface Item {
  major: number;
  minor: number;
  deviceId: string;
  applicationId: string;
}