export as namespace ARRecognitionContext;

export interface ARRecognitionContextResponse {
    items: Item[];
}

export interface Item {
    name: string;
    major: number;
    minor: number[];
    actionAnimations?: ActionAnimation[];
}

export interface ActionAnimation {
    name: string;
    duration: number;
    nodes: string[];
    value?: number;
}