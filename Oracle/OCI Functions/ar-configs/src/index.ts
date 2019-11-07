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