import ARKit
import SceneKit
import UIKit

class SceneViewController: UIViewController, ARSCNViewDelegate, SCNSceneRendererDelegate {

    // MARK: - Properties

    // ARKit / SceneKit
    @IBOutlet var sceneView: ARSCNView!
    private let sessionConfiguration = ARWorldTrackingConfiguration()
    private var pointsParentNode = SCNNode()
    private var surfaceParentNode = SCNNode()
    private lazy var pointMaterial: SCNMaterial = createPointMaterial()
    private var surfaceGeometry: SCNGeometry?

    // Struct to hold currently captured Point Cloud data
    private var pointCloud = PointCloud()

    // Scanning Options
    private let addPointRatio = 3 // Show 1 / [addPointRatio] of the points
    private let scanningInterval = 0.5 // Capture points every [scanningInterval] seconds when user is touching screen
    private var isSurfaceDisplayOn = false {
        didSet {
            surfaceParentNode.isHidden = !isSurfaceDisplayOn
        }
    }
    internal var isCapturingPoints = false {
        didSet {
            updateScanningViewState()
            if isCapturingPoints {
                capturePointsButton.accessibilityLabel = "Stop Scan"
                sceneView.debugOptions.insert(ARSCNDebugOptions.showFeaturePoints)
            } else {
                capturePointsButton.accessibilityLabel = "Start Scan"
                sceneView.debugOptions.remove(ARSCNDebugOptions.showFeaturePoints)
            }
        }
    }

    // UI
    internal let reconstructButton = UIButton()
    internal let capturePointsButton = CameraButton()

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
        sceneView.delegate = self

        // Add buttons
        addCapturePointsButton()
        addReconstructButton()
        addResetButton()

        // Add SceneKit Parent Nodes
        sceneView.scene.rootNode.addChildNode(pointsParentNode)
        sceneView.scene.rootNode.addChildNode(surfaceParentNode)

        // Set SceneKit Lighting
        sceneView.autoenablesDefaultLighting = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set Session configuration
        sessionConfiguration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal

        // Run the view's session
        sceneView.session.run(sessionConfiguration)

