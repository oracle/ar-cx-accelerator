import * as ARRecognitionContext from "../../typescript/ARRecognitionContext";
const fdk = require('@fnproject/fdk');

fdk.handle(function (input: any) {
	console.debug("AR Recognition Contexts Called");

	return new Promise((resolve, reject) => {
		getContexts()
		.then(contexts => {
			if (typeof(input.name) === "string" && input.name.length > 0) {
				let item = contexts.items.filter(item => item.name === input.name);
				resolve({ "items": item });
				return
			}
			else if (typeof(input.major) === "number" && typeof(input.minor) === "number") {
				let item = contexts.items.filter(item => item.major === input.major && item.minor.includes(input.minor));
				resolve({ "items": item });
				return
			}

			console.warn("Could not map either a recognition name or major/minor pair during recognition.");
		
			resolve({});
		})
		.catch(error => {
			console.error(JSON.stringify(error));
			reject(error);
		});
	});
});

const getContexts = function(): Promise<ARRecognitionContext.ARRecognitionContextResponse> {
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
// "{\"items\":[{\"name\":\"blue-pump_recognition\",\"major\":1,\"minor\":[1],\"actionAnimations\":[{\"name\":\"fadeIn\",\"duration\":0.25,\"nodes\":[\"pump\",\"assembly\",\"Long_Rod\",\"Rod_Nut\",\"Washer\",\"Fly_Wheel\",\"Rod_Enclosure\",\"Small_Rod\"]},{\"name\":\"moveZ\",\"value\":0.2,\"duration\":0.25,\"nodes\":[\"assembly\"]}]},{\"name\":\"red-pump_recognition\",\"major\":2,\"minor\":[1],\"actionAnimations\":[{\"name\":\"fadeIn\",\"duration\":0.25,\"nodes\":[\"red-pump\"]},{\"name\":\"moveZ\",\"value\":0.1,\"duration\":0.5,\"nodes\":[\"Front\"]},{\"name\":\"moveX\",\"value\":-0.25,\"duration\":0.5,\"nodes\":[\"Front\"]},{\"name\":\"fadeOut\",\"duration\":0.25,\"nodes\":[\"Front\"]},{\"name\":\"moveZ\",\"value\":0.2,\"duration\":0.5,\"nodes\":[\"Cogs\",\"Washers\"]}]}]}"