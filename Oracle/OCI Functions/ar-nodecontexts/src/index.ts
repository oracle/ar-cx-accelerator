/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

import fs = require("fs");
import * as NodeContext from "../../typescript/ARNodeContext";
const fdk = require('@fnproject/fdk');

fdk.handle(function (input: any) {
	console.debug("AR Node Contexts Called");
	
	return new Promise((resolve, reject) => {
		getContexts()
		.then(contexts => {
			if (typeof(input.name) === "string" && input.name.length > 0) {
				let item = contexts.items.filter(item => item.name === input.name);
				resolve({ "items": item });
				return
			}
			
			console.warn("Did not find item with name '" + input.name + "'");
			
			resolve({});
		})
		.catch(error => {
			console.error(JSON.stringify(error));
			reject(error);
		});
	});
});

const getContexts = function(): Promise<NodeContext.NodeContextResponse> {
	return new Promise(async (resolve, reject) => {
		fs.readFile("./src/node_contexts.json", "utf8", (error, data) => {
			if(error !== null) {
				reject(error);
				return
			}

			const json = JSON.parse(data);
			resolve(json);
		});
	});
}