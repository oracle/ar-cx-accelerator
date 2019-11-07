/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

export as namespace KnowledgeAdvanced;

export interface AuthRequest {
    siteName: string;
    login: string;
    password: string;
}

export interface AuthResponse {
    authenticationToken: string;
}