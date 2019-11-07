/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

const fdk = require('@fnproject/fdk');
import * as https from "https";
import * as Proxy from "../../typescript/OracleApplicationProxy";

fdk.handle(function (input: Proxy.RequestInput) {
	console.debug("IoT Proxy Called");

	return new Promise((resolve, reject) => {
		const hostname = process.env.hostname;
		const username = process.env.username;
		const password = process.env.password;
		
		const path = input.path;
		const method = input.method;
		let headers = input.headers;
		let payload: String | undefined = undefined;

		if (typeof(input.payload) === "string") {
			const base64Buffer = Buffer.from(input.payload!, "base64");
			payload = base64Buffer.toString("utf8");
		}
		
		if (typeof (path) !== "string") {
			const error = "IoT endpoint not set. Use '/' for root path.";
			console.error(error);
			reject({ "error": error });
		}

		if (typeof (method) !== "string") {
			const error = "Method for IoT endpoint not set.";
			console.error(error);
			reject({ "error": error });
		}

		const authHeaderBuffer = Buffer.from(username + ":" + password);
		const authHeader = authHeaderBuffer.toString('base64');

		if (typeof (headers) !== "object") {
			headers = {
				"Authorization": "Basic " + authHeader,
				"Content-Type": "application/json",
				"Content-Length": payload !== undefined ? payload!.length : 0
			}
		} else {
			headers["Authorization"] = "Basic " + authHeader;
			headers["Content-Length"] = payload !== undefined ? payload!.length : 0;

			if (typeof (headers["Content-Type"]) !== "string") {
				headers["Content-Type"] = "application/json";
			}
		}

		const requestOptions: https.RequestOptions = {
			hostname: hostname,
			port: 443,
			path: path,
			method: method,
			headers: headers
		};

		let response = '';
		const request = https.request(requestOptions, (res) => {
			res.on("data", (data) => {
				response += data;
			});
			
			res.on("end", () => {
				resolve(JSON.parse(response));
			});

			res.on("error", (e) => {
				reject({ "error": JSON.stringify(e) });
			});
		});

		request.on("error", (e) => {
			console.error("Request Error");
			reject({ "error": e.message });
		});

		request.on("abort", () => {
			console.error("Request Aborted");
			reject({ "error": "Connection Aborted" });
		});

		if ((method.toLowerCase() === "post" || method.toLowerCase() === "patch") && typeof (payload) !== "undefined") {
			request.write(payload);
		}

		request.end();
	});
});