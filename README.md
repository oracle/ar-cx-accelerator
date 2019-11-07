# Oracle CX Augmented Reality Accelerator

![Image of an AR experience built by extending this example accelerator.](Oracle/images/red-pump.jpg?raw=true "AR UI")

Screenshot of an example AR application built by extending the source code provided in this accelerator.

## Overview

This accelerator is intended to provide an example implementation for building Augmented Reality experiences that integrate with Oracle's CX service applications: Service Cloud, Engagement Cloud, and others.  The accelerator can be leveraged to introduce AR into a number of use cases such as field service, self-service, assisted-service, training, and knowledge delivery.  The accelerator includes content for:

1. Defining a convention to map the recognition of an image or object to remote IoT and service data.
2. Defining a convention to map AR model nodes to remote IoT and service data.
3. Using IoT data to display asset and device information.
4. Using IoT data to display real-time and historical sensor information.
5. Using Service Cloud or Engagement Cloud knowledge to supply PDF manuals and bulletins.
6. Defining a convention for building step-by-step guided procedures with text, image, and 3D animations that can be declared in JSON (rather than hard-coding them).

#### Important Info

**This project is intended for demonstration use only.  It is not supported by Oracle or Oracle Customer Care.**  

The project does not compile without some programmatic effort. And, it omits standard **required features** for a public-facing application such as multi-user authentication and authorization.  Rather, this accelerator is intended to be a starting-point for delivering bespoke solutions that developers may leverage to review integration and interaction paradigms that Oracle is using for AR experiences integrated with CX applications.

### Repository Structure

This git repository is structured with the following folders:

1. `iOS App` folder contains the Xcode project to develop and built the AR application.
2. `Oracle` folder contains subfolders with assets that apply to configuring the AR app with Oracle Integration Cloud, Oracle Service Cloud, and Oracle Engagement Cloud.  These assets will be used to configure Oracle applications as per the implementation documentation described below.
   1. `Engagement Cloud` folder contains the data model file to import into B2B service when using it as the service application for the AR app.
   2. `Images` contains images and other content used in the git repo.
   3. `OCI Functions` folder contains the OCI functions that are used for serving remote data to the app or proxying integration requests to other applications.
   4. `Service Cloud` folder contains the data model files, reports, and workspaces to import into B2C service when using it as the service application for the AR app.

### Prerequisites

#### Apple

1. Xcode 11.0 or later is required to develop and publish to your local device(s).
2. Membership in the [Apple Development Center](https://developer.apple.com) is required for advanced development and application deployment.
3. iOS device with an A9 chip or newer (for ARKit support).
4. iOS 12.4+ installed on your iOS device.

### Getting Started

1. Clone this repository to your computer.
2. In Terminal, cd to the directory where you cloned the project.
3. In Terminal, cd to the `iOS App` sub folder of this project. 
4. Double click `Augmented CX.workspace` to open the project in Xcode and begin your exploration.
   1. **Do not use `Augmented CX.xcodeproj` to open the project.**
5. Resolve any `#error` tag requirements.  These have been injected for your review before the app will compile.
6. Build and test the app.  Use the OTN documents for reference regarding app configuration.

### More Info

#### Compiler Flags

There are a few compiler flags that are used throughout the source code to help track down info in code or integration requests.  You may add these values to either `RELEASE` or `DEBUG` scenario's in Xcode's `Active Compilation Conditions` build setting.

1. `DEBUG` is used to output generic debug messages, text, etc.  It is liberally used under many conditions and will cause output messages with standard compiler settings.
2. `DEBUGNETWORK` is used to output the requests and responses from HTTP requests.  Given the highly integrated nature of this app, it is a verbose log.  This flag is disabled by default.
3. `DEBUGIOT` is used to output the values of IoT sensors after the data is retrieved from an HTTP request.  This is helpful to see IoT values in logs when debugging the app.
4. `DEBUGEVENTS` is used to output debugging messages from the event logging classes that send data to CX Infinity and other remote data capture endpoints.

#### Device ID Mapping Convension

AR experiences are not directly linked to individual devices or service scenarios without creating a convension to create such links.  This application attempts to create convensions that bridge the gaps between recognizing something in the real world (an image, device, etc.), identifying the specific instance of the device (the SKU or unique ID), and then applying an experience that is unique to that individual device.

We have also considered that recognizing the device in 3D space may not be possible by the user of the AR application.  There may be instances where a beacon or transmitter identifies the device instead of the visual cues.  [iBeacons](https://en.wikipedia.org/wiki/IBeacon) establish a pattern for recognition that we will follow in this app as well.  In following this structure our recognition mapping will use this pattern:

* UUID: A static UUID representing all devices mapped in the application.  This UUID will not change in our app.
* Major Value: An unsigned integer that maps to device models and their corresponding CAD data.  This is unique to the model level, but not the SKU.
* Minor Value: An unsigned integer that maps to individual device SKUs. 

|iBeacon Attribute|Value|
|-----|-----|
|UUID|1B765FF2-B692-4A42-8EBC-8AF2227ABCEC|
|Major Value|_device model_|
|Minor Value|_device id_|

In the case of the minor ID, a mapping service (an OCI Function in our case) will return the IoT CS UUID of the device, which can then be used for device-specific queries in IoTCS.

Using the supplied _red pump_ CAD model, the table would use the following convension, in which the device model represented by the _major value_ is always 1, since all red pumps are the same model, and each recognition image corresponding to a unique SKU in the _minor value_.

|iBeacon Attribute|Value|
|-----|-----|
|UUID|1B765FF2-B692-4A42-8EBC-8AF2227ABCEC|
|Major Value|1|
|Minor Value|1,2,3...n|

## iOS App Third-Party Open-Source Libraries

These third party libraries are leveraged in the iOS application via Swift Packages.

Thanks to these developers for their excellent open-source libraries.  See license file for license attribution.

* [iOSCharts](https://github.com/danielgindi/Charts)
* [XMLParsing](https://github.com/ShawnMoore/XMLParsing)
* [Font Awesome](https://github.com/FortAwesome/Font-Awesome/blob/master/LICENSE.txt)