        scheduledTimerWithTimeInterval()
    }

    // MARK: - Timer

    private var timer = Timer()

    private func scheduledTimerWithTimeInterval() {
        // Scheduling timer to call the function "updateCounting" every [scanningInteval] seconds
        timer = Timer.scheduledTimer(timeInterval: scanningInterval, target: self, selector: #selector(updateCounting), userInfo: nil, repeats: true)
    }

    @objc func updateCounting() {
        if isCapturingPoints {
            capturePoints()
        }
    }


    // MARK: - UI

    private func addCapturePointsButton() {
        view.addSubview(capturePointsButton)
        capturePointsButton.translatesAutoresizingMaskIntoConstraints = false
        capturePointsButton.accessibilityLabel = "Start Scan"
        capturePointsButton.addTarget(self, action: #selector(toggleCapturingPoints(sender:)), for: .touchUpInside)

        // Contraints
        let guide = view.safeAreaLayoutGuide
        capturePointsButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -2.0).isActive = true
        capturePointsButton.centerXAnchor.constraint(equalTo: guide.centerXAnchor, constant: 0.0).isActive = true
    }

    private func addReconstructButton() {
        reconstructButton.isEnabled = false
        view.addSubview(reconstructButton)
        reconstructButton.translatesAutoresizingMaskIntoConstraints = false
        reconstructButton.setTitle("View", for: .normal)
        reconstructButton.setTitleColor(UIColor.red, for: .normal)
        reconstructButton.setTitleColor(UIColor.gray, for: .disabled)
        reconstructButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        reconstructButton.showsTouchWhenHighlighted = true
        reconstructButton.layer.cornerRadius = 4
        reconstructButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        reconstructButton.addTarget(self, action: #selector(reconstructButtonTapped(sender:)), for: .touchUpInside)

        // Contraints
        let guide = view.safeAreaLayoutGuide
        reconstructButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16.0).isActive = true
        reconstructButton.centerXAnchor.constraint(equalTo: guide.centerXAnchor, constant: 80.0).isActive = true
    }

    private func addResetButton() {
        let resetButton = UIButton()
        view.addSubview(resetButton)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(UIColor.red, for: .normal)
        resetButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        resetButton.showsTouchWhenHighlighted = true
        resetButton.layer.cornerRadius = 4
        resetButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        resetButton.addTarget(self, action: #selector(resetButtonTapped(sender:)), for: .touchUpInside)

        // Contraints
        let guide = view.safeAreaLayoutGuide
        resetButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16.0).isActive = true
        resetButton.centerXAnchor.constraint(equalTo: guide.centerXAnchor, constant: -80.0).isActive = true
    }

    /**
     Displays a standard alert with a title and a message.
     */
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert
        )
        alert.addAction(UIAlertAction(
            title: "OK",
            style: UIAlertAction.Style.default,
            handler: nil
        ))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - UI Actions

    @IBAction func toggleCapturingPoints(sender: UIButton) {
        isCapturingPoints = !isCapturingPoints
    }

    @IBAction func reconstructButtonTapped(sender: UIButton) {

        // Prepare Point Cloud data structures in C struct format

        let pclPointSize = pointCloud.framePointSizes
        let pclPoints = pointCloud.points.map { PCLPoint3D(x: Double($0.x), y: Double($0.y), z: Double($0.z)) }
        let pclViewpoints = pointCloud.frameViewpoint.map { PCLPoint3D(x: Double($0.x), y: Double($0.y), z: Double($0.z)) }

        let pclPointCloud = pclPoints.withUnsafeBufferPointer { pclPointsBuffer in
            pclPointSize.withUnsafeBufferPointer { pclPointSizeBuffer in
                pclViewpoints.withUnsafeBufferPointer { pclViewPointsBuffer in
                    PCLPointCloud(
                        numPoints: Int32(pointCloud.points.count),
                        points: pclPointsBuffer.baseAddress,
                        numFrames: Int32(pointCloud.frameViewpoint.count),
                        pointFrameLengths: pclPointSizeBuffer.baseAddress,
                        viewpoints: pclViewPointsBuffer.baseAddress)
                }
            }
        }

        // Call C++ Surface Reconstruction function using C Wrapper asynchronously
        let dispatchGroup = DispatchGroup()
        var pclMesh: PCLMesh?
        dispatchGroup.enter()

        DispatchQueue.global(qos: .default).async {
            pclMesh = performSurfaceReconstruction(pclPointCloud)
            dispatchGroup.leave()
        }

        dispatchGroup.wait()

        if (pclMesh != nil) {
            defer {
                // The mesh points and polygons pointers were allocated in C++ so need to be freed here
                free(pclMesh!.points)
                free(pclMesh!.polygons)
            }

            // Remove current surfaces before displaying new surface
            surfaceParentNode.enumerateChildNodes { (node, stop) in
                node.removeFromParentNode()
                node.geometry = nil
            }

            // Display surface
            isSurfaceDisplayOn = true
            let surfaceNode = constructSurfaceNode(pclMesh: pclMesh!)
            surfaceParentNode.addChildNode(surfaceNode.flattenedClone())

            isCapturingPoints = false
            showAlert(title: "Surface Reconstructed", message: "\(pclMesh!.numFaces) faces")
        }
    }

    @IBAction func resetButtonTapped(sender: UIButton) {

        pointCloud.points = []
        pointCloud.framePointSizes = []
        pointCloud.frameViewpoint = []

        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in node.removeFromParentNode() }

        pointsParentNode = SCNNode()
        surfaceParentNode = SCNNode()

        surfaceGeometry = nil
        isCapturingPoints = false

        sceneView.scene.rootNode.addChildNode(pointsParentNode)
        sceneView.scene.rootNode.addChildNode(surfaceParentNode)

        sceneView.debugOptions.remove(ARSCNDebugOptions.showFeaturePoints)

        // Run the view's session
        sceneView.session.run(sessionConfiguration, options: [ARSession.RunOptions.resetTracking, ARSession.RunOptions.removeExistingAnchors])
    }

    // MARK: - Helper Functions

    /**
     Updates the state of the view based on scanning properties.
     */
    internal func updateScanningViewState() {
        capturePointsButton.isSelected = isCapturingPoints
        reconstructButton.isEnabled = !isCapturingPoints && pointCloud.points.count > 0
    }

    private func capturePoints() {

        // Store Points
        guard let rawFeaturePoints = sceneView.session.currentFrame?.rawFeaturePoints else {
            return
        }
        let currentPoints = rawFeaturePoints.points
        pointCloud.points += currentPoints
        pointCloud.framePointSizes.append(Int32(currentPoints.count))

        // Display points
        var i = 0
        for rawPoint in currentPoints {
            if i % addPointRatio == 0 {
                addPointToView(position: rawPoint)
            }
            i += 1
        }

        // Add viewpoint
        let camera = sceneView.session.currentFrame?.camera
        if let transform = camera?.transform {
            let position = SCNVector3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            pointCloud.frameViewpoint.append(position)
        }
    }

    /**
     Constructs an SCNNode representing the given PCL surface mesh output.
     */
    private func constructSurfaceNode(pclMesh: PCLMesh) -> SCNNode {

        // Construct vertices array
        var vertices = [SCNVector3]()
        for i in 0..<pclMesh.numPoints {
            vertices.append(SCNVector3(x: Float(pclMesh.points[i].x),
                                       y: Float(pclMesh.points[i].y),
                                       z: Float(pclMesh.points[i].z)))
        }
        let vertexSource = SCNGeometrySource(vertices: vertices)

        // Construct elements array
        var elements = [SCNGeometryElement]()
        for i in 0..<pclMesh.numFaces {
            let allPrimitives: [Int32] = [pclMesh.polygons[i].v1, pclMesh.polygons[i].v2, pclMesh.polygons[i].v3]
            elements.append(SCNGeometryElement(indices: allPrimitives, primitiveType: .triangles))
        }

        // Set surfaceGeometry to object from vertex and element data
        surfaceGeometry = SCNGeometry(sources: [vertexSource], elements: elements)
        surfaceGeometry?.firstMaterial?.isDoubleSided = true
        surfaceGeometry?.firstMaterial?.diffuse.contents =
            UIColor(displayP3Red: 135 / 255, green: 206 / 255, blue: 250 / 255, alpha: 1)
        surfaceGeometry?.firstMaterial?.lightingModel = .blinn
        return SCNNode(geometry: surfaceGeometry)
    }

    /**
     Creates a the SCNMaterial to be used for points in the displayed Point Cloud.
     */
    private func createPointMaterial() -> SCNMaterial {
        let textureImage = #imageLiteral(resourceName: "WhiteBlack")
        UIGraphicsBeginImageContext(textureImage.size)
        let width = textureImage.size.width
        let height = textureImage.size.height
        textureImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let pointMaterialImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let pointMaterial = SCNMaterial()
        pointMaterial.diffuse.contents = pointMaterialImage
        return pointMaterial
    }

    /**
     Helper function to add points to the view at the given position.
     */
    private func addPointToView(position: vector_float3) {
        let sphere = SCNSphere(radius: 0.00066)
        sphere.segmentCount = 8
        sphere.firstMaterial = pointMaterial

        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.orientation = (sceneView.pointOfView?.orientation)!
        sphereNode.pivot = SCNMatrix4MakeRotation(-Float.pi / 2, 0, 1, 0)
        sphereNode.position = SCNVector3(position)
        pointsParentNode.addChildNode(sphereNode)
    }
}

