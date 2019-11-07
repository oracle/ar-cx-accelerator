/* * *******************************************************************************************
 *  This file is part of the Oracle Augmented Reality Accelerator for CX Service 
 *  published by Oracle under the Universal Permissive License (UPL), Version 1.0
 *  Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
 ***********************************************************************************************/

const fdk = require('@fnproject/fdk');
import * as https from "https";
import * as Proxy from "../../typescript/OracleApplicationProxy";
import * as KA from "../../typescript/KnowledgeAdvanced";

fdk.handle(function (input: Proxy.RequestInput) {
	console.debug("KA Proxy Called");

	return new Promise(async (resolve, reject) => {
		const hostname = process.env.hostname;
		const sitename = process.env.sitename;

		const path = input.path;
		const method = input.method;
		let headers = input.headers;
		let payload: String | undefined = undefined;

		if (typeof(input.payload) === "string") {
			const base64Buffer = Buffer.from(input.payload!, "base64");
			payload = base64Buffer.toString("utf8");
		}

		if (typeof (path) !== "string") {
			const error = "KA endpoint not set. Use '/' for root path.";
			console.error(error);
			reject({ "error": error });
		}

		if (typeof (method) !== "string") {
			const error = "Method for KA endpoint not set.";
			console.error(error);
			reject({ "error": error });
		}

		const authTokenResponse = await getAuthToken();

		if (typeof (authTokenResponse.authenticationToken) !== "string") {
			reject({ "error": "Could not obtain auth token." });
		}

		const kmauthtoken = "{\"siteName\":\"" + sitename + "\",\"integrationUserToken\":\"" + authTokenResponse.authenticationToken + "\"}";

		if (typeof (headers) !== "object") {
			headers = {
				"kmauthtoken": kmauthtoken,
				"Content-Type": "application/json",
				"Accept": "application/json",
				"Content-Length": payload !== undefined ? payload!.length : 0
			}
		} else {
			headers["kmauthtoken"] = kmauthtoken;
			headers["Content-Type"] = "application/json";
			headers["Content-Length"] = payload !== undefined ? payload!.length : 0;
			headers["Accept"] = "application/json";
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
			console.log("Request Called");

			res.on("data", (data) => {
				response += data;
			});

			res.on("end", () => {
				response = response.length > 0 ? response : '{}';
				resolve(JSON.parse(response));
			});

			res.on("error", (e) => {
				reject({ "error": JSON.stringify(e) });
			});
		});

		request.on("error", (e) => {
			console.error("Request Error");
			reject({ "error": JSON.stringify(e) });
		});

		request.on("abort", () => {
			console.error("Request Aborted");
			reject({ "error": "Connection Aborted" });
		});

		request.on("finish", () => {
			console.log("Request Finished");
			console.log("Close");
		});

		if ((method.toLowerCase() === "post" || method.toLowerCase() === "patch") && typeof (payload) !== "undefined") {
			request.write(payload);
		}

		request.end();
	});
});

function getAuthToken(): Promise<KA.AuthResponse> {
	return new Promise((resolve, reject) => {
		const hostname = process.env.hostname;
		const sitename = process.env.sitename;
		const username = process.env.username;
		const password = process.env.password;

		if (typeof (hostname) !== "string" || typeof (sitename) !== "string" || typeof (username) !== "string" || typeof (password) !== "string") {
			reject({ "error": "Required configs not set for auth request." });
		}

		let requestOptions: https.RequestOptions = {
			hostname: hostname,
			port: 443,
			path: "/km/api/latest/auth/integration/authorize",
			method: "POST",
			headers: {
				"Accept": "application/json",
				"Content-Type": "application/json"
			}
		};

		const payload: KA.AuthRequest = {
			siteName: sitename!,
			login: username!,
			password: password!
		}
		const payloadStr = JSON.stringify(payload);

		requestOptions!.headers!["Content-Length"] = payloadStr.length;

		let response = '';
		const request = https.request(requestOptions, (res) => {
			res.on("data", (data) => {
				response += data;
			});

			res.on("end", () => {
				response = response.length > 0 ? response : '{}';
				resolve(JSON.parse(response));
			});

			res.on("error", (e) => {
				reject({ "error": JSON.stringify(e) });
			});
		});

		request.on("error", (e) => {
			console.log("Request Error");
			reject({ "error": JSON.stringify(e) });
		});

		request.on("abort", () => {
			console.log("Request Aborted");
			reject({ "error": "Connection Aborted" });
		});

		request.write(payloadStr);
		request.end();
	});
}