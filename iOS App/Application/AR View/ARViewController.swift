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
import CoreLocation
import os

class ARViewController:
    UIViewController,
    ARSCNViewDelegate,
    SKSceneDelegate,
    UIGestureRecognizerDelegate,
    UISplitViewControllerDelegate,
    CLLocationManagerDelegate,
    OverlayControllerDelegate,
    AppServerConfigsDelegate,
    NodeContextDelegate,
    ProceduresViewControllerDelegate,
    ApplicationButtonsViewControllerDelegate{
    
    // MARK: - IBOutlets

    /**
     Reference to the sceneView built in Interface Builder
    */
    @IBOutlet weak var sceneView: ARSCNView!
    
    // MARK: - Properties
    
    /**
     The context data for the object/image that was last recognized by ARKit
     */
    private var activeRecognitionContext: ARRecognitionContext?
    
    /**
     The name of the primary asset node that was loaded into the scene via recognition.
     */
    private var activeNodeName: String?
    
    /**
     The current device ID of the IoT device that has been recognized.
     */
    private(set) var deviceId: String?
    
    /**
     Parameter to cache the starting position of the model parts so that we can move them back if needed.
     */
    private var nodesOriginatingPositions: [String: SCNVector3]?
    
    /**
     The image placement spritekit scene
     */
    private lazy var imagePlacementScene: SKScene? = {
        return SKScene(fileNamed: "ImagePlacementScene.sks")
    }()
    
    /**
     A dictionary to store the sensor settings for nodes as they are retreived remotely.  This cache prevents the need for repetative sensor calls as node selection changes.
     */
    private var nodeSensorCache: [String: [ARSensor]] = [:]
    
    /**
     Variable indicating if the root asset child nodes are currently in an position that is different from their origin.
     */
    private var partsExposed: Bool = false
    
    /**
     Variable indicating if parts are currently animating
     */
    private var animatingParts: Bool = false
    
    /**
     Flag to indicate if all touch gestures should be enabled or disabled in the AR view.
     */
    private var gesturesEnabled: Bool = true
    
    /**
     Flag to indicate if all animations should be enabled or disabled in the AR view.  This is helpful when the user has moved a node outside of its normal boundaries and an animation against the node would not play accurately because of its position.
     */
    private var animationsEnabled: Bool = true
    
    /**
     Variable to indicate if an IoT request is in process.
     */
    private var iotRequestInProcess: Bool = false
    
    /**
     Variable to store the IoT device that was pulled from ICSBroker.
     */
    private var iotDevice: IoTDevice?
    
    /**
     Variable to store the last sensor message returned from IoTCS.
     */
    private var lastSensorMessage: SensorMessage?
    
    /**
     Reference to a timer that controlls how quickly to request IoT sensor data.
     */
    private var sensorTimer: Timer?
    
    /**
     Reference to the current scene node that has been captured by a tap and will display a contextual UI.
     */
    private weak var tappedNode: SCNNode?
    
    /**
     Reference to the current scene node that has been captured by a long tap and will be dragged.
     */
    private weak var dragNode: SCNNode?
    
    /**
     Reference to the current scene node that is being scaled via pinch.
     */
    private weak var pinchNode: SCNNode?
    
    /**
     Reference to a view controller that is supplying an overlay to the AR experience (Charts, etc.)
    */
    weak var overlayViewController: UIViewController?
    
    // MARK: - Animation
    
    /**
     An enumeration of animations that are baked into the AR components of this application and can be programmatically applied to any node.  An AR procedure step can apply an animation to a set of nodes, and this allows reference to the animation that should be applied.
     */
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
    
    /**
     Default duration for animations if not specified elsewhere.
     */
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
            os_log("Could not find node with name '%@' to play animation '%@'", nodeName, animation.rawValue)
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
                os_log("Playing animation '%@' for node '%@'", animation.rawValue, nodeName)
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
            for val in Animation.allCases {
                if animation.name == val.rawValue {
                    convertedAnimations.append(val)
                    break
                }
            }
        }
        
        // If we cannot map all animations supplied then we cannot play all animations.  Prevent the list from playing and fix the JSON nodes with incorrect animation names.
        if animations.count != convertedAnimations.count {
            throw SCNAction.ActionError.cannotMapAction(nodeCountExpected: animations.count, nodeCountCalculted: convertedAnimations.count)
        }
        
        self.animatingParts = true
        
        let parallelAnimationForNodes: (Animation, ARAnimation, (() -> ())?) -> () = { (animation, procedureAnimation, animationCompletion) in
            // Add any attributions to the supplied nodes prior to animation
            if let attributions = procedureAnimation.attributions {
                self.addAttributionsToSceneNodes(procedureAnimation.nodes, attributions: attributions)
            }
            
            // Run the animations
            for node in procedureAnimation.nodes {
                let value = procedureAnimation.value ?? 0.0
                let duration = procedureAnimation.duration ?? 0.0
                
                self.play(animation, for: node, value: value, duration: duration, completion: {
                    // Remove attributions
                    if let attributions = procedureAnimation.attributions {
                        self.removeAttributionChildNodes(node, attributions: attributions)
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
        guard let partsWithOriginalPositionsSaved = self.nodesOriginatingPositions else {
            #if DEBUG
            os_log(.debug, "Parts with original positions array empty.")
            #endif
            return
        }
        
        self.animatingParts = true
        
        var animateReturn: ((String) -> ())!
        animateReturn = { nodeName in
            guard let position = partsWithOriginalPositionsSaved[nodeName], let node = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else {
                #if DEBUG
                os_log(.debug, "Could not get original position for node named: %@", nodeName)
                #endif
                return
            }
            
            let actions: SCNAction = .group([
                .move(to: position, duration: self.defaultDuration),
                .fadeIn(duration: self.defaultDuration),
                .rotateTo(x: 0, y: 0, z: 0, duration: self.defaultDuration),
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide UINavigation Bar on AR View
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Applies the halo technique to the selected node for highlighting.
        #if DEBUGUI
        //Show stats in debug mode
        sceneView.showsStatistics = true
        
        os_log("Will not apply line technique during debug to prevent frequent crashes in debug mode.")
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
        os_log("Subviews Touched: %d", viewsTouched.count)
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
            os_log("rotating")
            #endif
            
            if sender.state == .began {
                #if DEBUG
                os_log("rotation began")
                #endif
            }
            else if sender.state == .changed {
                let newY: Float = Float(sender.rotation) * -1
                activeNode.eulerAngles.y = newY
            }
            else {
                #if DEBUG
                os_log("rotation ended")
                #endif
                
                // Only return if a procedure is not running
                if !self.children.contains(where: { $0 is ProceduresViewController }) {
                    activeNode.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.25))
                }
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
        os_log("pinching")
        #endif
        
        // Get the visible model node in the scene
        if self.pinchNode == nil {
            guard let activeNodeName = self.activeNodeName, let scaleNode = self.sceneView.scene.rootNode.childNode(withName: activeNodeName, recursively: true) else { return }
            pinchNode = scaleNode
        }
        
        if sender.state == .began{
            
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
                self.pinchNode?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.25))
            }
            
            self.pinchNode = nil
        }
        else {
            self.pinchNode = nil
        }
    }
    
    /**
     Event handler for a single tap event.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func tapped(_ sender: UITapGestureRecognizer) {
        #if DEBUG
        os_log("single tapped")
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
                // Ensure that the node was tapped either while a procedure is not active, or if it is listed in the interaction nodes
                if let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController {
                    let interactionNodes = proceduresViewController.procedure?.interactionNodes
                    guard (interactionNodes != nil && interactionNodes!.contains(nodeName)) else { return }
                }
                
                #if DEBUG
                if nodeHit.name != nil {
                    os_log("Node Tapped: %@", nodeName)
                }
                #endif
                
                // make sure that the node has a name and that it was not a sensor
                let itemTapped = hitTest.contains { ($0.node.name != nil && !$0.node.name!.contains("_Sensor")) }
                
                // Manage taps for the model item(s)
                if itemTapped {
                    #if DEBUG
                    os_log("Item is a 3D node. Setting context.")
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
                os_log("No node tapped")
                os_log("Root node name: '%@'", (self.sceneView.scene.rootNode.name ?? ""))
                #endif
                
                let removeContext: () -> () = {
                    guard let nodeToRemoveContext = self.tappedNode else { return }
                    self.removeTappedNodeContext(nodeToRemoveContext, completion: nil)
                    self.tappedNode = nil
                }
                
                let setContextToRecognitionNode: () -> () = {
                    // see if we can select the recognition node for root level context
                    guard let sensors = self.activeRecognitionContext?.sensors, sensors.count > 0 else { removeContext(); return }
                    guard let recognitionNodeName = self.activeRecognitionContext?.recognitionNodeName() else { return }
                    guard let recognitionNode = self.sceneView.scene.rootNode.childNode(withName: recognitionNodeName, recursively: false) else { return }
                    
                    self.setTappedNodeContext(recognitionNode)
                }
                
                if self.tappedNode != nil && self.activeRecognitionContext != nil && self.tappedNode?.name != self.activeRecognitionContext?.recognitionNodeName() {
                    setContextToRecognitionNode()
                }
                // If the tapped node is already set to the recognition node, then no other action required
                else if self.tappedNode?.name == self.activeRecognitionContext?.recognitionNodeName() {
                    return
                }
                else {
                    removeContext()
                }
            }
        }
    }/**
     Event handler for a single three-finger tap event which will play a node's assigned animations from its ARNodeContext context.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func twoFingerTap(_ sender: UITapGestureRecognizer) {
        #if DEBUG
        let gestureName = "Two Finger Tap"
        os_log("%@", gestureName)
        #endif
        
        guard let nodeName = self.activeRecognitionContext?.rootNodeName() else { return }
        guard let node = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else { return }
        
        self.returnNodes {
            self.setTappedNodeContext(node)
        }
    }
    
    /**
     Event handler for a single three-finger tap event which will play a node's assigned animations from its ARNodeContext context.
     
     - Parameter sender: The gesture recognizer that sent the event.
     */
    @objc private func threeFingerTap(_ sender: UITapGestureRecognizer) {
        let gestureName = "Three Finger Tap"
        
        #if DEBUG
        os_log("%@", gestureName)
        #endif
        
        let locationInView: CGPoint = sender.location(in: self.sceneView)
        let hitResults = self.sceneView.hitTest(locationInView, options: nil)
        let hitNode = hitResults.first?.node
        let nodeName = hitNode?.name
 
        // Ensure that the node was tapped either while a procedure is not active, or if it is listed in the interaction nodes
        if let proceduresViewController = self.children.first(where: { $0 is ProceduresViewController }) as? ProceduresViewController, nodeName != nil {
            let interactionNodes = proceduresViewController.procedure?.interactionNodes
            guard (interactionNodes != nil && interactionNodes!.contains(nodeName!)) else { return }
        }
        
        if sender.state == .ended && !self.animatingParts {
            if !self.partsExposed {
                #if DEBUG
                os_log("Exposing Parts")
                #endif
                
                guard let animations = self.activeRecognitionContext?.actionAnimations, animations.count > 0 else {
                    #if DEBUG
                    os_log("No actions assigned to recognition context '%@'", self.activeRecognitionContext?.name ?? "N/A")
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
                os_log("Returning Parts")
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
                os_log("Pan called by drag node not selected")
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
                os_log("Position: X (%.5f) Y (%.5f) Z (%.5f)", position.x, position.y, position.z)
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
                os_log("Position: X (%.5f) Y (%.5f) Z (%.5f)", position.x, position.y, position.z)
                #endif
            }
        }
        // Change the opacity when three models are used.
        else if sender.numberOfTouches == 3 {
            #if DEBUG
            os_log("3 finger pan")
            #endif
            
            guard let recognizedNodeName = self.activeRecognitionContext?.rootNodeName() else { return }
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
            os_log("New Transparency: %.5f", newOpacity)
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
            
        }
        else if sender.state == .ended {
            
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
            let alert = UIAlertController(title: "Unable to Load Configs", message: "We are unable to reach ICS for server data. Ensure that the ICS configuration variables are set in application settings and that the username and password are correct.", preferredStyle: UIAlertController.Style.alert)
            
            let settingsAction = UIAlertAction(title: "Open Settings", style: .default) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        os_log("Settings opened: %@", success)
                    })
                }
            }
            
            alert.addAction(settingsAction)  // Go to settings button
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))  // Cancel Button
            
            //ensure alert is presented on the main UI thread
            DispatchQueue.main.async {
                self.present(alert, animated: true)
            }
        }
        
        DispatchQueue.main.async {
            // If not successful, supply a warning to configure the remote settings.
            guard result else { showError(); return }
        
            // App delegate access must be run on main thread
            guard let serverConfigs = (UIApplication.shared.delegate as? AppDelegate)?.appServerConfigs?.serverConfigs else { showError(); return }
            
            // The device ID is only supplied here because this is a demo.  In the real-world, the object scan would identify the unique device id to retrieve IoT data for.
            //TODO: Remove and replace with ID recognition at scan.
            guard let deviceId = serverConfigs.iot?.deviceId else {
                let alert = UIAlertController(title: "Unable to Connect to Server", message: "Unable to get server configs from ICS", preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(action)
                
                DispatchQueue.main.async {
                    self.present(alert, animated: true, completion: nil)
                }
                
                return
            }
            
            self.deviceId = deviceId
            
            // Get the remote info for this device ID.
            self.getDeviceData(deviceId, completion: {
                // Start AR Tracking
                DispatchQueue.main.async {
                    guard let overlayVc = self.children.first(where: { $0 is ActivityOverlayViewController }) as? ActivityOverlayViewController else { return }
                    overlayVc.view.removeFromSuperview()
                    overlayVc.removeFromParent()
                    
                    self.setTrackingConfiguration()
                }
            })
        }
    }

    // MARK: - ARSCNViewDelegate Methods
    
    func session(_ session: ARSession, didFailWithError error: Error) {
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
        os_log("AR Session Interrupted")
        
        self.setSensorTimerState(to: false)
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        os_log("AR Session Interruption Ended")
        
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
        
        guard let deviceId = self.deviceId else { return }
        
        self.getDeviceData(deviceId, completion: nil)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //Ensure that the scene is empty and doesn not have nodes that may have lingered from a different tracking session
        self.resetScene(false)
        
        guard let anchorName = anchor.name, let anchorObjNameSubStr = anchorName.split(separator: "_").first else { return }
        
        let anchorObjName = String(anchorObjNameSubStr)
        
        #if DEBUG
        os_log("Anchor Name: %@", anchorName)
        os_log("Anchor Object: %@", anchorObjName)
        #endif
        
        let setupRecognitionContext: () -> () = {
            #if DEBUG
            os_log("Setting up recognition context for %@", anchorName)
            #endif
            
            guard let context = self.activeRecognitionContext else {
                #if DEBUG
                os_log("No recognition context for %@", anchorName)
                #endif
                
                return
            }
            
            node.name = self.activeRecognitionContext?.recognitionNodeName()
            
            guard let sensors = context.sensors else { return }
            self.nodeSensorCache[node.name!] = sensors
            
            self.showSensors(for: node)
        }
            
        let setupModelContext: () -> () = {
            #if DEBUG
            os_log("Setting up model context for %@", anchorName)
            #endif
            
            // Updates to the node have to happen on the main thread
            DispatchQueue.main.async {
                // Insert model into view
                guard let assetNode = SCNScene(named: String(format: "art.scnassets/%@.scn", anchorObjName))?.rootNode.childNode(withName: anchorObjName, recursively: false) else {
                    os_log(.error, "Unable to find 3D model for %@", anchorObjName)
                    
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
                
                if let objectAnchor = anchor as? ARObjectAnchor {
                    assetNode.simdScale = objectAnchor.referenceObject.scale / 2
                    assetNode.simdPosition = objectAnchor.referenceObject.center
                    
                    assetNode.position.x = 0
                    assetNode.position.y = 0
                    assetNode.position.z = 0
                    
                    #if DEBUG
                    os_log("Position: X (%.f5) Y (%.f5) X (%.f5)", assetNode.position.x, assetNode.position.y, assetNode.position.z)
                    #endif
                }
                else if let imageAnchor = anchor as? ARImageAnchor {
                    assetNode.position.z = Float(imageAnchor.referenceImage.physicalSize.height) * -1
                }
                
                // Save the original positions of all nodes so that we can reset the model to this state if the user moves parts around
                self.nodesOriginatingPositions = [:]
                var saveNodePositions: ((SCNNode) -> ())!
                saveNodePositions = { node in
                    if let nodeName = node.name, nodeName != assetNode.name {
                        self.nodesOriginatingPositions![nodeName] = node.position
                    }
                    
                    guard let childNodes = node.nonSensorChildNodes else { return }
                    
                    for childNode in childNodes {
                        saveNodePositions(childNode)
                        childNode.opacity = 0.5
                    }
                }
                
                saveNodePositions(assetNode)
                
                // Add the node to view
                node.addChildNode(assetNode)
                
                self.setTappedNodeContext(assetNode)
            }
            
            // Show sensors after a delay to let node placement occur
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                os_log("Showing Sensors")
                
                guard let activeNodeName = self.activeNodeName, let assetNode = self.sceneView.scene.rootNode.childNode(withName: activeNodeName, recursively: true) else {
                    #if DEBUG
                    os_log("Could not find node for: %@", (self.activeNodeName ?? ""))
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
            self.sceneView.overlaySKScene?.removeAllChildren()
            
            // Perform specfic functions based on whether the anchor was image based or object based.
            if anchor is ARObjectAnchor {
                self.objectAnchorHandler(node: node, anchor: (anchor as! ARObjectAnchor))
            }
            else if anchor is ARImageAnchor {
                self.objectImageHandler(node: node, anchor: (anchor as! ARImageAnchor))
            }
            else {
                os_log("Anchor was neither an object nor image. Resetting AR scene.")
                self.resetScene()
                return
            }
            
            //TODO: Add a progress indicator while application is getting remote data
            // ensure that the anchor has a name that we can use to query for contextual data
            DispatchQueue.main.async {
                guard let anchorName = anchor.name else {
                    let alert = UIAlertController(title: "Error", message: "The AR application was able to recognize an object, but cannot connect to ICS to retrieve configuration details about the item. Ensure that ICS is configured correctly and try again.", preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default, handler: { (action) in
                        self.resetScene()
                    })
                    alert.addAction(action)
                    
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                    
                    return
                }
                
                // Query API for context data for recognized object/image
                ICSBroker.shared.getRecognitionData(name: anchorName, completion: { result in
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
                    
                    // Show the application buttons
                    if let vc = UIStoryboard(name: "ApplicationButtonContext", bundle: nil).instantiateViewController(withIdentifier: "ApplicationButtonsViewController") as? ApplicationButtonsViewController {
                        self.addChild(vc)
                        
                        vc.delegate = self
                        vc.moveFrameOutOfView()
                        
                        self.view.insertSubview(vc.view, at: 0)
                        
                        vc.resizeForContent(self.defaultDuration, completion: nil)
                    }
                    
                    // Setup any 3D content related to the object/image that was recognized
                    setupRecognitionContext()
                    
                    // Setup 3D models
                    setupModelContext()
                })
            }
        }
        
        handleRecognition()
    }
    
    //MARK: - AR and Scene Methods
    
    /**
     Method for setting up the image tracking configuration.
     
     - Parameter resetTracking: Flag to indicate if any existing tracking should be removed from the AR session.  Will also display the placement image if set to true.
     */
    private func setTrackingConfiguration(_ resetTracking: Bool = true) {
        // Setup tracking configuration
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil), let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "AR Resources", bundle: nil) else {
            os_log("Could not find any tracking images in AR Resources")
            return
        }
        
        #if DEBUG
        os_log("%d reference images for AR detection available.", referenceImages.count)
        os_log("%d reference objects for AR detection available.", referenceObjects.count)
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
            os_log("Using image tracking")
            #endif
        } else {
            configuration = ARWorldTrackingConfiguration()
            (configuration as! ARWorldTrackingConfiguration).detectionObjects = referenceObjects
            
            #if DEBUG
            os_log("Using object tracking")
            #endif
        }
        
        var options: ARSession.RunOptions = []
        
        if resetTracking {
            #if DEBUG
            os_log("Reset tracking flag is true")
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
    
    /**
     Method for displaying the placement scene as a HUD
     */
    private func showPlacementImageScene() {
        #if DEBUG
        os_log("Showing placement scene")
        #endif
        
        if self.sceneView.overlaySKScene == nil {
            self.sceneView.overlaySKScene = SKScene(size: CGSize(width: self.view.frame.size.width, height: self.view.frame.size.height))
            self.sceneView.overlaySKScene?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.sceneView.overlaySKScene?.scaleMode = .aspectFill
        }
        
        guard let placementImageScene = self.imagePlacementScene?.copy() as? SKScene else {
            os_log("Error getting image placement scene!")
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
        os_log("Object detection anchor found")
        #endif
    }
    
    /**
     Method to perform setup options for the model node(s) when the recognition type was image-based.
     
     - Parameter node: The node that the anchor was placed in.
     - Parameter anchor: The AR anchor that was recognized.
     */
    private func objectImageHandler(node: SCNNode, anchor: ARImageAnchor) {
        #if DEBUG
        os_log("Image detection anchor found")
        #endif
        
        DispatchQueue.main.async {
            let referenceImage = anchor.referenceImage
            guard let imageName = referenceImage.name else {
                os_log("Reference image did not have a name that we could use to map to a scene file.")
                return
            }
            
            #if DEBUG
            os_log("Found reference image: %@", imageName)
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
     Displays a contextual warning message based on the string supplied.
     
     - Parameter message: The warning message to display.
     - Parameter time: The number of seconds to display the message for.
     */
    private func displayWarningContext(message: String, for time: TimeInterval) {
        let textNode = SKLabelNode(fontNamed: "HelveticaNeue-Light") // see http://iosfonts.com for options!
        textNode.text = message
        textNode.fontColor = UIColor.red
        var frame = textNode.calculateAccumulatedFrame()
        
        
        repeat {
            textNode.xScale = textNode.xScale - 0.1
            textNode.yScale = textNode.yScale - 0.1
            frame = textNode.calculateAccumulatedFrame()
        } while (frame.size.width > self.view.frame.size.width)
        
        frame = textNode.calculateAccumulatedFrame()
        
        let yBorderOffset: CGFloat = 20.0
        let moveY: CGFloat = -((self.sceneView.frame.height / 2) - ((textNode.yScale * frame.size.height) / 2)) + yBorderOffset
        textNode.position = CGPoint(x: 0.0, y: moveY)
        
        DispatchQueue.main.async {
            self.sceneView.overlaySKScene?.addChild(textNode)
        }
        
        Timer.scheduledTimer(withTimeInterval: time, repeats: false, block: { (timer) in
            DispatchQueue.main.async {
                textNode.removeFromParent()
            }
        })
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
        self.tappedNode = nil
        
        // Reconfigure tracking and overlay UI
        self.animatingParts = false
        self.partsExposed = false
        self.activeNodeName = nil
        
        if resetUI {
            self.pauseAllActions()
            
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
        // Ensure that the device id is set
        guard let deviceId = self.deviceId else { return }
        
        // Ensure that the node has a name and that it is different than the currently selected node.
        guard let nodeName = node.name, (self.tappedNode == nil || nodeName != self.tappedNode?.name) else {
            #if DEBUG
            os_log("Node does not have a name. Cannot set context.")
            #endif
            
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
            
            contextController?.setNode(name: nodeName, for: deviceId)
            
            // Implement more context buttons as required per your app implementation.
            guard let srHistoryButton = contextController?.srHistoryButton else {
                    os_log("Could not get node buttons")
                    return
            }
            
            contextController?.addActionButton(srHistoryButton)
            
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
                ICSBroker.shared.getNodeData(nodeName: nodeName, completion: { result in
                    switch result {
                    case .success(let data):
                        guard let sensors = data.sensors else { return }
                        self.nodeSensorCache[nodeName] = sensors
                        showSensorButton()
                        break
                    default:
                        os_log("Could not get sensors for %@", nodeName)
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
            guard let procedure = contextController!.arNodeContext!.procedures!.first(where: {  $0.name.lowercased() == openProcedureName }) else { return }
            
            self.proceduresHandler(contextController, procedure: procedure, completion: nil)
            
            // Remove the procedure key so that it is not run again if the user selects the node with the assigned procedure.
            (UIApplication.shared.delegate as? AppDelegate)?.openUrlParams?.removeValue(forKey: "procedure")
        }
        
        DispatchQueue.main.async {
            if self.tappedNode != nil && self.tappedNode != node {
                self.removeTappedNodeContext(self.tappedNode!, removeContextView: false, completion: {
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
            os_log("View Frame Size: Width (%.5f) height (%.5f)", self.view.frame.size.width, self.view.frame.size.height)
            os_log("Node Frame Size: Width (%.5f) height (%.5f)", node.calculateAccumulatedFrame().size.width, node.calculateAccumulatedFrame().size.height)
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
    
    /**
     Prepares the SR overlay with IoT data and then displays it.
     */
    private func showSrOverlay() {
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil else { return }
        
        //Ensure that only one overlay view is visible at a time.
        
        guard let vc = UIStoryboard(name: "ServiceRequest", bundle: nil).instantiateViewController(withIdentifier: "ServiceRequestSplitViewController") as? ServiceRequestSplitViewController else {
            return
        }
        
        vc.overlayDelegate = self
        vc.iotDevice = self.iotDevice
        vc.lastSensorMessage = self.lastSensorMessage
        vc.selectedPart = self.tappedNode?.name
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
     Adds an AR Attribution (content from a SpriteKit file in 2D space) to a SCNNode.  This method is used during procedure animations to help direct the user for interacting with the real-world object.
     
     - Parameter nodeNames: An array of nodes to apply the attribution to.  This will search the scene's node tree for nodes with the applicable name.
     - Parameter attibutions: An array of attributions to apply to the node.
     */
    private func addAttributionsToSceneNodes(_ nodeNames: [String], attributions: [ARAnimation.Attribution]) {
        // Get nodes that were listed for attribution
        var nodes: [SCNNode] = []
        
        for nodeName in nodeNames {
            guard let node = self.sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else { continue }
            nodes.append(node)
        }
        
        // Find the scenes for attribution and apply them to nodes
        for attribution in attributions {
            #if DEBUG
            os_log(.debug, "Adding attribution: %@", attribution.name)
            #endif
            
            guard let sceneFrame = attribution.sceneFrame else { return }
            guard let image = attribution.image?.getImage() else { continue }
            
            // Setup the spritekit scene
            let attributionScene = SKScene(size: sceneFrame.getCGFrame())
            attributionScene.backgroundColor = .clear
            attributionScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            
            // create a shape node to draw the attribution image
            let shapeNode = SKShapeNode(rectOf: sceneFrame.getCGFrame())
            shapeNode.name = "attributionNode"
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
            attributionScene.addChild(shapeNode)
            
            for node in nodes {
                let plane = SCNPlane(width: CGFloat(sceneFrame.width), height: CGFloat(sceneFrame.height))
                let scale = attribution.scale != nil ? attribution.scale!.getVector3() : SCNVector3(1, 1, 1)
                let eulerAngles = attribution.eulerAngles != nil ? attribution.eulerAngles!.getVector3Radians() : SCNVector3(0, 0, 0)
                let position = attribution.position != nil ? attribution.position!.getVector3() : SCNVector3(0, 0.2, 0)
                
                self.createPlaneNodeForSpriteInScene(newNodeName: attribution.name, plane: plane, spriteKitScene: attributionScene, scale: scale, eulerAngles: eulerAngles, isFacingUser: false) { (newNode) in
                    #if DEBUG
                    os_log("Adding attribution node (%@) to %@", newNode.name!, node.name!)
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
     Removes any immediate child nodes with the term "Attribution" in the child node name.
     
     - Parameter parentNodeName: the name of the parent node to search for Attribution child nodes.
     - Parameter attributions: An array of attribution objects to remove from the given node.
     */
    private func removeAttributionChildNodes(_ parentNodeName: String, attributions: [ARAnimation.Attribution]) {
        guard let parentNode = self.sceneView.scene.rootNode.childNode(withName: parentNodeName, recursively: true) else { return }
        
        for attribution in attributions {
            let removeAttribution = attribution.removeAttributionsAfterAnimation ?? true
            guard removeAttribution == true, let node = parentNode.childNode(withName: attribution.name, recursively: false) else { continue }
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
        os_log("Showing sensors for node: %@", nodeName)
        #endif
        
        if let sensors = self.nodeSensorCache[nodeName] {
            // Show sensors from the background thread
            DispatchQueue.global(qos: .userInteractive).async {
                for sensor in sensors {
                    guard let sensorName = sensor.name else { return }
                    
                    let sensorNodeName = String(format: "%@_SensorNode", sensorName)
                    
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
                        os_log("Adding node: %@", nodeName)
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
        os_log("Removing sensors for node: %@", nodeName)
        #endif
        
        for childNode in node.childNodes {
            if let nodeName = childNode.name, nodeName.contains("_SensorNode") {
                childNode.runAction(.fadeOut(duration: self.defaultDuration)) {
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
    
    /**
     Method that sets the text values on the sensor nodes.  This is required, as opposed to using the SensorScene methods, because the nodes have been removed from the spritekit scenes and placed in this scenekit scene.
     */
    private func updateSensorTextNodes() {
        // Will cause a bad thread access if run on background thread
        DispatchQueue.main.async {
            guard let lastSensorMessage = self.lastSensorMessage, let sensorData = lastSensorMessage.payload?.data else {
                os_log("Cannot update text nodes since there is no sensor data")
                return
            }
            
            guard let selectedNode = self.tappedNode, let nodeName = selectedNode.name else {
                #if DEBUG
                os_log("No node selected to update sensors for.")
                #endif
                
                return
            }
            
            guard let sensors = self.nodeSensorCache[nodeName] else { return }
            
            for sensor in sensors {
                guard let sensorName = sensor.name else { return }
                if let val = sensorData[sensorName] {
                    let sensorNodeWithSKMaterialName = String(format: "%@_SensorNode_MaterialNode", sensorName)
                    
                    guard let scene = selectedNode.childNode(withName: sensorNodeWithSKMaterialName, recursively: true)?.geometry?.firstMaterial?.diffuse.contents as? SKScene else {
                        os_log("No node with name '%@' in scene", sensorNodeWithSKMaterialName)
                        continue
                    }
                    
                    guard let sensorValue = Double("\(val)") else {
                        #if DEBUGIOT
                        os_log("Count not convert %.f5 to a Double", val)
                        #endif
                        
                        continue
                    }
                    
                    guard let wrapper = scene.childNode(withName: "//sensorWrapper") as? SKShapeNode, let label = wrapper.childNode(withName: "//sensorLabel") as? SKLabelNode else {
                        #if DEBUGIOT
                        os_log("Cannot find sensor label for %@", sensorName)
                        #endif
                        
                        continue
                    }
                    
                    #if DEBUGIOT
                    os_log("Updating %@: %.f5", sensorName, val)
                    #endif
                    
                    let textFormat = sensor.label?.formatter ?? "%@"
                    label.text = String(format: textFormat, sensorValue)
                    
                    guard let min = sensor.operatingLimits?.min, let max = sensor.operatingLimits?.max else { return }
                    
                    if sensorValue < min || sensorValue > max {
                        wrapper.fillColor = .red
                        self.displayWarningContext(message: "Warning: Tap Red Sensor for Details", for: 3)
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
        os_log("Item is a sensor. Checking actions.")
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
        os_log("Sensor Action: %@", sensorActionType.rawValue)
        #endif
        
        switch sensorActionType {
        case .lineChart:
            #if DEBUG
            os_log("Displaying line chart")
            #endif
            
            guard let vc = UIStoryboard(name: "Charts", bundle: nil).instantiateViewController(withIdentifier: "LineChartViewController") as? LineChartViewController, let deviceId = self.iotDevice?.id else { return }
            
            vc.deviceId = deviceId
            vc.sensor = sensor
            vc.overlayDelegate = self
            vc.title = String(format: "%@ Data", sensor.name!)
            
            self.addChild(vc)
            self.overlayViewController = vc
            
            self.slideInView(vc.view)
            
            // Stop the timer when in background
            self.setSensorTimerState(to: false)
            
            self.sceneView.session.pause()
            
            break
        case .url:
            guard let urlStr = sensor.action?.url, let url = URL(string: urlStr) else { return }
            #if DEBUG
            os_log("Opening URL")
            #endif
            
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            
            break
        case .volume:
            guard let scene = node.geometry?.firstMaterial?.diffuse.contents as? VideoScene else {
                os_log("No SKScene applied to node as material")
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
        os_log("Setting sensor state: %@", on ? "on" : "off")
        #endif
        
        self.sensorTimer?.invalidate()
        self.sensorTimer = nil
        
        if on {
            let userDefaultsInterval = UserDefaults.standard.double(forKey:  SensorConfigs.sensorRequestInterval.rawValue)
            let interval: Double = userDefaultsInterval >= 2.5 ? userDefaultsInterval : 5.0
            self.sensorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { (timer) in
                if !self.iotRequestInProcess {
                    self.iotRequestInProcess = true
                    
                    #if DEBUGIOT
                    os_log("Starting sensor request process.")
                    #endif
                    
                    self.getLastIoTMessage{ message in
                        #if DEBUGIOT
                        os_log("Sensor request completed.")
                        #endif
                        
                        self.iotRequestInProcess = false
                        
                        self.updateSensorTextNodes()
                        
                        guard let message = message, let NodeContextViewController = self.children.first(where: { $0 is NodeContextViewController }) as? NodeContextViewController else { return }
                        
                        // Display message data
                        DispatchQueue.main.async {
                            NodeContextViewController.addSensorMessage(message)
                        }
                    }
                } else {
                    #if DEBUGIOT
                    os_log("Sensor request already in process. Skipping scheduled call until it is completed.")
                    #endif
                }
            }
            
            self.sensorTimer!.fire()
        }
    }
    
    //MARK: - Integration Methods
    
    /**
     Method used to get the last message from IoTCS for the AR device.
     
     - Parameter completion: Completion handler that is called when the process finishes in either success or failure.
     - Parameter message: A sensor message to pass to the competion or nil if the results did not retrieve a value.
     */
    private func getLastIoTMessage(completion: ((_ message: SensorMessage?) -> ())?) {
        guard let deviceId = self.iotDevice?.id else { return }
        
        ICSBroker.shared.getHistoricalDeviceMessages(deviceId, completion: { result in
            switch result {
            case .success(let data):
                guard let message = data.items?[0] else { completion?(nil); return }
                self.lastSensorMessage = message
                completion?(message)
                
                break
            default:
                completion?(nil)
                break
            }
        })
    }
    
    /**
     Method used to get IoT device data.
     
     - Parameter deviceId: The ID for the specific item that has been recognized.
     - Parameter completion: Escaped closure that can be used to act upon the device data returned.
     */
    private func getDeviceData(_ deviceId: String, completion: (() -> ())?) {
        self.iotDevice = nil
        
        ICSBroker.shared.getDeviceInfo(deviceId) { result in
            switch result {
            case .success(let data):
                self.iotDevice = data
                
                break
            default:
                break
            }
            
            completion?()
        }
    }
    
    // MARK: - OverlayViewControllerDelegate Methods
    
    func closeRequested(sender: UIView) {
        self.slideOutView(sender, completion: {
            DispatchQueue.main.async {
                self.overlayViewController?.removeFromParent()
                self.overlayViewController = nil
                
                self.setSensorTimerState(to: true)
                
                if self.tappedNode != nil {
                    self.setTappedNodeContext(self.tappedNode!)
                }
                
                // Try to restart tracking based on the existing configuration.
                guard let configuration = self.sceneView.session.configuration else { self.resetScene(true); return }
                self.sceneView.session.run(configuration, options: .resetTracking)
            }
        })
    }
    
    // MARK: - ApplicationButtonsViewControllerDelegate Methods
    
    func resetButtonPressed(_ sender: ApplicationButtonsViewController) {
        #if DEBUG
        os_log("Reset Button Handler")
        #endif
        
        self.resetScene(true)
    }
    
    func helpButtonPressed(_ sender: ApplicationButtonsViewController) {
        #if DEBUG
        os_log("Help Manual Handler")
        #endif
        
        //Ensure that only one overlay view is visible at a time.
        guard self.overlayViewController == nil else { return }
        guard let helpController = UIStoryboard(name: "help", bundle: nil).instantiateInitialViewController() as? HelpViewController else { return }
        
        helpController.overlayDelegate = self
        self.overlayViewController = helpController
        self.addChild(helpController)
        self.slideInView(helpController.view)
        
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
        os_log("List Service Request Handler")
        #endif
        
        self.showSrOverlay()
        
        // Stop the timer when in background
        self.setSensorTimerState(to: false)
        self.sceneView.session.pause()
        completion?()
    }
    
    func showPdfHandler(_ sender: NodeContextViewController?, answer: AnswerResponse, completion: (() -> ())?) {
        #if DEBUG
        os_log("Show Manual Handler")
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
                os_log("PDF URL is empty. Cancelling.")
                #endif
                
                DispatchQueue.main.async {
                    loadingVc.view.removeFromSuperview()
                }
                return
            }
            
            #if DEBUG
            os_log("Attempting to retrieve PDF from: %@", url.absoluteString)
            #endif
            
            manual.getPDFFile(completion: { (pdf) in
                DispatchQueue.main.async {
                    loadingVc.view.removeFromSuperview()
                }
                
                guard let pdf = pdf else {
                    pdfError()
                    return
                }
                
                guard let vc = UIStoryboard(name: "PDF", bundle: nil).instantiateViewController(withIdentifier: "PDFViewController") as? PDFViewController else {
                    completion?()
                    return
                }
                
                vc.pdfDoc = pdf
                vc.overlayDelegate = self
                
                DispatchQueue.main.async {
                    self.sceneView.session.pause()
                    
                    self.addChild(vc)
                    self.overlayViewController = vc
                    self.slideInView(vc.view)
                    
                    if manual.title != nil && vc.navigationBar != nil {
                        vc.navigationBar.topItem?.title = manual.title
                    }
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
                try ICSBroker.shared.getAnswer(id: id, completion: { result in
                    switch result {
                    case .success(let data):
                        guard var manual = data.xmlToType(object: PdfAnswer.self) else {
                            os_log("Connot convert XML to pdf answer")
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
                        os_log("Did not get answer data back from ICS")
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
        os_log("Show Sensors Handler")
        #endif
        
        guard let activeNode = self.tappedNode else {
            #if DEBUG
            os_log("No active node to show sensors")
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
        os_log("Procedure Handler")
        #endif
        
        self.showProcedure(procedure)
        
        completion?()
    }
    
    func imageTappedHandler(_ sender: NodeContextViewController?, index: Int, completion: (() -> ())?) {
        #if DEBUG
        os_log("Image Tapped Handler")
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
        os_log("Node Context Action Handler")
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
                os_log("Opening URL: %@", urlStr)
                #endif
                
                UIApplication.shared.open(url, options: [:], completionHandler: { result in
                    os_log("Opening external url: %@", urlStr)
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
            os_log("Opening Application Function: %@", function.rawValue)
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
                guard let recognitionRootNode = self.activeRecognitionContext?.rootNodeName() else { return }
                guard let node = self.sceneView.scene.rootNode.childNode(withName: recognitionRootNode, recursively: true) else { return }
                node.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.25))
            }
            completion?()
        }
        
        // Turn off simulated failure
        guard let serverConfigs = (UIApplication.shared.delegate as? AppDelegate)?.appServerConfigs?.serverConfigs else { return }
        guard let appId = serverConfigs.iot?.applicationId else { return }
        guard let deviceId = self.deviceId else { return }
        
        DispatchQueue.global(qos: .background).async {
            let request = DeviceEventTriggerRequest(value: false)
            
            ICSBroker.shared.triggerDeviceIssue(applicationId: appId, deviceId: deviceId, request: request, completion: { (result) in
                switch result {
                case .success(_):
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
        }
    }
    
    func procedureNextStepWillOccur(_ sender: ProceduresViewController, currentIndex: Int, completion: (() -> ())?) {
        // Clean up any movements or animations prior to the next step occurring
        guard let step = sender.procedure?.steps?[currentIndex], let nodeOrginalPositions = step.nodeOriginalPositions, nodeOrginalPositions.count > 0 else {
            #if DEBUG
            os_log("No original positions found for step.")
            #endif
            
            completion?()
            return
        }
        
        #if DEBUG
        os_log("Returning nodes to original positions in step.")
        #endif
        
        for (index, position) in nodeOrginalPositions.enumerated() {
            guard let node = self.sceneView.scene.rootNode.childNode(withName: position.key, recursively: true) else {
                completion?()
                return
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
                
                var trackPositions: ((SCNNode) -> ())!
                trackPositions = { node in
                    if let nodeName = node.name {
                        nodePositions[nodeName] = node.position
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
