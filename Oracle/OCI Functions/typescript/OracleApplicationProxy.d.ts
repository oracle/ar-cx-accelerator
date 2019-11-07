/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

export as namespace OracleApplicationProxy;

export interface RequestInput {
    hostname: string;
    method: string;
    path: string;
    headers?: any;
    payload?: String;
}