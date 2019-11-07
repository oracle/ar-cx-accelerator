/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

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