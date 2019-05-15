# Oracle CX Augmented Reality Accelerator

## Overview

This accelerator is intended to provide example implementation practices for building Augmented Reality experiences that integrate with Oracle's SaaS CX applications: Service Cloud, Engagement Cloud, and others.

**This project is intended for demonstration use only.  It is not supported by Oracle or Oracle Customer Care.**  

The project does not compile without some programmatic effort, and it omits standard features for a public-facing application such as multi-user authentication and authorization.  Rather, this accelerator is intended to be a starting-point for delivering bespoke solutions that developers may leverage to review integration and interaction paradigms that Oracle is using for AR experiences integrated with CX applications.

### Repository Structure

This git repository is structured with the following folders:

1. `iOS App` folder contains the Xcode project to develop and built the AR application.
2. `Oracle` folder contains subfolders with assets that apply to configuring the AR app with Oracle Integration Cloud, Oracle Service Cloud, and Oracle Engagement Cloud.  These assets will be used to configure Oracle applications as per the implementation documentation described below.

## Implementation

Full implementation documentation may be found on Oracle Tech Net (OTN), which will guide you through the configuration of the Xcode project, setup of Oracle environments, and outline the methodology used to create the project.  The documentation includes:

1. Prerequisites, audience requirements, hardware requirements, and software requirements.
2. Configuration and use of the Oracle Integration Cloud flows that are used by the iOS code base.
3. Basic application use.

**Link will be published when Oracle Tech Network articles are live.**

### Prerequisites

#### Apple

1. Xcode 10.2 or later is required to develop and publish to your local device(s).
2. Membership in the [Apple Development Center](https://developer.apple.com) is required for advanced development and application deployment.
3. iOS device with an A9 chip or newer (for ARKit support).

#### CocoaPods

This project uses CocoaPods to install dependencies.  Instructions are written with the expectation that you are using CocoaPods.  However, you may install the third-party dependencies manually or using your package manager of choice.  To install CocoaPods, run the following command in Terminal.

```bash
sudo gem install cocoapods
```

### Getting Started

1. Clone this repository to your computer.
2. In Terminal, cd to the directory where you cloned the project.
3. In Terminal, cd to the `iOS App` sub folder of this project. 
4. Run the command `pod install`.  This will install the dependencies and will create a workspace file called `Augmented CX.workspace`.
5. Double click `Augmented CX.workspace` to open the project in Xcode and begin your exploration.
   1. **Do not use `Augmented CX.xcodeproj` to open the project.** It will not have the dependencies installed by CocoaPods and you will not be able to compile the application.
6. Resolve any `#error` tag requirements.  These have been injected for your review before the app will compile.
7. Build and test the app.  Use the OTN documents for reference regarding app configuration.

### More Info

#### Compiler Flags

There are a few compiler flags that are used throughout the source code to help track down info in code or integration requests.  You may add these values to either `RELEASE` or `DEBUG` scenario's in Xcode's `Active Compilation Conditions` build setting.

1. `DEBUG` is used to output generic debug messages, text, etc.  It is liberally used under many conditions and will cause output messages with standard compiler settings.
2. `DEBUGNETWORK` is used to output the requests and responses from HTTP requests.  Given the highly integrated nature of this app, it is a verbose log.  This flag is disabled by default.
3. `DEBUGIOT` is used to output the values of IoT sensors after the data is retrieved from an HTTP request.  This is helpful to see IoT values in logs when debugging the app.
4. `DEBUGEVENTS` is used to output debugging messages from the event logging classes that send data to CX Infinity and other remote data capture endpoints.

## Third-Party Open-Source Libraries

Thanks to these developers for their excellent open-source libraries.  See license file for license attribution.

* [iOSCharts](https://github.com/danielgindi/Charts)
* [XMLParsing](https://github.com/ShawnMoore/XMLParsing)
