//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: ARViewController.swift
// *********************************************************************************************
//

import UIKit
import SceneKit
import ARKit
import os

class ARViewController:
    UIViewController,
    ARSCNViewDelegate,
    SKSceneDelegate,
    UIGestureRecognizerDelegate,
    UISplitViewControllerDelegate,
    OverlayControllerDelegate,
    AppServerConfigsDelegate,
    NodeContextDelegate,
    ProceduresViewControllerDelegate,
    ApplicationButtonsViewControllerDelegate
{
    
    
    // MARK: - IBOutlets

    /// Reference to the sceneView built in Interface Builder
    @IBOutlet weak var sceneView: ARSCNView!
    
    // MARK: - Properties

    /// The context data for the object/image that was last recognized by ARKit
    private var activeRecognitionContext: ARRecognitionContext?

    /// The name of the primary asset node that was loaded into the scene via recognition.
    private var activeNodeName: String?
    
    /// Parameter to cache the starting angles of the model parts so that we can move them back if needed.
    private var nodesOriginatingAngles: [String: SCNVector3]?

    /// Parameter to cache the starting position of the model parts so that we can move them back if needed.
    private var nodesOriginatingPositions: [String: SCNVector3]?

    /// Parameter to cache the starting opacity of the model parts so that we can move them back if needed.
    private var nodesOriginatingOpacities: [String: CGFloat]?

    /// The image placement spritekit scene
    private lazy var imagePlacementScene: SKScene? = {
        return SKScene(fileNamed: "ImagePlacementScene.sks")
    }()

    /// The help spritekit scene
    private lazy var modelHelpScene: SKScene? = {
        return SKScene(fileNamed: "ModelHelpScene.sks")
    }()

    /// The parts help spritekit scene
    private lazy var modelPartsHelpScene: SKScene? = {
        return SKScene(fileNamed: "ModelPartsHelpScene.sks")
    }()

    /// A dictionary to store the sensor settings for nodes as they are retreived remotely.  This cache prevents the need for repetative sensor calls as node selection changes.
    private var nodeSensorCache: [String: [ARSensor]] = [:]

    /// Variable indicating if the root asset child nodes are currently in an position that is different from their origin.
    private var partsExposed: Bool = false

    /// Variable indicating if parts are currently animating
    private var animatingParts: Bool = false

    /// Flag to indicate if all touch gestures should be enabled or disabled in the AR view.
    private var gesturesEnabled: Bool = true

    /// Flag to indicate if all animations should be enabled or disabled in the AR view.  This is helpful when the user has moved a node outside of its normal boundaries and an animation against the node would not play accurately because of its position.
    private var animationsEnabled: Bool = true

    /// Flag that will block alerts that beacons have been found.
    private var blockBeaconAlerts: Bool = true

    /// Variable to indicate if an IoT device request is in process.
    private var iotDeviceRequestInProcess: Bool = false

    /// Variable to indicate if an IoT message request is in process.
    private var iotMessageRequestInProcess: Bool = false

    /// Variable to store the IoT device applicationId for the scanned item.
    private var iotApplicationId: String?

    /// Variable to store the IoT device for the scanned item.
    private var iotDevice: IoTDevice?

    /// Variable to store the last sensor message returned from IoTCS.
    private var lastSensorMessage: SensorMessage?

    /// Reference to a timer that controlls how quickly to request IoT sensor data.
    private var sensorTimer: Timer?

    /// Reference to the current scene node that has been captured by a tap and will display a contextual UI.
    private weak var tappedNode: SCNNode?

    /// Reference to the current scene node that has been captured by a long tap and will be dragged.
    private weak var dragNode: SCNNode?

    /// Reference to the current scene node that is being scaled via pinch.
    private weak var pinchNode: SCNNode?

    /// Reference to a view controller that is supplying an overlay to the AR experience (Charts, etc.)
    weak var overlayViewController: UIViewController?
    
    // MARK: - Animation

    /// An enumeration of animations that are baked into the AR components of this application and can be programmatically applied to any node.  An AR procedure step can apply an animation to a set of nodes, and this allows reference to the animation that should be applied.
    enum Animation: String, CaseIterable {
        case identify,
        fadeIn,
        fadeOut,
        materialsOpacity,
        moveX,
        moveY,
        moveZ,
        opacity,
        pulsingAlpha,
        pulsingHighlight,
        returnToOrigin,
        rotateX,
        rotateY,
        rotateZ,
        wait
    }

    /// Default duration for animations if not specified elsewhere.
    private let defaultDuration: TimeInterval = 0.25
    
    /**
     Plays a predefined animation against a single node.
     
     - Parameter animation: The animation that should be played against the node.
     - Parameter nodeName: The name of the nodes to apply the animation to.
     - Parameter value: The value to alter the animation to.
     - Parameter completion: The procedure that will be displayed.
     */
    private func play(_ animation: Animation, for nodeName: String, value: Double, duration: Double, completion: (() -> ())? = nil) {
        let nodes = self.sceneView.scene.rootNode.childNodes(passingTest: { (childNode, shouldStop) -> Bool in
            return childNode.name == nodeName
        })
        
        guard nodes.count > 0 else {
            os_log(.error, "Could not find node with name '%@' to play animation '%@'", nodeName, animation.rawValue)
            completion?()
            return
        }
        
        self.play(animation, for: nodes, value: value, duration: duration) {
            completion?()
        }
    }
    
    /**
     Plays a predefined animation against a single node.
     
     - Parameter animation: The animation that should be played against the node.
     - Parameter nodes: The array of nodes to apply the animation to.
     - Parameter value: The value to alter the animation to.
     - Parameter completion: The procedure that will be displayed.
     */
    private func play(_ animation: Animation, for nodes: [SCNNode], value: Double, duration: Double, completion: (() -> ())? = nil) {
        guard self.animationsEnabled else {
            completion?()
            return
        }
        
        for node in nodes {
            #if DEBUG
            if let nodeName = node.name {
                os_log(.debug, "Playing animation '%@' for node '%@'", animation.rawValue, nodeName)
            }
            #endif
            
            var action: SCNAction!
            
            switch animation {
            case .fadeIn:
                action = .fadeIn(duration: duration)
            case .fadeOut:
                action = .fadeOut(duration: duration)
            case .identify:
                action = .identify(duration: duration)
            case .materialsOpacity:
                action = .materialsOpacity(duration: duration, opacity: CGFloat(value))
            case .moveX:
                let changeVector = SCNVector3(value, 0, 0)
                action = .move(by: changeVector, duration: duration)
            case .moveY:
                let changeVector = SCNVector3(0, value, 0)
                action = .move(by: changeVector, duration: duration)
            case .moveZ:
                let changeVector = SCNVector3(0, 0, value)
                action = .move(by: changeVector, duration: duration)
            case .opacity:
                action = SCNAction.fadeOpacity(to: CGFloat(value), duration: duration)
            case .pulsingAlpha:
                action = .pulsingAlpha(duration: duration)
            case .pulsingHighlight:
                action = .pulsingHighlight(duration: duration)
            case .returnToOrigin:
                self.returnNodes()
                return
            case .rotateX:
                action = .rotate(by: CGFloat(value.degreesToRadians), around: SCNVector3(1, 0, 0), duration: duration)
            case .rotateY:
                action = .rotate(by: CGFloat(value.degreesToRadians), around: SCNVector3(0, 1, 0), duration: duration)
            case .rotateZ:
                action = .rotate(by: CGFloat(value.degreesToRadians), around: SCNVector3(0, 0, 1), duration: duration)
            case .wait:
                action = .wait(duration: duration)
            }
            
            node.runAction(action) {
                if node == nodes.last {
                    completion?()
                }
            }
        }
    }
    
    /**
     Maps an array of ARAnimation objects to animations provided by this view controller and then plays them.
     
     - Parameter animations: Array of ARAnimations to map to animations in this controller.
     - Parameter completion: A callback to call after all animations are played.
     
     - Throws: Exception when an animation cannot be mapped to the current model.
    */
    func playAnimations(animations: [ARAnimation], completion: (() -> ())?) throws -> () {
        // Map the string array the values in animations enum
        var convertedAnimations: [Animation] = []
        for animation in animations {
            guard let val = Animation(rawValue: animation.name) else { continue }
            convertedAnimations.append(val)
        }
        
        // If we cannot map all animations supplied then we cannot play all animations.  Prevent the list from playing and fix the JSON nodes with incorrect animation names.
        if animations.count != convertedAnimations.count {
            throw SCNAction.ActionError.cannotMapAction(nodeCountExpected: animations.count, nodeCountCalculted: convertedAnimations.count)
        }
        
        self.animatingParts = true
        
        let parallelAnimationForNodes: (Animation, ARAnimation, (() -> ())?) -> () = { (animation, procedureAnimation, animationCompletion) in
            // Add any attribute to the supplied nodes prior to animation
            if let attributes = procedureAnimation.attributes {
                self.addAttributesToSceneNodes(procedureAnimation.nodes, attributes: attributes)
            }
            
            // Run the animations
            for node in procedureAnimation.nodes {
                let value = procedureAnimation.value ?? 0.0
                let duration = procedureAnimation.duration ?? 0.0
                
                self.play(animation, for: node, value: value, duration: duration, completion: {
                    // Remove attributes
                    if let attributes = procedureAnimation.attributes {
                        self.removeAttributeChildNodes(node, attributes: attributes)
                    }
                    
                    // Cleanup after last node played
                    if node == procedureAnimation.nodes.last {
                        // Cleanup run
                        animationCompletion?()
                        
                        self.animatingParts = false
                    }
                })
            }
        }
        
        guard convertedAnimations.count > 0 else {
            throw SCNAction.ActionError.emptyActionArray
        }
        
        var playingIndex = 0
        var arAnimation = convertedAnimations[playingIndex]
        var procedureAnimation = animations[playingIndex]
        
        var completionHandler: (() -> ())!
        completionHandler = {
            playingIndex = playingIndex + 1
            
            if playingIndex < convertedAnimations.count {
                arAnimation = convertedAnimations[playingIndex]
                procedureAnimation = animations[playingIndex]
                parallelAnimationForNodes(arAnimation, procedureAnimation, completionHandler)
            } else {
                completion?()
            }
        }
        
        parallelAnimationForNodes(arAnimation, procedureAnimation, completionHandler)
    }
    
    /**
     Animates model subnodes back to their original position in the scene.
     
     - Parameter completion: Completion called once nodes have been returned to their original positions.
     */
    private func returnNodes(completion: (() -> ())? = nil) {
        guard let partsWithOriginalPositionsSaved = self.nodesOriginatingPositions, let partsWithOriginalAnglesSaved = self.nodesOriginatingAngles, let partsWithOriginalOpacitiesSaved = self.nodesOriginatingOpacities else {
            #if DEBUG
            os_log(.debug, "Parts with original positions array empty.")
            #endif
            return
        }
        
        self.animatingParts = true
        
        var animateReturn: ((String) -> ())!
        animateReturn = { nodeName in
            guard let position = partsWithOriginalPositionsSaved[nodeName], let angle = partsWithOriginalAnglesSaved[nodeName], let opacity = partsWithOriginalOpacitiesSaved[nodeName], let node = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else {
                #if DEBUG
                os_log(.debug, "Could not get original position for node named: %@", nodeName)
                #endif
                return
            }
            
            let actions: SCNAction = .group([
                .fadeOpacity(to: opacity, duration: self.defaultDuration),
                .move(to: position, duration: self.defaultDuration),
                .rotateTo(x: CGFloat(angle.x), y: CGFloat(angle.y), z: CGFloat(angle.z), duration: self.defaultDuration)
                ])
            
            node.runAction(actions, completionHandler: {
                self.animatingParts = false
                self.partsExposed = false
                self.animationsEnabled = true
                
                completion?()
            })
            
            for childNode in node.childNodes {
                guard let childNodeName = childNode.name else { continue }
                
                animateReturn(childNodeName)
            }
        }
        
        for nodeName in partsWithOriginalPositionsSaved.keys {
            animateReturn(nodeName)
        }
    }
    
    // MARK: - UIViewController Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Enable Default Lighting
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // remove any existing nodes
        for node in self.sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
        
        // Create a rotation gesture recognizer to rotate nodes
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotating))
        rotationGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(rotationGestureRecognizer)
        
        // Create a pinch gesture recognizer that we can use to explode the model
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinching))
        pinchGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(pinchGestureRecognizer)
        
        // Gesture recognizer for panning motions
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panRecognizerHandler))
        panGestureRecognizer.delegate = self
        self.view?.addGestureRecognizer(panGestureRecognizer)
        
        // Create a long press tap gesture recognizer to select a node to move
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        longPressGestureRecognizer.numberOfTapsRequired = 0
        longPressGestureRecognizer.numberOfTouchesRequired = 1
        longPressGestureRecognizer.minimumPressDuration = 0.5
        longPressGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(longPressGestureRecognizer)
        
        // Create a one-finger tap gesture recognizer that we can use to interact with the model
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.numberOfTouchesRequired = 1
        tapGestureRecognizer.require(toFail: longPressGestureRecognizer) // Tap only recognizes if long press fails
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGestureRecognizer)
        
        // Create a two-finger tap gesture recognizer that we can reselect the full model when tapped
        let twoFingerGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(twoFingerTap))
        twoFingerGestureRecognizer.numberOfTapsRequired = 1
        twoFingerGestureRecognizer.numberOfTouchesRequired = 2
        twoFingerGestureRecognizer.require(toFail: tapGestureRecognizer) // Tap only recognizes if single finger tap fails
        twoFingerGestureRecognizer.require(toFail: longPressGestureRecognizer) // Tap only recognizes if long press fails
        twoFingerGestureRecognizer.require(toFail: pinchGestureRecognizer) // Tap only recognizes if long press fails
        twoFingerGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(twoFingerGestureRecognizer)
        
        // Create a three-finger tap gesture recognizer that we can expose the inside nodes of the model
        let threeFingerGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(threeFingerTap))
        threeFingerGestureRecognizer.numberOfTapsRequired = 1
        threeFingerGestureRecognizer.numberOfTouchesRequired = 3
        threeFingerGestureRecognizer.require(toFail: tapGestureRecognizer) // Tap only recognizes if single finger tap fails
        threeFingerGestureRecognizer.require(toFail: twoFingerGestureRecognizer) // Tap only recognizes if two finger tap fails
        threeFingerGestureRecognizer.require(toFail: longPressGestureRecognizer) // Tap only recognizes if long press fails
        threeFingerGestureRecognizer.require(toFail: pinchGestureRecognizer) // Tap only recognizes if long press fails
        threeFingerGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(threeFingerGestureRecognizer)
        
        // Create and event that the AR view loaded
        AppEventRecorder.shared.record(name: "AR View Loaded", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: String(describing: type(of: self)), arAnchor: nil, arNode: nil, jsonString: nil, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide UINavigation Bar on AR View
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Applies the halo technique to the selected node for highlighting.
        #if DEBUGUI
        //Show stats in debug mode
        //sceneView.showsStatistics = true // Showing stats is a huge performance killer so only enable when needed.
        os_log(.debug, "Will not apply line technique during debug to prevent frequent crashes in debug mode.")
        #else
        if let path = Bundle.main.path(forResource: "LineNodeTechnique", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path) as? [String : AnyObject] {
                let technique = SCNTechnique(dictionary: dict)
                self.sceneView.technique = technique
            }
        }
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // If server configs already exist when this view appears, then call the set method.
        if (UIApplication.shared.delegate as? AppDelegate)?.appServerConfigs?.serverConfigs != nil {
            self.serverConfigsRetrieved(true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let tapped = self.tappedNode {
            self.removeTappedNodeContext(tapped, completion: nil)
        }
        
        // Pause the view's session
        sceneView.session.pause()
        
        let configuration = ARWorldTrackingConfiguration();
        configuration.planeDetection = [] //empty array (as opposed to .horizontal .vertical)
        sceneView.session.run(configuration)
        
        // Pause the timer
        self.setSensorTimerState(to: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) { (transitionContext) in
            DispatchQueue.main.async {
                let contextControllers = self.children.filter({ $0 is ContextViewController })
                
                for controller in contextControllers {
                    let contextController = controller as! ContextViewController
                    contextController.resizeForContent(self.defaultDuration, completion: nil)
                }
            }
        }
        
        DispatchQueue.main.async {
            let viewFrameWidth = self.view.frame.size.width - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right
            let viewFrameHeight = self.view.frame.size.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom
            
            // Reverse height and width this since method is called before the transition
            self.sizeOverlayNodes(widthComparison: viewFrameHeight, heightComparison: viewFrameWidth)
        }
    }
    
    // MARK: - Gesture Recognizer Handers
    
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) || (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) {
            return false
        }
        
        if (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer) || (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer) {
            return false
        }
        
        if (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer) || (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) {
            return false
        }
        
        return true
    }
    
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // If gestures are disabled, then return false.
        if !self.gesturesEnabled { return false }
        
        // If there is a view overlaying the AR View, then don't recognize
        let viewsTouched = self.view.subviews.filter { $0.frame.contains(gestureRecognizer.location(in: self.view)) }
        
        #if DEBUG
        os_log(.debug, "Subviews Touched: %d", viewsTouched.count)
        #endif
        
        // Only allow the guesture if the touch was in the AR space and not a context view.
        return viewsTouched.count == 0
    }
    
    // MARK: - Gesture Handler Methods
    
    /**
     Event handler for a rotation event.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func rotating(_ sender: UIRotationGestureRecognizer) {
        guard let activeNode = self.tappedNode else { return }
        let gestureName = "Rotate Gesture"
        
        if sender.numberOfTouches == 2 {
            #if DEBUG
            os_log(.debug, "rotating")
            #endif
            
            if sender.state == .began {
                #if DEBUG
                os_log(.debug, "rotation began")
                #endif
                
                if let event = try? AppEventRecorder.shared.getEvent(name: gestureName) {
                    event.uiElement = self.activeNodeName
                    AppEventRecorder.shared.record(event: event, completion: nil)
                }
            }
            else if sender.state == .changed {
                let newY: Float = Float(sender.rotation) * -1
                activeNode.eulerAngles.y = newY
            }
            else {
                #if DEBUG
                os_log(.debug, "rotation ended")
                #endif
                
                // Only return if a procedure is not running
                if !self.children.contains(where: { $0 is ProceduresViewController }) {
                    if let nodeName = activeNode.name, let originalAngles = self.nodesOriginatingAngles?[nodeName] {
                        activeNode.runAction(.rotateTo(x: CGFloat(originalAngles.x), y: CGFloat(originalAngles.y), z: CGFloat(originalAngles.z), duration: 0.25))
                    } else {
                        activeNode.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.25))
                    }
                }
                
                guard let event = try? AppEventRecorder.shared.getEvent(name: gestureName) else { return }
                event.eventEnd = Date()
                event.readyToSend = true
                AppEventRecorder.shared.record(event: event, completion: nil)
            }
        }
    }
    
    /**
     Event handler for a pinch event.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func pinching(_ sender: UIPinchGestureRecognizer) {
        // Only scale when root node selected
        guard self.activeNodeName == self.tappedNode?.name else { return }
        let gestureName = "Pinch Gesture"
        
        #if DEBUG
        os_log(.debug, "pinching")
        #endif
        
        // Get the visible model node in the scene
        if self.pinchNode == nil {
            guard let activeNodeName = self.activeNodeName, let scaleNode = self.sceneView.scene.rootNode.childNode(withName: activeNodeName, recursively: true) else { return }
            pinchNode = scaleNode
        }
        
        if sender.state == .began{
            if let event = try? AppEventRecorder.shared.getEvent(name: gestureName) {
                event.uiElement = self.activeNodeName
                AppEventRecorder.shared.record(event: event, completion: nil)
            }
        }
        else if sender.state == .changed {
            if ((sender.velocity < 1 && self.pinchNode!.scale.x > 0.01) || (sender.velocity > 1 && self.pinchNode!.scale.x < 10.0)) {
                let scaleReduction: Float = 0.01 * Float(sender.velocity)
                
                let x = self.pinchNode!.scale.x + scaleReduction
                let y = self.pinchNode!.scale.y + scaleReduction
                let z = self.pinchNode!.scale.z + scaleReduction
                let changeBy = SCNVector3(x, y, z)
                self.pinchNode!.scale = changeBy
            }
        }
        else if sender.state == .ended {
            // Ensure rotation back to origin since both gestures can run at the same time
            // Only return if a procedure is not running
            if !self.children.contains(where: { $0 is ProceduresViewController }) {
                if let nodeName = pinchNode?.name, let originalAngles = self.nodesOriginatingAngles?[nodeName] {
                    self.pinchNode?.runAction(.rotateTo(x: CGFloat(originalAngles.x), y: CGFloat(originalAngles.y), z: CGFloat(originalAngles.z), duration: 0.25))
                } else {
                    self.pinchNode?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.25))
                }
            }
            
            self.pinchNode = nil
            
            guard let event = try? AppEventRecorder.shared.getEvent(name: gestureName) else { return }
            event.eventEnd = Date()
            event.readyToSend = true
            AppEventRecorder.shared.record(event: event, completion: nil)
        }
    }
    
    /**
     Event handler for a single tap event.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func tapped(_ sender: UITapGestureRecognizer) {
        #if DEBUG
        os_log(.debug, "single tapped")
        #endif
        
        let gestureName = "Single Finger Tap"
        
        if sender.state == .ended {
            // Remove any help scene in the overlay
            if self.sceneView.overlaySKScene != nil && self.sceneView.overlaySKScene!.children.count > 0 {
                DispatchQueue.main.async {
                    self.sceneView.overlaySKScene?.removeAllChildren()
                }
                
                return
            }
            
            // Remove any existing highlighting on items
            for node in self.sceneView.scene.rootNode.childNodes {
                node.setHighlighted(false)
            }
            
            let locationInView: CGPoint = sender.location(in: self.sceneView)
            
            let hitTest = self.sceneView.hitTest(locationInView, options: nil)
            
            if let nodeHit = hitTest.first?.node, let nodeName = nodeHit.name {
                AppEventRecorder.shared.record(name: gestureName, eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: nil, arAnchor: self.activeRecognitionContext?.name, arNode: nodeName, jsonString: nil, completion: nil)
                
                // Ensure that the node was tapped either while a procedure is not active, or if it is listed in the interaction nodes
                if let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController {
                    let interactionNodes = proceduresViewController.procedure?.interactionNodes
                    guard (interactionNodes != nil && interactionNodes!.contains(nodeName)) else { return }
                }
                
                #if DEBUG
                if nodeHit.name != nil {
                    os_log(.debug, "Node Tapped: %@", nodeName)
                }
                #endif
                
                // make sure that the node has a name and that it was not a sensor
                let itemTapped = hitTest.contains { ($0.node.name != nil && !$0.node.name!.contains("_Sensor")) }
                
                // Manage taps for the model item(s)
                if itemTapped {
                    #if DEBUG
                    os_log(.debug, "Item is a 3D node. Setting context.")
                    #endif
                    
                    // remove sensors from the currently tapped node if it is different from the previously tapped node
                    if let previouslyTappedNode = self.tappedNode, previouslyTappedNode.name != nodeHit.name {
                        self.hideSensors(for: previouslyTappedNode)
                    }
                    
                    self.setTappedNodeContext(nodeHit)
                }
                
                // Check for taps on a sensor
                else if nodeName.contains("_Sensor") {
                    self.sensorTapped(nodeHit)
                }
            }
            else {
                #if DEBUG
                os_log(.debug, "No node tapped")
                os_log(.debug, "Root node name: '%@'", (self.sceneView.scene.rootNode.name ?? ""))
                #endif
                
                let removeContext: () -> () = {
                    guard let nodeToRemoveContext = self.tappedNode else { return }
                    self.removeTappedNodeContext(nodeToRemoveContext, completion: nil)
                    self.tappedNode = nil
                }
                
                let setContextToRecognitionNode: () -> () = {
                    // see if we can select the recognition node for root level context
                    guard let sensors = self.activeRecognitionContext?.sensors, sensors.count > 0 else { removeContext(); return }
                    guard let recognitionNodeName = self.activeRecognitionContext?.name else { return }
                    guard let recognitionNode = self.sceneView.scene.rootNode.childNode(withName: recognitionNodeName, recursively: false) else { return }
                    
                    self.setTappedNodeContext(recognitionNode)
                }
                
                if self.tappedNode != nil && self.activeRecognitionContext != nil && self.tappedNode?.name != self.activeRecognitionContext?.name {
                    setContextToRecognitionNode()
                }
                // If the tapped node is already set to the recognition node, then no other action required
                else if self.tappedNode?.name == self.activeRecognitionContext?.name {
                    return
                }
                else {
                    removeContext()
                }
            }
        }
    }/**
     Event handler for a single two-finger tap that will select the root node of the actively recognized item.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func twoFingerTap(_ sender: UITapGestureRecognizer) {
        #if DEBUG
        let gestureName = "Two Finger Tap"
        os_log(.debug, "%@", gestureName)
        #endif
        
        guard let nodeName = self.activeRecognitionContext?.nodeName() else { return }
        
        // Ensure that a procedure is not active, or if it is listed in the interaction nodes
        if let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController {
            let interactionNodes = proceduresViewController.procedure?.interactionNodes
            guard (interactionNodes != nil && interactionNodes!.contains(nodeName)) else { return }
        }
        
        guard let node = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else { return }
        
        self.returnNodes {
            DispatchQueue.main.async {
                self.setTappedNodeContext(node)
            }
        }
    }
    
    /**
     Event handler for a single three-finger tap event which will play a node's assigned animations from its ARNodeContext context.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func threeFingerTap(_ sender: UITapGestureRecognizer) {
        let gestureName = "Three Finger Tap"
        
        #if DEBUG
        os_log(.debug, "%@", gestureName)
        #endif
        
        let locationInView: CGPoint = sender.location(in: self.sceneView)
        let hitResults = self.sceneView.hitTest(locationInView, options: nil)
        let hitNode = hitResults.first?.node
        let nodeName = hitNode?.name
 
        AppEventRecorder.shared.record(name: gestureName, eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: nil, arAnchor: self.activeRecognitionContext?.name, arNode: hitNode?.name, jsonString: nil, completion: nil)
        
        // Ensure that the node was tapped either while a procedure is not active, or if it is listed in the interaction nodes
        if let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController, nodeName != nil {
            let interactionNodes = proceduresViewController.procedure?.interactionNodes
            guard (interactionNodes != nil && interactionNodes!.contains(nodeName!)) else { return }
        }
        
        if sender.state == .ended && !self.animatingParts {
            if !self.partsExposed {
                #if DEBUG
                os_log(.debug, "Exposing Parts")
                #endif
                
                guard let animations = self.activeRecognitionContext?.actionAnimations, animations.count > 0 else {
                    #if DEBUG
                    os_log(.debug, "No actions assigned to recognition context '%@'", self.activeRecognitionContext?.name ?? "N/A")
                    #endif
                    
                    return
                }
                
                // Try to play the animation.  If there is a failure, then return the nodes.
                do {
                    try self.playAnimations(animations: animations) {
                        self.partsExposed = true
                    }
                } catch {
                    error.log()
                    self.returnNodes(completion: nil)
                }
            } else {
                #if DEBUG
                os_log(.debug, "Returning Parts")
                #endif
                
                self.returnNodes(completion: nil)
            }
        }
    }
    
    /**
     Event handler for a long press event.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func longPress(_ sender: UILongPressGestureRecognizer) {
        let gestureName = "Long Press"
        
        let location: CGPoint = sender.location(in: self.sceneView)
        
        // Ensure there is a hit result and that the result is not a sensor node
        guard let hitResult = sceneView.hitTest(location, options: [:]).first?.node, let nodeName = hitResult.name, !nodeName.contains("Sensor") else {
            return
        }
        
        // Ensure that the node was tapped either while a procedure is not active, or if it is listed in the interaction nodes
        if let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController {
            let interactionNodes = proceduresViewController.procedure?.interactionNodes
            guard (interactionNodes != nil && interactionNodes!.contains(nodeName)) else { return }
        }
        
        if sender.state == .began {
            self.dragNode = hitResult
            
            // Highlight the item being tapped
            self.highlightMaterials(self.dragNode!)
            
            // Remove the alpha of child nodes to prevent flicker
            if let nonSensorNodes = self.dragNode?.nonSensorChildNodes {
                for node in nonSensorNodes {
                    node.opacity = 0
                }
            }
            
            //Only update the tapped node once since this method get's called a lot during drag events
            if self.tappedNode != self.dragNode {
                if let activeNodeName = self.activeNodeName, let activeNode = self.sceneView.scene.rootNode.childNode(withName: activeNodeName, recursively: true) {
                    activeNode.setHighlighted(false)
                }
                self.tappedNode?.setHighlighted(false)
                self.setTappedNodeContext(self.dragNode!)
                
                self.tappedNode = self.dragNode
            }
            
            if let event = try? AppEventRecorder.shared.getEvent(name: gestureName) {
                event.uiElement = nodeName
                AppEventRecorder.shared.record(event: event, completion: nil)
            }
        }
        else if sender.state == .ended {
            if self.dragNode != nil {
                self.resetMaterials(self.dragNode!)
            }
            
            // After dragging a part, parts are exposed
            if let hitResultName = hitResult.name, hitResultName != self.activeNodeName, let origPositions = self.nodesOriginatingPositions {
                let origPos = origPositions[hitResultName]
                
                if origPos != nil && !SCNVector3EqualToVector3(origPos!, hitResult.position) {
                    self.partsExposed = true
                }
            }
            
            self.dragNode = nil
            
            guard let activeNodeName = self.activeNodeName, let activeNode = self.sceneView.scene.rootNode.childNode(withName: activeNodeName, recursively: true) else { return }
            
            for node in activeNode.childNodes {
                self.resetMaterials(node)
            }
            
            guard let event = try? AppEventRecorder.shared.getEvent(name: gestureName) else { return }
            event.eventEnd = Date()
            event.readyToSend = true
            AppEventRecorder.shared.record(event: event, completion: nil)
        }
    }
    
    /**
     Event handler for a pan event.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func panRecognizerHandler(_ sender: UIPanGestureRecognizer) {
        let gestureName = "Finger Pan"
        
        let velocity = sender.velocity(in: self.view)
        let scaleReduction: Float = 0.00001
        
        // Drag the selected node when 1 finger is used.
        if sender.numberOfTouches == 1 {
            guard let selectedNode = self.dragNode, let nodeName = selectedNode.name else {
                #if DEBUG
                os_log(.debug, "Pan called by drag node not selected")
                #endif
                
                return
            }
            
            // Ensure that the node was tapped either while a procedure is not active, or if it is listed in the interaction nodes
            if let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController {
                let interactionNodes = proceduresViewController.procedure?.interactionNodes
                guard (interactionNodes != nil && interactionNodes!.contains(nodeName)) else { return }
            }
            
            if sender.state == .changed {
                //since a drag is a 2d motion, move the object on the x and z axis only
                let x = selectedNode.position.x + (Float(velocity.x) * selectedNode.scale.x * scaleReduction)
                let scaleY = -(Float(velocity.y) * selectedNode.scale.y * scaleReduction)
                let y = selectedNode.position.y + scaleY
                let z = selectedNode.position.z
                
                let position = SCNVector3Make(x, y, z)
                selectedNode.position = position
                
                #if DEBUG
                os_log(.debug, "1-Finger Pan Position: X (%.5f) Y (%.5f) Z (%.5f)", position.x, position.y, position.z)
                #endif
            }
        }
        // Move the entire model when two fingers are used
        else if sender.numberOfTouches == 2 {
            if sender.state == .changed {
                //since a drag is a 2d motion, move the object on the x and z axis only
                let selectedNode = self.sceneView.scene.rootNode
                let x = selectedNode.position.x + (Float(velocity.x) * selectedNode.scale.x * scaleReduction)
                let scaleY = -(Float(velocity.y) * selectedNode.scale.y * scaleReduction)
                let y = selectedNode.position.y + scaleY
                let z = selectedNode.position.z
                
                let position = SCNVector3Make(x, y, z)
                selectedNode.position = position
                
                #if DEBUG
                os_log(.debug, "2-Finger Pan Position: X (%.5f) Y (%.5f) Z (%.5f)", position.x, position.y, position.z)
                #endif
            }
        }
        // Change the opacity when three models are used.
        else if sender.numberOfTouches == 3 {
            #if DEBUG
            os_log(.debug, "3-Finger pan")
            #endif
            
            guard let recognizedNodeName = self.activeRecognitionContext?.name else { return }
            guard let modelNode = self.sceneView.scene.rootNode.childNode(withName: recognizedNodeName, recursively: true) else { return }
            guard let childNodes = modelNode.nonSensorChildNodes else { return }
            //guard let firstNode = childNodes.first else { return }
            let opacity = modelNode.opacity
            
            let scaleReduction: CGFloat = 0.00005
            var newOpacity = opacity + scaleReduction * CGFloat(velocity.y) * -1
            
            if newOpacity < 0 {
                newOpacity = 0
            }
            if newOpacity > 1 {
                newOpacity = 1
            }
            
            #if DEBUG
            os_log(.debug, "New Transparency: %.5f", newOpacity)
            #endif
            
            modelNode.opacity = newOpacity
            for node in childNodes {
                node.setChildNodeOpacity(opacity: newOpacity)
            }
        }
        
        if sender.state != .began && sender.state != .changed {
            if let dragNode = self.dragNode {
                self.resetMaterials(dragNode)
                self.dragNode = nil
            }
        }
        
        if sender.state == .began {
            if let event = try? AppEventRecorder.shared.getEvent(name: gestureName) {
                event.uiElement = self.dragNode?.name
                AppEventRecorder.shared.record(event: event, completion: nil)
            }
        }
        else if sender.state == .ended {
            guard let event = try? AppEventRecorder.shared.getEvent(name: gestureName) else { return }
            event.eventEnd = Date()
            event.readyToSend = true
            AppEventRecorder.shared.record(event: event, completion: nil)
        }
    }
    
    // MARK: - AppServerConfigsDelegate Methods
    
    func gettingServerConfigs() {
        // Show Loading View
        guard let vc = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateInitialViewController() as? ActivityOverlayViewController else { return }

        self.addChild(vc)
        vc.view.frame = self.view.frame
        self.view.addSubview(vc.view)
        vc.setLabel("Getting Configuration from Server")
    }
    
    func serverConfigsRetrieved(_ result: Bool) {
        let showError: () -> () = {
            let alert = UIAlertController(title: "Unable to Load Configs", message: "We are unable to reach Oracle Cloud Infrastructure for server data. Ensure that the OCI F(n) configuration variables are set in application settings and that the username and password are correct.", preferredStyle: UIAlertController.Style.alert)
            
            let settingsAction = UIAlertAction(title: "Open Settings", style: .default) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        os_log(.debug, "Settings opened")
                    })
                }
            }
            
            alert.addAction(settingsAction)  // Go to settings button
            alert.addAction(UIAlertAction(title: "Retry", style: UIAlertAction.Style.cancel, handler: { action in
                self.resetScene(true)
            }))
            
            //ensure alert is presented on the main UI thread
            DispatchQueue.main.async {
                self.present(alert, animated: true)
            }
        }
        
        DispatchQueue.main.async {
            // If not successful, supply a warning to configure the remote settings.
            guard result else { showError(); return }
            
            guard let overlayVc = self.children.first(where: { $0 is ActivityOverlayViewController }) as? ActivityOverlayViewController else { return }
            overlayVc.view.removeFromSuperview()
            overlayVc.removeFromParent()
            
            self.setTrackingConfiguration()
        }
    }

    // MARK: - ARSCNViewDelegate Methods
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        AppEventRecorder.shared.record(name: "AR Session Failed", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: nil, arAnchor: self.activeRecognitionContext?.name, arNode: self.activeNodeName, jsonString: nil, completion: nil)
        
        // Present an error message to the user
        let alert = UIAlertController(title: "AR Error", message: "The AR session ended in an unexpected error: \(error)", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: {
                self.resetScene(true)
            })
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        os_log(.info, "AR Session Interrupted")
        
        self.setSensorTimerState(to: false)
        
        guard let event = try? AppEventRecorder.shared.getEvent(name: "AR Session Interrupted") else { return }
        event.eventStart = Date()
        event.arNode = self.activeNodeName
        event.arAnchor = self.activeRecognitionContext?.name
        AppEventRecorder.shared.record(event: event, completion: nil)
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        os_log(.info, "AR Session Interruption Ended")
        
        self.setSensorTimerState(to: true)
        
        // Present an error message to the user if object recognition is used since tracking is likely to have failed
        if let config = UserDefaults.standard.string(forKey: "recognition_type"), config != "image" {
            let alert = UIAlertController(title: "AR Session Interrupted", message: "The AR session was interrupted and will be reset.", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default, handler: { action in
                self.resetScene(true)
            })
            alert.addAction(action)
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
            
            return
        }
        
        guard let deviceId = self.iotDevice?.id else {
            os_log(.error, "Device ID does not exist on AR controller after session interruption ended.")
            return
        }
        self.getDeviceData(deviceId, completion: nil)
        
        guard let event = try? AppEventRecorder.shared.getEvent(name: "AR Session Interrupted") else { return }
        event.eventEnd = Date()
        AppEventRecorder.shared.record(event: event, completion: nil)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //Ensure that the scene is empty and does not have nodes that may have lingered from a different tracking session
        self.resetScene(false)
        
        guard let anchorName = anchor.name else {
            os_log(.error, "Anchor scanned does not have a name. Cannot proceed with AR experience.")
            return
        }
        
        let anchorObjNameComponents = anchorName.split(separator: "_")
        
        guard anchorObjNameComponents.count >= 3, let major = Int(String(anchorObjNameComponents[0])), let minor = Int(String(anchorObjNameComponents[1])) else {
            os_log(.error, "Anchor scanned does not conform to the naming convension established in this application.  Major and minor values expected in first two array keys.")
            return
        }
        
        let anchorObjNameSubStr = String(anchorObjNameComponents[2])
        let anchorObjFileName = String(format: "%d-%@", major, anchorObjNameSubStr)
        let anchorObjNodeName = String(anchorObjNameSubStr)
        
        #if DEBUG
        os_log(.debug, "Anchor Name: %@", anchorName)
        os_log(.debug, "Anchor File Name: %@.scn", anchorObjFileName)
        os_log(.debug, "Anchor Node Name: %@", anchorObjNodeName)
        os_log(.debug, "Anchor Object Major: %d", major)
        os_log(.debug, "Anchor Object Minor: %d", minor)
        #endif
        
        AppEventRecorder.shared.record(name: "AR Renderer Added Node", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: nil, arAnchor: anchorName, arNode: nil, jsonString: nil, completion: nil)
        
        let setupRecognitionContext: () -> () = {
            #if DEBUG
            os_log(.debug, "Setting up recognition context for %@", anchorName)
            #endif
            
            guard let context = self.activeRecognitionContext else {
                #if DEBUG
                os_log(.debug, "No recognition context for %@", anchorName)
                #endif
                
                return
            }
            
            node.name = self.activeRecognitionContext?.name
            
            guard let sensors = context.sensors else { return }
            self.nodeSensorCache[node.name!] = sensors
            
            self.showSensors(for: node)
        }
            
        let setupModelContext: () -> () = {
            #if DEBUG
            os_log(.debug, "Setting up model context for %@", anchorName)
            #endif
            
            // Updates to the node have to happen on the main thread
            DispatchQueue.main.async {
                // Insert model into view
                guard let assetNode = SCNScene(named: String(format: "art.scnassets/%@.scn", anchorObjFileName))?.rootNode.childNode(withName: anchorObjNodeName, recursively: false) else {
                    os_log(.error, "Unable to find 3D model for %@", anchorObjNodeName)
                    
                    // only display message if the recognition context is empty too.
                    // we do this check because the setup may be intended to omit a 3D model in the AR space.
                    if self.activeRecognitionContext == nil {
                        let alert = UIAlertController(title: "Error", message: "Unable to find the 3D model assets in the application.", preferredStyle: .alert)
                        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(action)
                        
                        DispatchQueue.main.async {
                            self.present(alert, animated: true, completion: {
                                self.resetScene()
                            })
                        }
                    }
                    
                    // If there is no 3d model, then set the recognition node as the node for context
                    self.setTappedNodeContext(node)
                    
                    return
                }
                
                self.activeNodeName = assetNode.name
                
                AppEventRecorder.shared.record(name: "AR Node Displayed", eventStart: Date(), eventEnd: nil, eventLength: 0.0, uiElement: nil, arAnchor: anchorName, arNode: assetNode.name, jsonString: nil, completion: nil)
                
                if let objectAnchor = anchor as? ARObjectAnchor {
                    assetNode.simdScale = objectAnchor.referenceObject.scale / 2
                    assetNode.simdPosition = objectAnchor.referenceObject.center
                    
                    assetNode.position.x = 0
                    assetNode.position.y = 0
                    assetNode.position.z = 0
                    
                    #if DEBUG
                    os_log(.debug, "Position: X (%.f5) Y (%.f5) X (%.f5)", assetNode.position.x, assetNode.position.y, assetNode.position.z)
                    #endif
                }
                else if let imageAnchor = anchor as? ARImageAnchor {
                    assetNode.position.z = Float(imageAnchor.referenceImage.physicalSize.height) * -1
                }
                
                // If the recognition context has properties that alter the default positions set above, then use them now.
                if let modelScale = self.activeRecognitionContext?.modelScale {
                    assetNode.scale = modelScale.getVector3()
                }
                if let modelRotation = self.activeRecognitionContext?.modelRotation {
                    assetNode.eulerAngles = modelRotation.getVector3Radians()
                }
                if let modelPosition = self.activeRecognitionContext?.modelPosition {
                    assetNode.position = modelPosition.getVector3()
                }
                
                self.nodesOriginatingPositions = [:]
                self.nodesOriginatingOpacities = [:]
                self.nodesOriginatingAngles = [:]
                
                // Save the original positions and opacities of all nodes so that we can reset the model to this state if the user moves parts around
                self.nodesOriginatingPositions?[assetNode.name!] = assetNode.position
                self.nodesOriginatingOpacities?[assetNode.name!] = assetNode.opacity
                self.nodesOriginatingAngles?[assetNode.name!] = assetNode.eulerAngles
                
                var saveNodePositions: ((SCNNode) -> ())!
                saveNodePositions = { node in
                    if let nodeName = node.name, nodeName != assetNode.name {
                        self.nodesOriginatingPositions?[nodeName] = node.position
                        self.nodesOriginatingOpacities?[nodeName] = node.opacity
                        self.nodesOriginatingAngles?[nodeName] = node.eulerAngles
                    }
                    
                    guard let childNodes = node.nonSensorChildNodes else { return }
                    
                    for childNode in childNodes {
                        saveNodePositions(childNode)
                    }
                }
                
                saveNodePositions(assetNode)
                
                // Add the node to view
                node.addChildNode(assetNode)
                
                self.setTappedNodeContext(assetNode)
            }
            
            // Show sensors after a delay to let node placement occur
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                os_log(.debug, "Showing Sensors")
                
                guard let activeNodeName = self.activeNodeName, let assetNode = self.sceneView.scene.rootNode.childNode(withName: activeNodeName, recursively: true) else {
                    #if DEBUG
                    os_log(.debug, "Could not find node for: %@", (self.activeNodeName ?? ""))
                    #endif
                    return
                }
                
                DispatchQueue.main.async {
                    self.showSensors(for: assetNode)
                }
            }
        }
        
        // Manages different behaviors between image and object recognition types.
        let handleRecognition: () -> () = {
            // Remove the "scan item" overlay image
            DispatchQueue.main.async {
                self.sceneView.overlaySKScene?.removeAllChildren()
                self.sceneView.overlaySKScene = nil
                self.setSensorTimerState(to: false)
            }
            
            // Perform specfic functions based on whether the anchor was image based or object based.
            if anchor is ARObjectAnchor {
                self.objectAnchorHandler(node: node, anchor: (anchor as! ARObjectAnchor))
            }
            else if anchor is ARImageAnchor {
                self.objectImageHandler(node: node, anchor: (anchor as! ARImageAnchor))
            }
            else {
                os_log(.error, "Anchor was neither an object nor image. Resetting AR scene.")
                self.resetScene()
                return
            }
            
            DispatchQueue.main.async {
                self.deviceRecognitionHandler(major: major, minor: minor, completion: {
                    DispatchQueue.main.async {
                        guard self.iotDevice != nil else { return }
                        
                        // Setup any content related to the object/image that was recognized
                        setupRecognitionContext()
                        
                        // Setup 3D models
                        setupModelContext()
                    }
                })
            }
        }
        
        // Disable beacon tracking if a visual recognition was found first
        self.blockBeaconAlerts = true
        
        handleRecognition()
    }
    
    // MARK: - Device Recognition Methods
    
    /**
     Method to handle common recognition tasks regardless of the source of the recognition (AR, iBeacons, etc.).
     If this method fails, then an error is presented and the scene is reset.
     
     - Parameter major: The major int of the recognition item.
     - Parameter minor: The minor int of the recognition item.
     - Parameter completion: Callback method called on successful device retrieval.
    */
    private func deviceRecognitionHandler(major: Int, minor: Int, completion: @escaping () -> ()) {
        // If a device request is already in process, then just drop this request
        guard !self.iotDeviceRequestInProcess else { completion(); return }
        
        let recognitionError: () -> () = {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Identification Error", message: "A recognition event occurred but we were unable to get the IoT device ID for the recognized item. Will reset the scene.", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: { (action) in
                    self.resetScene()
                })
                alert.addAction(action)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        let overlay = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateViewController(withIdentifier: "ActivityOverlayViewController") as? ActivityOverlayViewController
        if overlay != nil {
            overlay!.view.frame = self.view.frame
            self.addChild(overlay!)
            self.view.addSubview(overlay!.view)
            overlay!.setLabel("Getting Device Info")
        }
        
        guard let integrationBroker = (UIApplication.shared.delegate as! AppDelegate).integrationBroker else {
            recognitionError()
            completion()
            return
        }
        
        self.iotDeviceRequestInProcess = true
        
        // Query API for context data for recognized object/image model
        integrationBroker.getRecognitionContext(major: major, minor: minor, completion: { result in
            var context: ARRecognitionContext?
            
            switch result {
            case .success(let data):
                context = data
                break
            case .failure(let failure):
                failure.log()
                break
            }
            
            self.activeRecognitionContext = context
            
            // Get the device ID for the recognized minor record.
            integrationBroker.getUUIDsForRecognizedDevice(major: major, minor: minor, completion: { (result) in
                switch result {
                case .success(let tuple):
                    DispatchQueue.main.async {
                        integrationBroker.getDeviceInfo(tuple.1, completion: { (result) in
                            self.iotDeviceRequestInProcess = false
                            
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let device):
                                    overlay?.view.removeFromSuperview()
                                    overlay?.removeFromParent()
                                    self.iotApplicationId = tuple.0
                                    self.iotDevice = device
                                    
                                    // Show the application buttons
                                    buttonIf: if let vc = UIStoryboard(name: "ApplicationButtonContext", bundle: nil).instantiateViewController(withIdentifier: "ApplicationButtonsViewController") as? ApplicationButtonsViewController {
                                        guard !self.children.contains(where: { $0 is ApplicationButtonsViewController }) else { break buttonIf }
                                        
                                        self.addChild(vc)
                                        
                                        vc.delegate = self
                                        vc.moveFrameOutOfView()
                                        
                                        self.view.insertSubview(vc.view, at: 0)
                                        
                                        vc.resizeForContent(self.defaultDuration, completion: nil)
                                    }
                                    
                                    completion()
                                    break
                                case .failure(let failure):
                                    failure.log()
                                    recognitionError()
                                    break
                                }
                            }
                        })
                    }
                    
                    break
                case .failure(let failure):
                    failure.log()
                    recognitionError()
                    break
                }
            })
        })
    }
    
    /**
     Can be called when an iBeacon is recognized to set the recognition context based on a beacon.
     
     - Parameter major: The major int of the recognition item.
     - Parameter minor: The minor int of the recognition item.
     - Parameter completion: Callback method called on successful device retrieval.
     */
    func iBeaconRecognitionHandler(major: Int, minor: Int, completion: (() -> ())?) {
        // Ensure that we will offer beacon notices
        guard !self.blockBeaconAlerts else { return }
        
        // Ensure that we have server configs before trying to recognize items
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let configs = appDelegate.appServerConfigs, !configs.gettingServerConfigs else { return }
        
        // Ensure there are no overlays on top of the view now
        guard !self.children.contains(where: { $0 is OverlayViewController }) else { return }
        
        // If a device is already active in the UI, then do not proceed.
        guard self.iotDevice == nil else { return }
        
        self.blockBeaconAlerts = true
        
        //TODO: Update UI by displaying which devices are near and allowing the user to select a given device.
        self.deviceRecognitionHandler(major: major, minor: minor) {
            guard let device = self.iotDevice, let deviceId = device.id else { return }
            guard let recognitionContext = self.activeRecognitionContext else { return }
            guard let deviceModel = device.deviceModels?.first(where: { $0.system != nil && $0.system! == false }), let deviceModelName = deviceModel.name else { return }
            
            let alert = UIAlertController(title: "Beacon Found", message: String(format: "A beacon for device %@ with id %@ was found. Would you like to view its details now?", deviceModelName, deviceId), preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) in
                let emptyNode = SCNNode()
                // The recognition node should not share the same name as the root node of the model
                // We address this by adding "_recognition" to the end of the recognition node names.
                // Remove that here so that we can "fake" finding the AR object based on the beacon and display
                // the object data even though the AR recognition has not happened.
                if let nodeName = recognitionContext.nodeName() {
                    emptyNode.name = String(nodeName)
                    self.setTappedNodeContext(emptyNode)
                }
                
                self.blockBeaconAlerts = false
            })
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                self.iotDevice = nil
                self.iotApplicationId = nil
            })
            alert.addAction(ok)
            alert.addAction(cancel)
            
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - AR and Scene Methods
    
    /**
     Method for setting up the image tracking configuration.
     
     - Parameter resetTracking: Flag to indicate if any existing tracking should be removed from the AR session.  Will also display the placement image if set to true.
     */
    private func setTrackingConfiguration(_ resetTracking: Bool = true) {
        // Setup tracking configuration
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil), let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "AR Resources", bundle: nil) else {
            os_log(.error, "Could not find any tracking images in AR Resources")
            return
        }
        
        #if DEBUG
        os_log(.debug, "%d reference images for AR detection available.", referenceImages.count)
        os_log(.debug, "%d reference objects for AR detection available.", referenceObjects.count)
        #endif
        
        var configuration: ARConfiguration!
        var imageTrack = true
        
        if let config = UserDefaults.standard.string(forKey: "recognition_type"), config != "image" {
            imageTrack = false
        }
        
        if imageTrack {
            configuration = ARImageTrackingConfiguration()
            (configuration as! ARImageTrackingConfiguration).trackingImages = referenceImages
            (configuration as! ARImageTrackingConfiguration).maximumNumberOfTrackedImages = 1
            (configuration as! ARImageTrackingConfiguration).isAutoFocusEnabled = true
            
            #if DEBUG
            os_log(.debug, "Using image tracking")
            #endif
        } else {
            configuration = ARWorldTrackingConfiguration()
            (configuration as! ARWorldTrackingConfiguration).detectionObjects = referenceObjects
            
            #if DEBUG
            os_log(.debug, "Using object tracking")
            #endif
        }
        
        var options: ARSession.RunOptions = []
        
        if resetTracking {
            #if DEBUG
            os_log(.debug, "Reset tracking flag is true")
            #endif
            
            options = [.removeExistingAnchors, .resetTracking]
            
            // Show the placement image scene so the user knows what to do.
            DispatchQueue.main.async {
                let contextControllers = self.children.filter({ $0 is ContextViewController })
                for controller in contextControllers {
                    let contextController = controller as! ContextViewController
                    contextController.removeView(completion: nil)
                }
                
                if let loadingController = self.children.first(where: { $0 is ActivityOverlayViewController}) as? ActivityOverlayViewController {
                    loadingController.view.removeFromSuperview()
                    loadingController.removeFromParent()
                }
                
                self.showPlacementImageScene()
                
                self.blockBeaconAlerts = false
            }
        }
        
        if ARConfiguration.isSupported {
            DispatchQueue.main.async {
                self.sceneView.session.run(configuration, options: options)
            }
        } else {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "ARKit Not Supported", message: "Your device does not support ARKit. Ensure that you are using an iOS device that has an A9 processor or newer.", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(action)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    /// Method for displaying the placement scene as a HUD
    private func showPlacementImageScene() {
        #if DEBUG
        os_log(.debug, "Showing placement scene")
        #endif
        
        if self.sceneView.overlaySKScene == nil {
            self.sceneView.overlaySKScene = SKScene(size: CGSize(width: self.view.frame.size.width, height: self.view.frame.size.height))
            self.sceneView.overlaySKScene?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.sceneView.overlaySKScene?.scaleMode = .aspectFill
        }
        
        guard let placementImageScene = self.imagePlacementScene?.copy() as? SKScene else {
            os_log(.error, "Error getting image placement scene!")
            return
        }
        placementImageScene.delegate = self
        placementImageScene.isUserInteractionEnabled = false
        
        for node in placementImageScene.children {
            let copy = node.copy() as! SKNode
            
            self.sceneView.overlaySKScene?.addChild(copy)
        }
        
        let viewFrameWidth = self.view.frame.size.width - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right
        let viewFrameHeight = self.view.frame.size.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom
        
        DispatchQueue.main.async {
            self.sizeOverlayNodes(widthComparison: viewFrameWidth, heightComparison: viewFrameHeight)
        }
    }
    
    /**
     Method to perform setup options for the model node(s) when the recognition type was object-based.
     
     - Parameter node: The node that the anchor was placed in.
     - Parameter anchor: The AR anchor that was recognized.
    */
    private func objectAnchorHandler(node: SCNNode, anchor: ARObjectAnchor) {
        #if DEBUG
        os_log(.debug, "Object detection anchor found")
        #endif
    }
    
    /**
     Method to perform setup options for the model node(s) when the recognition type was image-based.
     
     - Parameter node: The node that the anchor was placed in.
     - Parameter anchor: The AR anchor that was recognized.
     */
    private func objectImageHandler(node: SCNNode, anchor: ARImageAnchor) {
        #if DEBUG
        os_log(.debug, "Image detection anchor found")
        #endif
        
        DispatchQueue.main.async {
            let referenceImage = anchor.referenceImage
            guard let imageName = referenceImage.name else {
                os_log(.error, "Reference image did not have a name that we could use to map to a scene file.")
                return
            }
            
            #if DEBUG
            os_log(.debug, "Found reference image: %@", imageName)
            #endif
            
            // Push the model to the back of the placement image so that the camera can track the image and display the model at the same time.
            let zPosition = -Float(referenceImage.physicalSize.height)
            node.position.z = zPosition * -1
            
            // Highlight the found image with a pulsing plane
            let plane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.20
            planeNode.eulerAngles.x = -.pi / 2
            
            node.addChildNode(planeNode)
            
            planeNode.runAction(.sequence([.pulsingAlpha(duration: 1), .fadeOut(duration: self.defaultDuration)])) {
                DispatchQueue.main.async {
                    planeNode.removeFromParentNode()
                }
            }
        }
    }
    
    /**
     Method to remove all AR elements from the view and reset the experience.
     
     - Parameter resetUI: When true, will completely reset the UI of the experience.  When false, resets only values.
     */
    func resetScene(_ resetUI: Bool = true) {
        // Remove highlighting from tapped node to prevent node technique error on reset
        self.tappedNode?.setHighlighted(false)
        
        // Disable timers and remove UI elements
        self.setSensorTimerState(to: false)
        self.nodesOriginatingPositions = nil
        self.nodesOriginatingOpacities = nil
        self.nodesOriginatingAngles = nil
        self.tappedNode = nil
        
        // Reconfigure tracking and overlay UI
        self.animatingParts = false
        self.partsExposed = false
        self.activeNodeName = nil
        
        if resetUI {
            self.pauseAllActions()
            
            self.blockBeaconAlerts = false
            
            // Remove the reference to the recognized device
            self.iotDevice = nil
            self.iotApplicationId = nil
            
            // Reset AR Tracking
            DispatchQueue.main.async {
                self.setTrackingConfiguration()
            }
        }
    }
    
    /**
     Helper method to animate the appearance of a UIKit overlay view since a Navigation Controller would reset the AR experience.
     
     - Parameter view: The view to slide into display over the AR experience.
     - Parameter completion: Completion called when the animation has completed.
    */
    func slideInView(_ view: UIView, completion: (() -> ())? = nil) {
        DispatchQueue.main.async {
            view.frame.origin.y = self.view.frame.height
            self.view.addSubview(view)
            
            UIView.animate(withDuration: 0.25, animations: {
                var newFrame = view.frame
                newFrame.origin.y = 0
                view.frame = newFrame
            }) { (completed) in
                completion?()
            }
        }
    }
    
    /**
     Helper method to animate the disappearance of a UIKit overlay view since a Navigation Controller would reset the AR experience.
     
     - Parameter view: The view to slide out of display over the AR experience.
     - Parameter completion: Completion called with the animation has completed.
     */
    private func slideOutView(_ view: UIView, completion: (() -> ())? = nil) {
        DispatchQueue.main.async {
            guard self.view.subviews.contains(view) else { return }
            
            UIView.animate(withDuration: 0.25, animations: {
                var newFrame = view.frame
                newFrame.origin.y = view.frame.height
                view.frame = newFrame
            }) { (completed) in
                view.removeFromSuperview()
                completion?()
            }
        }
    }
    
    /**
     Will replace a default material with the highlight material for a SCNNode.
     
     - Parameter node: The node to update.
     */
    private func highlightMaterials(_ node: SCNNode) {
        guard let hm = node.geometry?.material(named: "HighlightMaterial"), let dm = node.geometry?.material(named: "DefaultMaterial") else { return }
        node.geometry?.replaceMaterial(at: 1, with: dm)
        node.geometry?.replaceMaterial(at: 0, with: hm)
        
        node.geometry?.firstMaterial?.transparency = 1
        node.opacity = 1
    }
    
    /**
     Will replace a highlight material with the default material for a SCNNode.
     
     - Parameter node: The node to update.
     */
    private func resetMaterials(_ node: SCNNode) {
        guard let hm = node.geometry?.material(named: "HighlightMaterial"), let dm = node.geometry?.material(named: "DefaultMaterial") else { return }
        node.geometry?.replaceMaterial(at: 1, with: hm)
        node.geometry?.replaceMaterial(at: 0, with: dm)
        
        node.geometry?.firstMaterial?.transparency = 1
        node.opacity = 1
    }
    
    /**
     Sets contextual information in the view based on the node that was tapped.
     
     - Parameter node: The node to update.
     */
    private func setTappedNodeContext(_ node: SCNNode) {
        // No need to do anything else if the tapped node is the same as the previously tapped node.
        guard node != self.tappedNode else { return }
        
        // Ensure that the device id is set
        guard let deviceId = self.iotDevice?.id else { return }
        guard let appId = self.iotApplicationId else { return }
        
        // Ensure that the node has a name and that it is different than the currently selected node.
        guard let nodeName = node.name, (self.tappedNode == nil || nodeName != self.tappedNode?.name) else {
            os_log(.info, "Node does not have a name. Cannot set context.")
            return
        }
        
        let applyContext: (SCNNode) -> () = { node in
            // Set the newly tapped node
            self.tappedNode = node
            
            node.setHighlighted()
            
            // Add the context view if it is not in view
            var contextController = self.children.first(where: { $0 is NodeContextViewController }) as? NodeContextViewController
            if contextController == nil {
                let nodeContextStoryboard = UIStoryboard(name: "NodeContext", bundle: nil)
                guard let contextViewController = nodeContextStoryboard.instantiateViewController(withIdentifier: "NodeContextViewController") as? NodeContextViewController else { return }
                
                contextViewController.delegate = self
                self.addChild(contextViewController)
                self.view.insertSubview(contextViewController.view, at: 0) // place at the bottom of the view stack in case overlay controllers are displayed.
                
                contextController = contextViewController
            }
            
            contextController?.setNode(name: nodeName, device: deviceId, appId: appId)
            
            guard let srHistoryButton = contextController?.srHistoryButton,
                let noteHistoryButton = contextController?.noteHistoryButton,
                let threeDPrintButton = contextController?.threeDPrintButton,
                let orderButton = contextController?.orderButton else {
                    os_log(.error, "Could not get node buttons")
                    return
            }
            
            contextController?.addActionButton(srHistoryButton)
            
            //TODO: Add notes function for Engagement Cloud.
            // Until then, only add the notes button when we're using service cloud.
            if (UIApplication.shared.delegate as? AppDelegate)?.appServerConfigs?.serverConfigs?.service?.application == .serviceCloud {
                contextController?.addActionButton(noteHistoryButton)
            }
            
            contextController?.addActionButton(threeDPrintButton)
            contextController?.addActionButton(orderButton)
            
            // Retrieve any remote data related to this node for display (sensors, etc.)
            guard let nodeName = node.name else { return }
            
            let showSensorButton: () -> () = {
                // Add the action button to hide/show sensors if there are sensors associated with this node.
                if let sensorsButton = contextController?.sensorsButton {
                    // We assume that the sensors are related to the parent node.  Would need new logic if sensors apply to certian parts.
                    contextController?.addActionButton(sensorsButton, at: 0)
                }
                
                self.showSensors(for: node)
            }
            
            if self.nodeSensorCache[nodeName] == nil {
                (UIApplication.shared.delegate as? AppDelegate)?.integrationBroker?.getNodeData(nodeName: nodeName, completion: { (result) in
                    switch result {
                    case .success(let data):
                        guard let sensors = data.sensors else { return }
                        self.nodeSensorCache[nodeName] = sensors
                        
                        DispatchQueue.main.async {
                            showSensorButton()
                        }
                        
                        break
                    default:
                        os_log(.error, "Could not get sensors for %@", nodeName)
                        break
                    }
                })
            }
            else {
                showSensorButton()
            }
            
            // Check to see if any procedures were passed to automatically start at launch time to start when this node is selected.
            guard let params = (UIApplication.shared.delegate as? AppDelegate)?.openUrlParams else { return }
            guard let openProcedureName = params["procedure"]?.removingPercentEncoding?.lowercased() else { return }
            guard contextController?.arNodeContext?.procedures != nil else { return }
            guard let procedure = contextController!.arNodeContext!.procedures!.first(where: { $0.name.lowercased() == openProcedureName }) else { return }
            
            self.proceduresHandler(contextController, procedure: procedure, completion: nil)
            
            // Remove the procedure key so that it is not run again if the user selects the node with the assigned procedure.
            (UIApplication.shared.delegate as? AppDelegate)?.openUrlParams?.removeValue(forKey: "procedure")
        }
        
        DispatchQueue.main.async {
            if let tappedNode = self.tappedNode {
                self.removeTappedNodeContext(tappedNode, removeContextView: false, completion: {
                    DispatchQueue.main.async {
                        applyContext(node)
                    }
                })
            } else {
                applyContext(node)
            }
        }
    }
    
    /**
     Removes the contextual information for a node once it is no longer the actively tapped node.
     
     - Parameter node: The node to update.
     - Parameter removeContextView: Flag indicating if the context view should be removed from view. Usually this is yes unless the tappedNodeContext method is swithing contexts.
     - Parameter completion: A callback called once the context controller is removed.
     */
    private func removeTappedNodeContext(_ node: SCNNode, removeContextView: Bool = true, completion: (() -> ())?) {
        node.setHighlighted(false)
        
        guard removeContextView, let contextViewController = self.children.first(where: { $0 is NodeContextViewController }) as? NodeContextViewController else {
            completion?()
            return
        }
        
        contextViewController.removeView(completion: {
            completion?()
        })
    }
    
    /**
     Scales the scene's overlay nodes to the boundaries of the visible area.
     
     - Parameter widthComparison: Width value to test against.
     - Parameter heightComparison: Height value to test against.
    */
    private func sizeOverlayNodes(widthComparison: CGFloat, heightComparison: CGFloat) {
        guard let overlay = self.sceneView.overlaySKScene else { return }
        
        for node in overlay.children {
            #if DEBUG
            os_log(.debug, "View Frame Size: Width (%.5f) height (%.5f)", self.view.frame.size.width, self.view.frame.size.height)
            os_log(.debug, "Node Frame Size: Width (%.5f) height (%.5f)", node.calculateAccumulatedFrame().size.width, node.calculateAccumulatedFrame().size.height)
            #endif
            
            var scale = node.xScale
            
            // Reverse checks between width and height since this method is called before the transition takes place
            repeat {
                if node.calculateAccumulatedFrame().size.width > widthComparison || node.calculateAccumulatedFrame().size.height > heightComparison {
                    scale = scale - 0.1
                }
                
                node.xScale = scale
                node.yScale = scale
            } while node.calculateAccumulatedFrame().size.width > widthComparison || node.calculateAccumulatedFrame().size.height > heightComparison
        }
    }
    
    // MARK: - Overlay Display Methods

    /// Prepares the SR overlay with IoT data and then displays it.
    private func showSrOverlay() {
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil else { return }
        
        //Ensure that only one overlay view is visible at a time.
        
        guard let vc = UIStoryboard(name: "ServiceRequest", bundle: nil).instantiateViewController(withIdentifier: "ServiceRequestSplitViewController") as? ServiceRequestSplitViewController else {
            return
        }
        
        vc.overlayDelegate = self
        vc.applicationId = self.iotApplicationId
        vc.iotDevice = self.iotDevice
        vc.lastSensorMessage = self.lastSensorMessage
        vc.selectedPart = self.tappedNode?.name ?? self.activeRecognitionContext?.name // Use the recognition context as the part if there is no actively tapped node
        vc.screenshot = self.sceneView.snapshot()
        
        self.addChild(vc)
        self.overlayViewController = vc
        self.slideInView(vc.view)
        
        // Stop the timer when in background
        self.setSensorTimerState(to: false)
    }
    
    // MARK: - Procedures Methods
    
    /**
     Displays the procedure view and sets up the AR experience based on the parameters defined in the procedure.
     
     - Parameter procedure: The procedure that will be displayed.
     */
    private func showProcedure(_ procedure: ARProcedure) {
        let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController
        
        guard proceduresViewController == nil, let vc = UIStoryboard(name: "Procedures", bundle: nil).instantiateViewController(withIdentifier: "ProceduresViewController") as? ProceduresViewController else { return }
        
        self.gesturesEnabled = procedure.interactionNodes != nil && procedure.interactionNodes!.count > 0
        
        vc.delegate = self
        vc.setProcedure(procedure)
        
        self.addChild(vc)
        
        DispatchQueue.main.async {
            self.view.addSubview(vc.view)
        }
    }
    
    /**
     Adds an AR attribute (content from a SpriteKit file in 2D space) to a SCNNode.  This method is used during procedure animations to help direct the user for interacting with the real-world object.
     
     - Parameter nodeNames: An array of nodes to apply the attribute to.  This will search the scene's node tree for nodes with the applicable name.
     - Parameter attibutions: An array of attributes to apply to the node.
     */
    private func addAttributesToSceneNodes(_ nodeNames: [String], attributes: [ARAnimation.Attribute]) {
        // Get nodes that were listed for attribute
        var nodes: [SCNNode] = []
        
        for nodeName in nodeNames {
            guard let node = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else { continue }
            nodes.append(node)
        }
        
        // Find the scenes for attribute and apply them to nodes
        for attribute in attributes {
            #if DEBUG
            os_log(.debug, "Adding attribute: %@", attribute.name)
            #endif
            
            guard let sceneFrame = attribute.sceneFrame else { return }
            guard let image = attribute.image?.getImage() else { continue }
            
            // Setup the spritekit scene
            let attributeScene = SKScene(size: sceneFrame.getCGFrame())
            attributeScene.backgroundColor = .clear
            attributeScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            
            // create a shape node to draw the attribute image
            let shapeNode = SKShapeNode(rectOf: sceneFrame.getCGFrame())
            shapeNode.name = "attributeNode"
            shapeNode.xScale = 1
            shapeNode.yScale = 1
            shapeNode.strokeColor = .clear
            shapeNode.fillColor = .white
            shapeNode.lineWidth = 1
            shapeNode.alpha = 1
            
            // apply the image as a texture to the shapenode
            let texture = SKTexture(image: image)
            shapeNode.fillTexture = texture
            
            // add the shapenode to the scene
            attributeScene.addChild(shapeNode)
            
            for node in nodes {
                let plane = SCNPlane(width: CGFloat(sceneFrame.width), height: CGFloat(sceneFrame.height))
                let scale = attribute.scale != nil ? attribute.scale!.getVector3() : SCNVector3(1, 1, 1)
                let eulerAngles = attribute.eulerAngles != nil ? attribute.eulerAngles!.getVector3Radians() : SCNVector3(0, 0, 0)
                let position = attribute.position != nil ? attribute.position!.getVector3() : SCNVector3(0, 0.2, 0)
                
                self.createPlaneNodeForSpriteInScene(newNodeName: attribute.name, plane: plane, spriteKitScene: attributeScene, scale: scale, eulerAngles: eulerAngles, isFacingUser: false) { (newNode) in
                    #if DEBUG
                    os_log("Adding attribute node (%@) to %@", newNode.name!, node.name!)
                    #endif
                    
                    newNode.opacity = 1
                    newNode.isPaused = false
                    newNode.position = position
                    
                    node.addChildNode(newNode)
                }
            }
        }
    }
    
    /**
     Removes any immediate child nodes with the term "Attribute" in the child node name.
     
     - Parameter parentNodeName: the name of the parent node to search for attribute child nodes.
     - Parameter attributes: An array of attribute objects to remove from the given node.
     */
    private func removeAttributeChildNodes(_ parentNodeName: String, attributes: [ARAnimation.Attribute]) {
        guard let parentNode = self.sceneView.scene.rootNode.childNode(withName: parentNodeName, recursively: true) else { return }
        
        for attribute in attributes {
            let removeAttribute = attribute.removeAttributesAfterAnimation ?? true
            guard removeAttribute == true, let node = parentNode.childNode(withName: attribute.name, recursively: false) else { continue }
            node.removeFromParentNode()
        }
    }
    
    // MARK: - Sensor Methods
    
    /**
     Method to place sensors in the view of the user.
     
     - Parameter node: The node to query for sensors and display
     */
    private func showSensors(for node: SCNNode) {
        guard let nodeName = node.name else { return }
        
        #if DEBUG
        os_log(.debug, "Showing sensors for node: %@", nodeName)
        #endif
        
        if let sensors = self.nodeSensorCache[nodeName] {
            // Show sensors from the background thread
            DispatchQueue.global(qos: .userInteractive).async {
                for sensor in sensors {
                    guard let sensorName = sensor.name else { return }
                    
                    let sensorNodeName = String(format: "%@_SensorNode", sensorName.replacingOccurrences(of: " ", with: "_"))
                    
                    // If the node already contains a sensor with this name, then no need to add again
                    if let _ = node.childNode(withName: sensorNodeName, recursively: true) { continue }
                    
                    // If not, then contruct a spritekit node that can be applied to the materials of a scenekit node for display in AR
                    guard let sceneFrame = sensor.sceneFrame else { return }
                    
                    let sensorScene = sensor.background?.type == .video ? VideoScene(size: sceneFrame.getCGFrame()) : SKScene(size: sceneFrame.getCGFrame())
                    sensorScene.backgroundColor = .clear
                    sensorScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    var wrapperNode: SKNode?
                    
                    if let background = sensor.background, let backgroundType = background.type {
                        switch backgroundType {
                        case .image:
                            let shapeNode = SKShapeNode(rectOf: sceneFrame.getCGFrame())
                            shapeNode.name = "sensorWrapper"
                            shapeNode.xScale = 1
                            shapeNode.yScale = 1
                            shapeNode.strokeColor = .clear
                            shapeNode.fillColor = .white
                            shapeNode.lineWidth = 1
                            shapeNode.alpha = 1
                            
                            guard let image = background.image?.getImage() else { continue }
                            let texture = SKTexture(image: image)
                            
                            shapeNode.fillTexture = texture
                            
                            wrapperNode = shapeNode
                            break
                        case .video:
                            guard let videoName = sensor.background?.video else { continue }
                            let nameParts = videoName.components(separatedBy: ".")
                            guard nameParts.count == 2, let fileUrl = Bundle.main.url(forResource: nameParts[0], withExtension: nameParts[1]) else { return }
                            
                            let player = AVPlayer(url: fileUrl)
                            player.volume = 0
                            
                            let videoNode = SKVideoNode(avPlayer: player)
                            videoNode.name = "videoNode"
                            videoNode.play()
                            
                            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { notification in
                                player.seek(to: CMTime.zero)
                                player.play()
                            }
                            
                            (sensorScene as! VideoScene).videoPlayer = player
                            (sensorScene as! VideoScene).videoNode = videoNode
                            
                            wrapperNode = videoNode
                            break
                        }
                    }
                    
                    // ensure that the wrapper node was created
                    guard wrapperNode != nil else { continue }
                    
                    // create a label node
                    let labelNode = SKLabelNode(text: sensor.label?.text)
                    labelNode.name = "sensorLabel"
                    labelNode.color = sensor.label?.font?.color != nil ? sensor.label!.font!.color!.getUIColor() : .white
                    labelNode.fontColor = sensor.label?.font?.color != nil ? sensor.label!.font!.color!.getUIColor() : .white
                    labelNode.fontSize = sensor.label?.font?.size != nil ? sensor.label!.font!.size! : 32.0
                    labelNode.fontName = sensor.label?.font?.name != nil ? sensor.label!.font!.name! : "HelveticaNeue-Light" //see http://iosfonts.com/
                    labelNode.position = sensor.label?.position != nil ? sensor.label!.position!.getPoint() : CGPoint(x: 0, y: 0)
                    labelNode.zRotation = sensor.label?.rotation != nil ? CGFloat(sensor.label!.rotation!) : CGFloat(0)
                    
                    wrapperNode!.addChild(labelNode)
                    
                    sensorScene.addChild(wrapperNode!)
                    
                    let planeSize = sensor.sensorPlane?.getPlane() ?? SCNPlane(width: 1.0, height: 1.0)
                    let scale = sensor.scale?.getVector3() ?? SCNVector3(1, 1, 1)
                    let alwaysFacingUser = sensor.alwaysFaceViewPort ?? false
                    let angles = sensor.eulerAngles?.getVector3Radians() ?? SCNVector3(0, 0, -Double.pi)
                    
                    self.createPlaneNodeForSpriteInScene(newNodeName: sensorNodeName, plane: planeSize, spriteKitScene: sensorScene, scale: scale, eulerAngles: angles, isFacingUser: alwaysFacingUser, completion: { (planeNode) in
                        #if DEBUG
                        let nodeName = planeNode.name ?? ""
                        os_log(.debug, "Adding node: %@", nodeName)
                        #endif
                        
                        planeNode.scale = scale
                        planeNode.opacity = 0
                        planeNode.position = sensor.position?.getVector3() ?? SCNVector3(0, 0, 0)
                        planeNode.isPaused = false
                        
                        node.addChildNode(planeNode)
                        
                        planeNode.runAction(.fadeIn(duration: self.defaultDuration))
                    })
                }
            }
            
            // Assign timer on main thread so that it remains in this object's scope
            DispatchQueue.main.async {
                self.setSensorTimerState(to: true)
            }
        }
    }
    
    /**
     Removes sensors from the node structure of the supplied node.
     
     - Parameter node: The node to inspect for sensors
     */
    private func hideSensors(for node: SCNNode) {
        guard let nodeName = node.name else { return }
        
        #if DEBUG
        os_log(.debug, "Removing sensors for node: %@", nodeName)
        #endif
        
        for childNode in node.childNodes {
            if let nodeName = childNode.name, nodeName.contains("_SensorNode") {
                childNode.runAction(.fadeOut(duration: 0.1)) {
                    childNode.removeFromParentNode()
                }
            }
        }
    }
    
    /**
     Creates a new plane node for a 2D sensor scenekit scene and wrapes it in a SCNNode for display in 3D space.
     
     - Parameter newNodeName: The name to apply to the new scenekit node that is created.
     - Parameter plane: The plane object on which to apply the scenekit scene.
     - Parameter spriteKitScene: The spriteKit scene to apply to the sceneKit plane.
     - Parameter scale: The scale of the scenekit object.
     - Parameter eulerAngles: Euler angles to apply to the node.
     - Parameter isFacingUser: Flag to indicate if the look at contraint should be applied to this node with gimbal lock.  This keeps planes like sensors facing the user.
     - Parameter completion: A callback that passes the newly created node as a paramter.
     - Parameter node: The node returned from the callback.
     
     - Returns: The node that was created with the sprite scene.
     */
    private func createPlaneNodeForSpriteInScene(newNodeName: String, plane: SCNPlane, spriteKitScene: SKScene, scale: SCNVector3, eulerAngles: SCNVector3 = SCNVector3(0, 0, -Double.pi), isFacingUser: Bool = true, completion: @escaping (_ node: SCNNode) -> ()) {
        DispatchQueue.global(qos: .userInteractive).async {
            // this is a wrapper for the latter "sceneKitNode" which is required to make the sensor appear right-side-up when look constraints are on.
            let newNode = SCNNode()
            newNode.name = newNodeName
            
            //Create plane geometry
            plane.name = plane.name ?? String(format: "%@_Plane", newNodeName)
            
            //Set SpriteKit scene on the plane's material
            plane.firstMaterial?.diffuse.contents = spriteKitScene
            
            //If material double-sided, SpriteKit scene will show up on both sides of the plane
            plane.firstMaterial?.isDoubleSided = true
            
            //Create a SceneKit node for the plane
            let sceneKitNode = SCNNode(geometry: plane)
            sceneKitNode.eulerAngles = eulerAngles
            sceneKitNode.name = String(format: "%@_MaterialNode", newNodeName)
            
            //Add the Scenekit node to the SceneKit scene
            newNode.addChildNode(sceneKitNode)
            newNode.scale = scale
            
            if isFacingUser {
                //Create look at constraint so that the guages are always facing the view
                let lookAtConstraint = SCNLookAtConstraint(target: self.sceneView.pointOfView)
                lookAtConstraint.isGimbalLockEnabled = true
                newNode.constraints = [lookAtConstraint]
            }
            
            completion(newNode)
        }
    }

    /// Method that sets the text values on the sensor nodes.  This is required, as opposed to using the SensorScene methods, because the nodes have been removed from the spritekit scenes and placed in this scenekit scene.
    private func updateSensorTextNodes() {
        // Will cause a bad thread access if run on background thread
        DispatchQueue.main.async {
            guard let lastSensorMessage = self.lastSensorMessage, let sensorData = lastSensorMessage.payload?.data else {
                os_log(.error, "Cannot update text nodes since there is no sensor data")
                return
            }
            
            guard let selectedNode = self.tappedNode, let nodeName = selectedNode.name else {
                os_log(.info, "No node selected to update sensors for.")
                return
            }
            
            guard let sensors = self.nodeSensorCache[nodeName] else { return }
            
            for sensor in sensors {
                guard let sensorName = sensor.name else { return }
                if let val = sensorData[sensorName] {
                    let sensorNodeWithSKMaterialName = String(format: "%@_SensorNode_MaterialNode", sensorName)
                    
                    guard let scene = selectedNode.childNode(withName: sensorNodeWithSKMaterialName, recursively: true)?.geometry?.firstMaterial?.diffuse.contents as? SKScene else {
                        os_log(.error, "No node with name '%@' in scene", sensorNodeWithSKMaterialName)
                        continue
                    }
                    
                    guard let sensorValue = Double("\(val)") else {
                        #if DEBUGIOT
                        os_log(.debug, "Count not convert %.f5 to a Double", val)
                        #endif
                        
                        continue
                    }
                    
                    guard let wrapper = scene.childNode(withName: "//sensorWrapper") as? SKShapeNode, let label = wrapper.childNode(withName: "//sensorLabel") as? SKLabelNode else {
                        #if DEBUGIOT
                        os_log(.debug, "Cannot find sensor label for %@", sensorName)
                        #endif
                        
                        continue
                    }
                    
                    #if DEBUGIOT
                    os_log(.debug, "Updating %@: %.f5", sensorName, val)
                    #endif
                    
                    let textFormat = sensor.label?.formatter ?? "%@"
                    label.text = String(format: textFormat, sensorValue)
                    
                    guard let min = sensor.operatingLimits?.min, let max = sensor.operatingLimits?.max else { return }
                    
                    if sensorValue < min || sensorValue > max {
                        wrapper.fillColor = .red
                    } else {
                        wrapper.fillColor = UIColor(white: 1.0, alpha: 1.0)
                    }
                }
            }
        }
    }
    
    /**
     Handler method for reacting to a sensor tap in the AR experience.
     
     - Parameter node: The sensor node.
     */
    private func sensorTapped(_ node: SCNNode) {
        #if DEBUG
        os_log(.debug, "Item is a sensor. Checking actions.")
        #endif
        
        guard let nodeName = node.name else { return }
        
        let strSplit = nodeName.components(separatedBy: "_Sensor")
        let sensorName = strSplit[0]
        guard let sensorParent = node.parent?.parent else { return } // SensorNodePlane then parent
        guard let parentName = sensorParent.name else { return }
        guard let sensors = self.nodeSensorCache[parentName] else { return }
        guard let sensor = sensors.first(where: { $0.name == sensorName }) else { return }
        guard let sensorActionType = sensor.action?.type else { return }
        
        #if DEBUG
        os_log(.debug, "Sensor Action: %@", sensorActionType.rawValue)
        #endif
        
        switch sensorActionType {
        case .lineChart:
            #if DEBUG
            os_log(.debug, "Displaying line chart")
            #endif
            
            guard let navVc = UIStoryboard(name: "Charts", bundle: nil).instantiateInitialViewController() as? OverlayNavigationController, let vc = navVc.children.first as? LineChartViewController, let deviceId = self.iotDevice?.id, let appId = self.iotApplicationId else { return }
            
            vc.title = String(format: "%@ Data", sensor.name!)
            vc.applicationId = appId
            vc.deviceId = deviceId
            vc.sensor = sensor
            
            navVc.overlayDelegate = self
            self.addChild(navVc)
            self.overlayViewController = navVc
            
            self.slideInView(navVc.view)
            
            // Stop the timer when in background
            self.setSensorTimerState(to: false)
            
            self.sceneView.session.pause()
            
            break
        case .url:
            guard let urlStr = sensor.action?.url, let url = URL(string: urlStr) else { return }
            #if DEBUG
            os_log(.debug, "Opening URL")
            #endif
            
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            
            break
        case .volume:
            guard let scene = node.geometry?.firstMaterial?.diffuse.contents as? VideoScene else {
                os_log(.info, "No SKScene applied to node as material")
                return
            }
            
            guard let player = scene.videoPlayer else { return }
            
            // If the volume is 0, reset the video and play from start
            if player.volume == 0 {
                player.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
                player.volume = 1
                player.play()
            } else {
                player.volume = 0
            }
            
            break
        }
    }
    
    /**
     Will remove any tapped context and pause the AR view and timer.
     This is primarily used when the app closes to stop AR actions on shutdown or when the scene is reset but we don't want to call this controller's reset method which will START actions after the reset.
     */
    func pauseAllActions() {
        DispatchQueue.main.async {
            self.setSensorTimerState(to: false)
            
            self.sceneView.session.pause()
            
            self.sceneView.overlaySKScene?.removeAllChildren()
            
            self.sceneView.scene.rootNode.enumerateChildNodes () { (node, _) in
                node.removeFromParentNode()
            }
            
            // Remove any context controllers
            let contextControllers = self.children.filter({ $0 is ContextViewController })
            for controller in contextControllers {
                let contextController = controller as! ContextViewController
                
                contextController.removeView(completion: nil)
            }
        }
    }
    
    // MARK: - IoT Methods
    
    /**
     Method to set and start/stop a timer to get IoT device messages.
     
     - Parameter on: Flag to turn the state on or off.
     */
    func setSensorTimerState(to on: Bool) {
        #if DEBUG
        os_log(.debug, "Setting sensor state: %@", on ? "on" : "off")
        #endif
        
        self.sensorTimer?.invalidate()
        self.sensorTimer = nil
        
        // If the state is off, then there is nothing more to do.
        guard on else { return }
        
        let userDefaultsInterval = UserDefaults.standard.double(forKey:  SensorConfigs.sensorRequestInterval.rawValue)
        let interval: Double = userDefaultsInterval >= 2.5 ? userDefaultsInterval : 5.0
        self.sensorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { (timer) in
            if !self.iotMessageRequestInProcess {
                #if DEBUGIOT
                os_log(.debug, "Starting sensor request process.")
                #endif
                guard let applicationId = self.iotApplicationId, let deviceId = self.iotDevice?.id else {
                    os_log(.error, "Device ID was not retrieved by recognition context mapping. Will not be able to get IoT sensor data for this device.")
                    return
                }
                
                self.iotMessageRequestInProcess = true
                
                (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getHistoricalDeviceMessages(applicationId, deviceId, completion: { result in
                    self.iotMessageRequestInProcess = false
                    
                    switch result {
                    case .success(let data):
                        guard let items = data.items, items.count > 0 else {
                            os_log(.error, "IoT device message not returned from IoT Cloud Service.")
                            return
                        }
                        
                        let message = items[0]
                        self.lastSensorMessage = message
                        
                        #if DEBUGIOT
                        os_log(.debug, "Sensor request completed.")
                        #endif
                        
                        // Display message data
                        DispatchQueue.main.async {
                            self.updateSensorTextNodes()
                            
                            // Add an alert message if required
                            guard let NodeContextViewController = self.children.first(where: { $0 is NodeContextViewController }) as? NodeContextViewController else { return }
                            NodeContextViewController.addSensorMessage(message)
                        }
                        
                        break
                    case .failure(let failure):
                        failure.log()
                        os_log(.error, "Error getting data for sensors")
                        break
                    }
                }, limit: 50)
            } else {
                #if DEBUGIOT
                os_log(.debug, "Sensor request already in process. Skipping scheduled call until it is completed.")
                #endif
            }
        }
    }
    
    //MARK: - Integration Methods
    
    /**
     Method used to get IoT device data.
     
     - Parameter deviceId: The ID for the specific item that has been recognized.
     - Parameter completion: Escaped closure that can be used to act upon the device data returned.
     */
    private func getDeviceData(_ deviceId: String, completion: (() -> ())?) {
        self.iotDevice = nil
        
        (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getDeviceInfo(deviceId) { result in
            switch result {
            case .success(let data):
                self.iotDevice = data
                
                break
            case .failure(let failure):
                failure.log()
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Connection Error", message: "Unable to get device information from ICS. There may be a network issue between your device and ICS.", preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(action)
                    self.present(alert, animated: true, completion: nil)
                }
                break
            }
            
            completion?()
        }
    }
    
    // MARK: - OverlayViewControllerDelegate Methods
    
    func closeRequested(sender: UIView) {
        self.slideOutView(sender, completion: {
            DispatchQueue.main.async {
                self.setSensorTimerState(to: true)
                
                if self.tappedNode != nil {
                    self.setTappedNodeContext(self.tappedNode!)
                }
                
                // Try to restart tracking based on the existing configuration.
                guard let configuration = self.sceneView.session.configuration else { self.resetScene(true); return }
                self.sceneView.session.run(configuration, options: .resetTracking)
                
                self.overlayViewController?.removeFromParent()
                self.overlayViewController = nil
            }
        })
    }
    
    // MARK: - ApplicationButtonsViewControllerDelegate Methods
    
    func resetButtonPressed(_ sender: ApplicationButtonsViewController) {
        #if DEBUG
        os_log(.debug, "Reset Button Handler")
        #endif
        
        self.resetScene(true)
    }
    
    func helpButtonPressed(_ sender: ApplicationButtonsViewController) {
        #if DEBUG
        os_log(.debug, "Help Manual Handler")
        #endif
        
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil else { return }
        guard let navVc = UIStoryboard(name: "help", bundle: nil).instantiateInitialViewController() as? OverlayNavigationController else { return }
        
        navVc.overlayDelegate = self
        self.overlayViewController = navVc
        self.addChild(navVc)
        self.slideInView(navVc.view)
        
        // Stop the timer when in background
        self.setSensorTimerState(to: false)
        self.sceneView.session.pause()
    }
    
    func shareButtonPressed(_ sender: ApplicationButtonsViewController) {
        let screenshot = self.sceneView.snapshot()
        
        let activityVc = UIActivityViewController(activityItems: [screenshot], applicationActivities: nil)
        activityVc.excludedActivityTypes = [.addToReadingList, .openInIBooks]
        
        //FROM THE APPLE DOCS:
        //It is your responsibility to present and dismiss the view controller using the appropriate means for the given device idiom. On iPad, you must present the view controller in a popover. On other devices, you must present it modally.
        
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            self.present(activityVc, animated: true, completion: {
                activityVc.removeFromParent()
            })
            
            if let poPresentationController = activityVc.popoverPresentationController {
                poPresentationController.sourceView = sender.view
            }
            break
        case .phone:
            self.present(activityVc, animated: true, completion: nil)
            break
        default:
            // We could present an error here, but unlikely this app will ever run on carplay or other idioms
            break
        }
    }
    
    // MARK: - NodeContextDelegate Methods
    
    func listServiceRequestsHandler(_ sender: NodeContextViewController?, completion: (() -> ())? = nil) {
        #if DEBUG
        os_log(.debug, "List Service Request Handler")
        #endif
        
        self.showSrOverlay()
        
        // Stop the timer when in background
        self.setSensorTimerState(to: false)
        self.sceneView.session.pause()
        completion?()
    }
    
    func listNotesHandler(_ sender: NodeContextViewController?, nodeName: String, completion: (() -> ())?) {
        #if DEBUG
        os_log(.debug, "List Notes Handler")
        #endif
        
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil else { completion?(); return }
        
        guard let vc = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as? NotesSplitViewController else { completion?(); return }
        
        vc.overlayDelegate = self
        vc.delegate = self
        vc.deviceId = self.iotDevice?.id
        vc.nodeName = nodeName
        
        self.addChild(vc)
        self.overlayViewController = vc
        self.slideInView(vc.view)
        
        // Stop the timer when in background
        self.setSensorTimerState(to: false)
        
        self.sceneView.session.pause()
        
        completion?()
    }
    
    func printItemHandler(_ sender: NodeContextViewController?, completion: (() -> ())? = nil) {
        #if DEBUG
        os_log(.debug, "Print Item Handler")
        #endif
        
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil, let tappedNode = self.tappedNode, let tappedNodeName = tappedNode.name else {
            completion?()
            return
        }
        
        let tappedNodeImage = self.sceneView.snapshot()
        
        let alert = UIAlertController(title: "Print Item", message: String(format: "Confirm that you would like to print '%@' as selected in yellow.", tappedNodeName), preferredStyle: .alert)
        let printAction = UIAlertAction(title: "Print", style: UIAlertAction.Style.default, handler: { action in
            let printedAlert = UIAlertController(title: "Print Queued", message: "Your print request has been queued to your 3D printer.", preferredStyle: .alert)
            let printedAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            printedAlert.addAction(printedAction)
            
            DispatchQueue.main.async {
                self.present(printedAlert, animated: true, completion: nil)
            }
        })
        let cancel = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil)
        
        alert.addImageAction(tappedNodeImage)
        alert.addAction(printAction)
        alert.addAction(cancel)
        
        self.present(alert, animated: true, completion: nil)
        
        completion?()
    }
    
    func orderItemHandler(_ sender: NodeContextViewController?, completion: (() -> ())? = nil) {
        #if DEBUG
        os_log(.debug, "Order Item Handler")
        #endif
        
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil, let tappedNode = self.tappedNode?.name else {
            completion?()
            return
        }
        
        let alert = UIAlertController(title: "1-Click Order", message: String(format: "Confirm that you would like to auto-order %@.", tappedNode), preferredStyle: .alert)
        let order = UIAlertAction(title: "Order", style: UIAlertAction.Style.default, handler: { action in
            let orderedAlert = UIAlertController(title: "Order Completed", message: "Your order has been placed.", preferredStyle: .alert)
            let orderAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            orderedAlert.addAction(orderAction)
            
            DispatchQueue.main.async {
                self.present(orderedAlert, animated: true, completion: nil)
            }
        })
        let cancel = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil)
        alert.addAction(order)
        alert.addAction(cancel)
        
        self.present(alert, animated: true, completion: nil)
        
        completion?()
    }
    
    func showPdfHandler(_ sender: NodeContextViewController?, answer: AnswerResponse, completion: (() -> ())?) {
        #if DEBUG
        os_log(.debug, "Show Manual Handler")
        #endif
        
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil else {
            completion?()
            return
        }
        
        // Since a number of API calls have to be made before we know the path of the PDF, show the overlay view
        guard let loadingVc = UIStoryboard(name: "ActivityOverlay", bundle: nil).instantiateViewController(withIdentifier: "ActivityOverlayViewController") as? ActivityOverlayViewController else { return }
        
        let pdfError: () -> () = {
            let alert = UIAlertController(title: "Error", message: "The selected manual does not appear to be a PDF file attachment in the knowledgebase. Please ensure that the answer is configured correctly.", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(action)
            
            DispatchQueue.main.async {
                loadingVc.view.removeFromSuperview()
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        let showPdfView: (PdfAnswer) -> () = { manual in
            guard let url = manual.url else {
                #if DEBUG
                os_log(.debug, "PDF URL is empty. Cancelling.")
                #endif
                
                DispatchQueue.main.async {
                    loadingVc.view.removeFromSuperview()
                }
                return
            }
            
            #if DEBUG
            os_log(.debug, "Attempting to retrieve PDF from: %@", url.absoluteString)
            #endif
            
            manual.getPDFFile(completion: { (pdf) in
                DispatchQueue.main.async {
                    loadingVc.view.removeFromSuperview()
                }
                
                guard let pdf = pdf else {
                    pdfError()
                    return
                }
                
                DispatchQueue.main.async {
                    guard let navVc = UIStoryboard(name: "PDF", bundle: nil).instantiateInitialViewController() as? OverlayNavigationController, let vc = navVc.children.first as? PDFViewController  else {
                        completion?()
                        return
                    }
                    
                    navVc.overlayDelegate = self
                    navVc.title = manual.title
                    vc.pdfDoc = pdf
                    self.sceneView.session.pause()
                    
                    self.addChild(navVc)
                    self.overlayViewController = navVc
                    self.slideInView(navVc.view)
                }
                
                // Stop the timer when in background
                self.setSensorTimerState(to: false)
                
                completion?()
            })
        }
        
        guard let id = answer.recordId, let title = answer.title else {
            completion?()
            return
        }
        
        let alert = UIAlertController(title: "PDF Document", message: title, preferredStyle: .alert)
        let viewAction = UIAlertAction(title: "Open", style: .default) { (action) in
            DispatchQueue.main.async {
                self.view.addSubview(loadingVc.view)
                // Set the label after loaded into view.
                loadingVc.setLabel("Loading PDF")
            }
            
            do {
                try (UIApplication.shared.delegate as! AppDelegate).integrationBroker.getAnswer(id: id, completion: { result in
                    switch result {
                    case .success(let data):
                        guard var manual = data.xmlToType(object: PdfAnswer.self) else {
                            os_log(.error, "Connot convert XML to pdf answer")
                            completion?()
                            pdfError()
                            return
                        }
                        
                        // If the URL is null, then likely we are querying from KA and not Engagement Cloud.  Try to set the PDF path from the answer data.
                        if manual.url == nil, data.resourcePath != nil {
                            manual.setUrlFromResourcePath(data.resourcePath!)
                        }
                        
                        showPdfView(manual)
                        
                        break
                    default:
                        os_log(.error, "Did not get answer data back from ICS")
                        completion?()
                        pdfError()
                        return
                    }
                })
            } catch {
                error.log()
                completion?()
                pdfError()
            }
        }
        
        let closeAction = UIAlertAction(title: "Close", style: .cancel, handler: nil)
        alert.addAction(viewAction)
        alert.addAction(closeAction)
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func showSensorsHandler(_ sender: NodeContextViewController?, completion: (() -> ())? = nil) {
        #if DEBUG
        os_log(.debug, "Show Sensors Handler")
        #endif
        
        guard let activeNode = self.tappedNode else {
            #if DEBUG
            os_log(.debug, "No active node to show sensors")
            #endif
            
            return
        }
        
        let currentSensor = activeNode.childNodes.first(where: { $0.name != nil && $0.name!.contains("_Sensor") })
        
        if currentSensor != nil {
            self.hideSensors(for: activeNode)
        } else {
            self.showSensors(for: activeNode)
        }
        
        completion?()
    }
    
    func proceduresHandler(_ sender: NodeContextViewController?, procedure: ARProcedure, completion: (() -> ())?) {
        #if DEBUG
        os_log(.debug, "Procedure Handler")
        #endif
        
        self.showProcedure(procedure)
        
        completion?()
    }
    
    func imageTappedHandler(_ sender: NodeContextViewController?, index: Int, completion: (() -> ())?) {
        #if DEBUG
        os_log(.debug, "Image Tapped Handler")
        #endif
        
        guard let images = sender?.arNodeContext?.images else {
            completion?()
            return
        }
        
        // Setup the image overlay view so that we have dimentions for the subview
        let storyBoard = UIStoryboard(name: "NodeImage", bundle: nil)
        let pageController = storyBoard.instantiateViewController(withIdentifier: "NodeImagePageViewOverlayController") as! NodeImagePageViewOverlayController
        
        var imageViewControllers: [UIViewController] = []
        
        for contextImage in images {
            guard let assignImage = contextImage.getImage() else { continue }
            
            let imageView = UIImageView()
            imageView.image = assignImage
            imageView.contentMode = .scaleAspectFit
            
            let imageViewController = UIViewController()
            imageViewController.view.addSubview(imageView)
            imageView.frame = imageViewController.view.frame
            
            imageViewControllers.append(imageViewController)
        }
        
        pageController.setPageControllers(imageViewControllers)
        pageController.initialIndex = index
        
        self.present(pageController, animated: true, completion: completion)
        
        self.sceneView.session.pause()
    }
    
    func nodeContextActionHandler(_ sender: NodeContextViewController?, action: ARNodeContext.TableRow.Action, completion: (() -> ())?) {
        #if DEBUG
        os_log(.debug, "Node Context Action Handler")
        #endif
        
        guard let type = action.type else {
            completion?()
            return
        }
        
        switch type {
        case .url:
            guard let urlStr = action.url, let url = URL(string: urlStr) else { break }
            
            if UIApplication.shared.canOpenURL(url) {
                #if DEBUG
                os_log(.debug, "Opening URL: %@", urlStr)
                #endif
                
                UIApplication.shared.open(url, options: [:], completionHandler: { result in
                    os_log(.info, "Opening external url: %@", urlStr)
                })
            }
            else {
                let alert = UIAlertController(title: "Error", message: "Cannot open link provided. Contact developer to correct this issue.", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(action)
                self.present(alert, animated: true, completion: nil)
            }
            
            break
        case .applicationFunction:
            guard let function = action.applicationFunction else { return }
            
            #if DEBUG
            os_log(.debug, "Opening Application Function: %@", function.rawValue)
            #endif
            
            switch function {
            case .createSr:
                DispatchQueue.main.async {
                    self.showSrOverlay()
                }
                break
            default:
                break
            }
        break
        }
        
        completion?()
    }
    
    // MARK: - ProceduresViewControllerDelegate Methods
    
    func closeRequested(_ sender: ProceduresViewController) {
        self.gesturesEnabled = true
    }
    
    func procedureStart(_ sender: ProceduresViewController, completion: (() -> ())?) {
        self.returnNodes() {
            completion?()
        }
    }
    
    func procedureStop(_ sender: ProceduresViewController, completion: (() -> ())?) {
        self.returnNodes() {
            DispatchQueue.main.async {
                guard let recognitionRootNode = self.activeRecognitionContext?.nodeName() else { return }
                guard let node = self.sceneView.scene.rootNode.childNode(withName: recognitionRootNode, recursively: true) else { return }
                
                if let nodeName = node.name, let originalAngles = self.nodesOriginatingAngles?[nodeName] {
                    node.runAction(.rotateTo(x: CGFloat(originalAngles.x), y: CGFloat(originalAngles.y), z: CGFloat(originalAngles.z), duration: 0.25))
                } else {
                    node.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.25))
                }
                
                self.setTappedNodeContext(node)
            }
            completion?()
        }
        
        // Turn off simulated failure
        guard let appId = self.iotApplicationId else { return }
        guard let deviceId = self.iotDevice?.id else { return }
        
        DispatchQueue.main.async {
            let integrationBroker = (UIApplication.shared.delegate as! AppDelegate).integrationBroker!
            
            DispatchQueue.global(qos: .background).async {
                // See if there is an action for this device associated with the "procedure end" event.
                integrationBroker.getDeviceArActionMapping(appId, deviceId, completion: { (result) in
                    switch result {
                    case .success(let mapping):
                        // If the device event mapping is not in the API response, then end.
                        guard let iotEvent = mapping.iotTriggerName, mapping.arAppEvent == .procedureEnd else { return }
                        
                        // We found a device/event mapping.  Get device data so that we can make a call to ICS.
                        integrationBroker.getDeviceInfo(deviceId, completion: { (result) in
                            switch result {
                            case .success(let device):
                                let request = DeviceEventTriggerRequest(value: false)
                                
                                guard let model = device.deviceModels?.first(where: { $0.system != true })?.urn else { return }
                                
                                // Perform the proper call to IoT actions based on the mapping.
                                integrationBroker.triggerDeviceIssue(applicationId: appId, deviceId: deviceId, request: request, deviceModel: model, action: iotEvent, completion: { (result) in
                                    switch result {
                                    case .success(_):
                                        // Perform any other required work after the action is completed.
                                        
                                        break
                                    default:
                                        let alert = UIAlertController(title: "IoT Error", message: "There was an error disabling the IoT event after procedures were completed", preferredStyle: .alert)
                                        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                                        alert.addAction(action)
                                        
                                        DispatchQueue.main.async {
                                            self.present(alert, animated: true, completion: nil)
                                        }
                                        break
                                    }
                                })
                                
                                break
                            case .failure(let failure):
                                failure.log()
                                break
                            }
                        })
                        
                        break
                    case .failure(let failure):
                        failure.log()
                        break
                    }
                })
            }
        }
    }
    
    func procedureNextStepWillOccur(_ sender: ProceduresViewController, currentIndex: Int, completion: (() -> ())?) {
        // Clean up any movements or animations prior to the next step occurring
        guard let step = sender.procedure?.steps?[currentIndex], let nodeOrginalPositions = step.nodeOriginalPositions, nodeOrginalPositions.count > 0 else {
            #if DEBUG
            os_log(.debug, "No original positions found for step.")
            #endif
            
            completion?()
            return
        }
        
        #if DEBUG
        os_log(.debug, "Returning nodes to original positions in step.")
        #endif
        
        for (index, position) in nodeOrginalPositions.enumerated() {
            guard let node = self.sceneView.scene.rootNode.childNode(withName: position.key, recursively: true) else {
                completion?()
                return
            }
            
            if let nodeName = node.name, let alpha = sender.procedure?.steps?[currentIndex].nodeOriginalOpacity?[nodeName] {
                node.runAction(.fadeOpacity(to: alpha, duration: self.defaultDuration))
            }
            
            if index == nodeOrginalPositions.count - 1 {
                node.runAction(.move(to: position.value, duration: self.defaultDuration)) {
                    completion?()
                }
            } else {
                node.runAction(.move(to: position.value, duration: self.defaultDuration))
            }
        }
    }
    
    func procedureNextStepDidOccur(_ sender: ProceduresViewController, newIndex: Int, completion: (() -> ())?) {
        if let highlightNode = sender.procedure?.steps?[newIndex].highlightNode, let node = self.sceneView.scene.rootNode.childNode(withName: highlightNode, recursively: true) {
            self.setTappedNodeContext(node)
        }
        
        completion?()
    }
    
    func playAnimations(_ sender: ProceduresViewController, animations: [ARAnimation], completion: (() -> ())?) {
        guard animations.count > 0 else {
            completion?()
            return
        }
        
        self.gesturesEnabled = false
        self.animatingParts = true
        
        do {
            try self.playAnimations(animations: animations) {
                var nodePositions: [String:SCNVector3] = [:]
                var nodeOpacities: [String:CGFloat] = [:]
                
                var trackPositions: ((SCNNode) -> ())!
                trackPositions = { node in
                    if let nodeName = node.name {
                        nodePositions[nodeName] = node.position
                        nodeOpacities[nodeName] = node.opacity
                    }
                    
                    if node.childNodes.count > 0 {
                        for childNode in node.childNodes {
                            trackPositions(childNode)
                        }
                    }
                }
                
                for animation in animations {
                    for nodeName in animation.nodes {
                        guard let node = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else { continue }
                        
                        trackPositions(node)
                    }
                }
                
                sender.setNodePositionsForCurrentStep(nodePositions)
                sender.setNodeAplhasForCurrentStep(nodeOpacities)
                
                self.gesturesEnabled = true
                self.animatingParts = false
                
                completion?()
            }
        } catch {
            //TODO: Display an error for the user alerting them that the developer has not property configured the animation data and that the animation will stop here.
            error.log()
            self.gesturesEnabled = true
            self.animatingParts = false
        }
    }
}
