/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

import * as Mapping from "../../typescript/ARDeviceActionMapping";
const fdk = require('@fnproject/fdk');

fdk.handle(function (input: any) {
	console.debug("AR Device Mapping Called");

	return new Promise((resolve, reject) => {
		getMappings()
		.then(mapping => {
			if (typeof (input.deviceId) === "string" && typeof (input.applicationId) === "string") {
				let item = mapping.items.filter(item => item.deviceId === input.deviceId && item.applicationId === input.applicationId);
				resolve({ "items": item });
				return
			}

			console.warn("Did not find mapping for device '" + input.deviceId + "' with app id '" + input.applicationId + "'");

			resolve({});
		})
		.catch(error => {
			console.error(JSON.stringify(error));
			reject(error);
		});
	});
});

const getMappings = function (): Promise<Mapping.ARDeviceActionMappingResponse> {
	return new Promise((resolve, reject) => {
		const mappingStr = process.env.mapping;

		if (mappingStr !== undefined) {
			const mapping = JSON.parse(mappingStr);

			if (mapping !== undefined) {
				resolve(mapping);
				return
			}
		}

		reject("Could not get mapping data from configs.");
	});
}

// Mapping Str
//"{\"items\":[{\"deviceId\":\"6F29841B-9159-46A6-AAD1-EBEF0D89CFA5\",\"applicationId\":\"EB33B7E7-6A02-40B5-ACE2-31645180F89B\",\"arAppEvent\":\"procedureEnd\",\"iotTriggerName\":\"resetFilter\"}]}"