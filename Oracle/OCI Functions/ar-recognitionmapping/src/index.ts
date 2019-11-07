/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

import * as ARRecognitionMapping from "../../typescript/ARRecognitionMapping";
import { resolve } from "url";
const fdk = require('@fnproject/fdk');

fdk.handle(function (input: any) {
	console.debug("AR Recognition Mapping Called");

	return new Promise(async (resolve, reject) => {
		getMappings()
		.then(mappings => {
			if (mappings.items !== undefined && typeof(input.major) === "number" && typeof(input.minor) === "number" ) {
				let item = mappings.items.filter(item => item.major === input.major && item.minor === input.minor);
				resolve({ "items": item });
				return
			}

			console.warn("Could not map any items with the provided major/minor pair.");

			resolve({});
		})
		.catch(error => {
			console.error(JSON.stringify(error));
			reject(error);
		});
	});
});

const getMappings = function(): Promise<ARRecognitionMapping.ARRecognitionMappingResponse> {
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

// Mappings:
// "{\"items\":[{\"major\":1,\"minor\":1,\"deviceId\":\"B47C0F65-F1D7-4642-9694-E00B9500C63D\",\"applicationId\":\"0-AB\"},{\"major\":2,\"minor\":1,\"deviceId\":\"B47C0F65-F1D7-4642-9694-E00B9500C63D\",\"applicationId\":\"0-AB\"},{\"major\":3,\"minor\":1,\"deviceId\":\"DA99E3EB-3743-437C-94F4-DEB77C91723F\",\"applicationId\":\"0-AB\"},{\"major\":3,\"minor\":2,\"deviceId\":\"DA99E3EB-3743-437C-94F4-DEB77C91723F\",\"applicationId\":\"0-AB\"},{\"major\":4,\"minor\":1,\"deviceId\":\"N/A\",\"applicationId\":\"N/A\"},{\"major\":5,\"minor\":1,\"deviceId\":\"D2C22D16-A77F-4B56-A1DF-B44771F4A0E1\",\"applicationId\":\"0-AB\"},{\"major\":6,\"minor\":1,\"deviceId\":\"744BC778-F2E4-4626-9FD6-086714E77BE1\",\"applicationId\":\"0-AB\"}]}"