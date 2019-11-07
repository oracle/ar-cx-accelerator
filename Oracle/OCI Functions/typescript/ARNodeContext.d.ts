export as namespace ARNodeContext;

export interface NodeContextResponse {
    items: Item[];
}

export interface Item {
    name: string;
    description?: string;
    tableSections?: TableSection[];
    sensors?: Sensor[];
    procedures?: Procedure[];
    showSensorChart?: boolean;
    subNodes?: SubNode[];
}

export interface SubNode {
    name: string;
    specifications: Specification[];
}

export interface Specification {
    name: string;
    value: string;
}

export interface Procedure {
    name: string;
    description?: string;
    image?: Image;
    steps?: Step[];
    interactionNodes?: string[];
}

export interface Step {
    title: string;
    text?: string;
    image?: Image;
    animations?: Animation[];
    highlightNode?: string;
    details?: string;
    confirmationMessage?: string;
}

export interface Animation {
    name: string;
    duration?: number;
    value?: number;
    nodes?: string[];
    attributes?: Attribute[];
}

export interface Attribute {
    name: string;
    sceneFrame?: SceneFrame;
    scene?: string;
    node?: string;
    image?: Image;
    eulerAngles?: Position;
    position?: Position;
    scale?: Position;
}

export interface Sensor {
    name: string;
    background: Background;
    label: Label;
    sceneFrame: SceneFrame;
    action: Action;
    position: Position;
    sensorPlane: SceneFrame;
    scale: Position;
    eulerAngles: Position;
    alwaysFaceViewPort: boolean;
    operatingLimits: OperatingLimits;
}

export interface OperatingLimits {
    min: number;
    max: number;
}

export interface Action {
    type: string;
}

export interface SceneFrame {
    width: number;
    height: number;
}

export interface Label {
    text: string;
    font: Font;
    position: Position;
    rotation: number;
    formatter: string;
}

export interface Position {
    x?: number;
    y?: number;
    z?: number;
}

export interface Font {
    name: string;
    size: number;
    color: Color;
}

export interface Color {
    red: number;
    blue: number;
    green: number;
    alpha: number;
}

export interface Background {
    type: string;
    image: Image;
}

export interface Image {
    data?: string;
    url?: string;
    name?: string;
}

export interface TableSection {
    name: string;
    rows: Row[];
}

export interface Row {
    title: string;
    subtitle: string;
}