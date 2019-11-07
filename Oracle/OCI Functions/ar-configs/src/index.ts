/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

 const fdk = require('@fnproject/fdk');

fdk.handle(function (input: any) {
	console.debug("AR Configs Called");
	
	return {
		"service": {
			"application": process.env.application,
			"applicationHostName": process.env.applicationHostName,
			"knowledgeContentHostName": process.env.knowledgeContentHostName,
			"knowledgeSearchHostName": process.env.knowledgeSearchHostName,
			"contactId": parseInt(process.env.contactId!)
		}
	}
});