//
//  GameViewController.swift
//  3dJournal
//
//  Created by Trevor Clute on 3/31/25.
//

import CoreData
import SceneKit
import UIKit
import simd

let cameraY: Float = 5

class GameViewController: UIViewController, SCNSceneRendererDelegate,
    UIGestureRecognizerDelegate, UITextViewDelegate
{
    let context = (UIApplication.shared.delegate as! AppDelegate)
        .persistentContainer.viewContext
    let cameraNode: SCNNode = SCNNode()
    let lightNode: SCNNode = SCNNode()
    let bulbNode: SCNNode = SCNNode()
    let particleNode: SCNNode = SCNNode()
    lazy var movementJoyStick = JoystickView(
        handleSize: view.bounds.width / 6, baseSize: view.bounds.width / 3)
    var createBookButton: UIButton?
    var hiddenTextView: UITextView = UITextView(frame: .zero)

    let scene: SCNScene = SCNScene()
    lazy var bookManager = BookManager(
        scene: self.scene, textView: self.hiddenTextView,
        context: self.context)
    lazy var terrain = Terrain(scene: scene)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupJoystick()
        setupCreateBookButton()
        setupHiddenText()
        addLight()
        addCamera()
        addParticleSystem()
        bookManager.loadBooksFromDataBase()
        loadCameraPositionFromDataBase()

        // MARK: - do scnview things
        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.delegate = self
        scnView.isPlaying = true
        scnView.loops = true
        scnView.backgroundColor = UIColor.black

        // MARK: - add gestures

        let tapGesture = UITapGestureRecognizer(
            target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(
            target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        scnView.addGestureRecognizer(panGesture)

        let swipeLeftGesture = UISwipeGestureRecognizer(
            target: self, action: #selector(handleSwipe(_:)))
        swipeLeftGesture.direction = .left
        swipeLeftGesture.cancelsTouchesInView = false
        scnView.addGestureRecognizer(swipeLeftGesture)

        let swipeRightGesture = UISwipeGestureRecognizer(
            target: self, action: #selector(handleSwipe(_:)))
        swipeRightGesture.direction = .right
        swipeRightGesture.cancelsTouchesInView = false
        scnView.addGestureRecognizer(swipeRightGesture)

        let longPress = UILongPressGestureRecognizer(
            target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5  // seconds to trigger
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
        view.addGestureRecognizer(longPress)

    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
        let location = touch.location(in: view)

        // Ignore touches within the joystick area
        if movementJoyStick.frame.contains(location) {
            switchCreateBookButtonIcon(to: "book")
            return false
        }

        guard let scnView = view as? SCNView else { return true }
        let scnLocation = touch.location(in: scnView)
        let hitResults = scnView.hitTest(scnLocation, options: [:])

        if gestureRecognizer is UILongPressGestureRecognizer {
            if let hit = hitResults.first,
                hit.node.parent?.name == "book"
            {
                return true  // Allow long press on a book
            }
            return false
        }

        if let hit = hitResults.first,
            let bookNode = hit.node.parent as? BookNode,
            hit.node.parent?.name == "book",
            bookNode.status == .open
        {
            if hit.node.name == "leftPage" || hit.node.name == "rightPage" {
                return false
            }
        }

        // Don't handle touch if the book is open
        return true
    }

    func systemColorName(for color: UIColor) -> String {
        switch color {
        case UIColor.systemRed:
            return "red"
        case UIColor.systemBlue:
            return "blue"
        case UIColor.systemGreen:
            return "green"
        case UIColor.systemYellow:
            return "yellow"
        case UIColor.systemOrange:
            return "orange"
        case UIColor.systemPink:
            return "pink"
        case UIColor.systemIndigo:
            return "purple"
        case UIColor.systemCyan:
            return "cyan"
        default:
            return ""
        }
    }

    var colors = Wheel<UIColor>([
        .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue,
        .systemIndigo, .systemPink, .systemCyan,
    ])
    @objc func createBookButtonTapped() {
        let transform = cameraNode.presentation.worldTransform

        switchCreateBookButtonIcon(to: "pencil")
        let cameraPosition = SCNVector3(
            x: transform.m41, y: transform.m42, z: transform.m43)

        let forward = SCNVector3(
            x: -transform.m31, y: -transform.m32, z: -transform.m33)
        let distance: Float = 2.0
        let targetPosition = SCNVector3(
            x: cameraPosition.x + forward.x * distance,
            y: cameraPosition.y + forward.y * distance,
            z: cameraPosition.z + forward.z * distance)
        do {
            let book = try bookManager.createBook(
                position: targetPosition, color: colors.getCurrent(),
                title: Date.now.formatted(date: .long, time: .omitted))
            hiddenTextView.becomeFirstResponder()
            self.hiddenTextView.text = ""
            book.open(cameraNode: cameraNode)
            for b in bookManager.books {
                if book.position.x == b.position.x
                    && book.position.y == b.position.y
                    && book.position.z == b.position.z
                {
                    self.bookManager.beginWrite(
                        bookNode: b, cameraNode: cameraNode)
                    self.updateText(in: self.hiddenTextView)
                    self.populateCaretInEmptyText(bookNode: b)
                    return
                }
            }
            self.populateCaretInEmptyText(bookNode: book)
            bookManager.addNewBookToDataBase(bookNode: book)
            bookManager.books.append(book)
            scene.rootNode.addChildNode(book)
            scene.rootNode.addChildNode(book.titleNode!)
        } catch {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
            print("error \(error)")
        }
    }

    @objc func handleLongPress(_ gesture: UIGestureRecognizer) {
        let scnView = self.view as! SCNView
        let location = gesture.location(in: scnView)
        let hitResults = scnView.hitTest(location, options: [:])
        hiddenTextView.resignFirstResponder()
        hiddenTextView.text = ""
        if let result = hitResults.first {
            if result.node.parent?.name == "book" {
                let book = result.node.parent! as! BookNode

                // Create the alert controller
                let alert = UIAlertController(
                    title: "Delete Book?",
                    message:
                        "Created on \(book.titleNode?.attributedString.string ?? "00/00/00")",
                    preferredStyle: .alert)

                // Customize alert appearance
                if let alertView = alert.view {
                    // Customize background
                    alertView.layer.cornerRadius = 14
                    alertView.layer.borderWidth = 1
                    alertView.layer.borderColor = book.color.cgColor
                }

                // Customize title and message text
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold)
                ]
                let messageAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular)
                ]
                alert.setValue(
                    NSAttributedString(
                        string: alert.title ?? "", attributes: titleAttributes),
                    forKey: "attributedTitle")
                alert.setValue(
                    NSAttributedString(
                        string: alert.message ?? "",
                        attributes: messageAttributes),
                    forKey: "attributedMessage")

                // Customize Delete button
                let deleteAction = UIAlertAction(
                    title: "Delete", style: .destructive
                ) { _ in
                    self.bookManager.removeBook(book: book)
                    self.switchCreateBookButtonIcon(to: "book")
                }
                deleteAction.setValue(
                    UIColor.systemRed, forKey: "titleTextColor")
                deleteAction.setValue(
                    UIImage(systemName: "trash.fill"), forKey: "image")

                // Customize Cancel button
                let cancelAction = UIAlertAction(
                    title: "Cancel", style: .cancel, handler: nil)
                cancelAction.setValue(
                    UIImage(systemName: "xmark.circle.fill"), forKey: "image")

                // Add actions
                alert.addAction(deleteAction)
                alert.addAction(cancelAction)

                // Add a subtle animation
                alert.view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                alert.view.alpha = 0.8
                self.present(alert, animated: true) {
                    UIView.animate(
                        withDuration: 0.2,
                        animations: {
                            alert.view.transform = .identity
                            alert.view.alpha = 1.0
                        })
                }
            }
        }
    }

    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let scnView = self.view as! SCNView
        let location = gesture.location(in: scnView)
        let hitResults = scnView.hitTest(location, options: [:])
        if hitResults.count > 0 {
            let result = hitResults[0]
            if result.node.parent?.name == "book" {
                let book = result.node.parent! as! BookNode
                switch gesture.direction {
                case .left:
                    book.nextPage()
                case .right:
                    book.previousPage()
                default:
                    break
                }
            }

        }
    }

    private var lastPanLocation = CGPoint.zero
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let scnView = self.view as! SCNView
        let translation = gesture.translation(in: scnView)

        switchCreateBookButtonIcon(to: "book")
        switch gesture.state {
        case .began:
            lastPanLocation = translation

        case .changed:
            let deltaX = Float(translation.x - lastPanLocation.x) * 0.003
            let deltaY = Float(translation.y - lastPanLocation.y) * 0.003

            // Rotate camera around Y and X axes
            cameraNode.eulerAngles.y += deltaX
            cameraNode.eulerAngles.x += deltaY

            lastPanLocation = translation

        default:
            break
        }
    }

    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        let location = gestureRecognize.location(in: scnView)
        let hitResults = scnView.hitTest(location, options: [:])
        if let result = hitResults.first {
            if result.node.parent?.name == "book" {
                let book = result.node.parent! as! BookNode
                bookManager.handleClick(
                    bookNode: book, cameraNode: cameraNode
                )
                if book.status == .open {
                    switchCreateBookButtonIcon(to: "pencil")
                }
                else if book.status == .closed {
                    switchCreateBookButtonIcon(to: "book")
                }
            } else if result.node.name == "light" || result.node.name == "bulb"
            {
                colors.iterate()
                bulbNode.geometry?.materials.first?.emission.contents =
                    colors.getCurrent()
            }

        }
    }

    func textViewDidChange(_ textView: UITextView) {
        updateText(in: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateText(in: textView)
    }

    var isBringing = false
    var lastTime: TimeInterval?
    var lastSaveTime: TimeInterval?
    func renderer(
        _ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval
    ) {
        if let lt = lastTime {
            let deltaTime = time - lt
            lastTime = time

            //handle movement
            let speed: Double = 30
            let front =
                cameraNode.simdWorldFront
                * Float(movementJoyStick.offset.dy * deltaTime * speed)
            let right =
                cameraNode.simdWorldRight
                * Float(movementJoyStick.offset.dx * deltaTime * speed)
            cameraNode.simdPosition -= front
            cameraNode.simdPosition += right

            particleNode.position = cameraNode.position
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            cameraNode.position.y =
                terrain.getWorldHeight(
                    x: cameraNode.position.x, z: cameraNode.position.z)
                + cameraY
            SCNTransaction.commit()

            let normalizedTileCamPosition = SCNVector3(
                x: cameraNode.position.x / 200, y: 0,
                z: cameraNode.position.z / 200)
            terrain.generateSurroundingTiles(
                x: Int(floor(normalizedTileCamPosition.x)),
                z: Int(floor(normalizedTileCamPosition.z)))

            if !isBringing {
                isBringing = true
                bring(to: cameraNode, node: lightNode)
                bring(to: cameraNode, node: bulbNode)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isBringing = false
            }
            let origin = SCNVector3(0, 0, 0)
            bulbNode.look(
                at: origin, up: SCNVector3(0, 1, 0),
                localFront: SCNVector3(0, 1, 0))

            if lastSaveTime == nil || time - (lastSaveTime ?? 0) >= 10 {
                saveCameraPositionToDataBase()
                lastSaveTime = time
            }
        } else {
            lastTime = time
            lastSaveTime = time
        }

    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }

    func bring(to target: SCNNode, node: SCNNode) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(
            name: .linear)
        let tempNode = SCNNode()
        tempNode.simdTransform = target.simdWorldTransform
        tempNode.simdOrientation *= simd_quatf(
            angle: .pi / 5, axis: SIMD3<Float>(1, 0, 0))

        // Extract forward direction from new transform
        let cameraPosition = SIMD3<Float>(
            target.simdWorldTransform.columns.3.x,
            target.simdWorldTransform.columns.3.y,
            target.simdWorldTransform.columns.3.z)

        let rotatedTransform = tempNode.simdWorldTransform
        let forward = -SIMD3<Float>(
            rotatedTransform.columns.2.x,
            rotatedTransform.columns.2.y,
            rotatedTransform.columns.2.z)

        let distance: Float = 1
        let targetPosition = cameraPosition + forward * distance
        node.simdPosition = targetPosition

        SCNTransaction.commit()
    }

    private func populateCaretInEmptyText(bookNode: BookNode) {
        if bookNode.text.length > 1 {
            return
        }
        let caret = NSAttributedString(
            string: " ",
            attributes: [
                .backgroundColor: UIColor(
                    red: 0.2922, green: 0.4922, blue: 0.85, alpha: 1.0),
                .init("caret"): true,
            ])
        bookNode.setText(caret)
    }

    private func updateText(in textView: UITextView) {
        let originalText = textView.text ?? ""
        let attributedString = NSMutableAttributedString(string: originalText)

        if let selectedRange = textView.selectedTextRange {
            let cursorOffset = textView.offset(
                from: textView.beginningOfDocument, to: selectedRange.start)
            let caret = NSAttributedString(
                string: " ",
                attributes: [
                    .backgroundColor: UIColor(
                        red: 0.2922, green: 0.4922, blue: 0.85, alpha: 1.0),
                    .init("caret"): true,
                ])

            // Insert and update
            attributedString.insert(caret, at: cursorOffset)
            self.bookManager.write(text: attributedString)
        }
    }

    override func viewWillTransition(
        to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        self.positionJoystick(size: size)
    }
}

extension GameViewController {
    func addLight() {
        let lampLight = SCNLight()
        lampLight.type = .omni
        lampLight.color = UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1.0)
        lampLight.intensity = 7
        lampLight.attenuationStartDistance = 0
        lampLight.attenuationEndDistance = 15
        lampLight.shadowMode = .deferred
        lightNode.light = lampLight
        lightNode.name = "light"
        scene.rootNode.addChildNode(lightNode)

        let bulbMaterial = SCNMaterial()
        bulbMaterial.diffuse.contents = UIColor.white
        bulbMaterial.emission.contents = colors.getCurrent()
        bulbMaterial.roughness.contents = 0.0
        bulbMaterial.metalness.contents = 0.0
        bulbMaterial.shininess = 1.0
        bulbMaterial.lightingModel = .physicallyBased

        let bulb = SCNCone(topRadius: 0, bottomRadius: 0.03, height: 0.09)
        bulb.materials = [bulbMaterial]
        bulbNode.geometry = bulb
        bulbNode.position = lightNode.position
        bulbNode.name = "bulb"
        bulbNode.castsShadow = false

        scene.rootNode.addChildNode(bulbNode)

        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.color = UIColor.white
        directionalLightNode.light?.intensity = 1000
        directionalLightNode.light?.castsShadow = true
        directionalLightNode.light?.shadowMode = .deferred
        directionalLightNode.light?.shadowColor = UIColor.black
            .withAlphaComponent(0.5)
        directionalLightNode.light?.shadowMapSize = .init(
            width: 2048, height: 2048)

        directionalLightNode.light?.shadowRadius = 8
        directionalLightNode.light?.shadowBias = 0.1
        directionalLightNode.light?.automaticallyAdjustsShadowProjection = true
        directionalLightNode.light?.maximumShadowDistance = 100
        directionalLightNode.light?.shadowSampleCount = 64
        directionalLightNode.position = SCNVector3(0, 20, 0)
        directionalLightNode.light?.shadowMode = .deferred

        directionalLightNode.eulerAngles = SCNVector3Make(-Float.pi / 3, 0, 0)

        // Add it to your scene
        scene.rootNode.addChildNode(directionalLightNode)

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 70
        ambientLight.light?.color = UIColor.white
        scene.rootNode.addChildNode(ambientLight)

    }
    
}
extension GameViewController {
    func addParticleSystem() {
        let starParticleSystem = SCNParticleSystem()

        // 💫 Basic Appearance
        starParticleSystem.particleImage = nil  // Just glowing white points
        starParticleSystem.particleColor = UIColor.white
        starParticleSystem.particleSize = 0.1

        // 🌌 Emission Setup
        starParticleSystem.emitterShape = SCNSphere(radius: 200)
        starParticleSystem.birthRate = 200  // Number of stars
        starParticleSystem.loops = false  // Emit once and stop
        starParticleSystem.emissionDuration = 0.01
        starParticleSystem.particleLifeSpan = .infinity
        starParticleSystem.particleVelocity = 0

        // ✨ Optional: Add slight twinkle
        starParticleSystem.particleColorVariation = SCNVector4(
            0.5, 0.1, 0.5, 0.3)
        starParticleSystem.blendMode = .additive
        starParticleSystem.isLightingEnabled = false
        starParticleSystem.isLocal = true

        particleNode.position = SCNVector3(x: 0, y: 0, z: 0)
        particleNode.addParticleSystem(starParticleSystem)
        scene.rootNode.addChildNode(particleNode)
    }

}

extension GameViewController {
    func addCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: cameraY, z: 0)
        cameraNode.look(at: SCNVector3(1, cameraY + 1, -1.1))
        cameraNode.camera?.fieldOfView = 90
        cameraNode.camera?.zNear = 0.001
        cameraNode.camera?.zFar = 600
        scene.rootNode.addChildNode(cameraNode)
    }
}
extension GameViewController {
    func saveCameraPositionToDataBase() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Camera")
        do {
            let results = try context.fetch(request)
            guard let position = results.first else {
                let camera = NSEntityDescription.insertNewObject(
                    forEntityName: "Camera", into: self.context)
                camera.setValue(cameraNode.position.x, forKey: "x")
                camera.setValue(cameraNode.position.z, forKey: "z")
                return
            }
            position.setValue(cameraNode.position.x, forKey: "x")
            position.setValue(cameraNode.position.z, forKey: "z")
            try context.save()
        } catch {
            print("error \(error)")
        }
    }

    func loadCameraPositionFromDataBase() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Camera")
        do {
            let results = try context.fetch(request)
            guard let savedCamera = results.first else {
                print("No saved camera position found.")
                return
            }

            if let x = savedCamera.value(forKey: "x") as? Float,
                let z = savedCamera.value(forKey: "z") as? Float
            {
                cameraNode.position.x = x
                cameraNode.position.z = z
            } else {
                print("Saved position data is incomplete.")
            }
        } catch {
            print("Failed to load camera position: \(error)")
        }
    }
}

extension GameViewController {
    func setupHiddenText() {
        hiddenTextView.delegate = self
        hiddenTextView.isHidden = false
        hiddenTextView.isEditable = true
        hiddenTextView.isSelectable = true
        hiddenTextView.isUserInteractionEnabled = true
        hiddenTextView.inputView = nil
        hiddenTextView.returnKeyType = .default
        hiddenTextView.autocorrectionType = .no
        hiddenTextView.autocapitalizationType = .none
        hiddenTextView.spellCheckingType = .no
        hiddenTextView.text = ""
        view.addSubview(hiddenTextView)
    }
}

extension GameViewController {
    func setupCreateBookButton() {
        let createBookButton = UIButton(type: .system)
        createBookButton.translatesAutoresizingMaskIntoConstraints = false
        createBookButton.titleLabel?.font = UIFont.systemFont(
            ofSize: 20, weight: .semibold)
        createBookButton.setTitleColor(.white, for: .normal)

        // Moon-like gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(white: 0.9, alpha: 0.1).cgColor,
            UIColor(white: 1.0, alpha: 0.15).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.8, y: 0.8)
        gradientLayer.cornerRadius = view.bounds.width / 8

        // Shadow = lunar glow
        createBookButton.backgroundColor = UIColor(white: 1.0, alpha: 0.05)
        createBookButton.layer.cornerRadius = view.bounds.width / 8
        createBookButton.layer.borderColor =
            UIColor.white.withAlphaComponent(0.2).cgColor
        createBookButton.layer.borderWidth = 1.0
        createBookButton.layer.shadowColor = UIColor.white.cgColor
        createBookButton.layer.shadowOpacity = 0.3
        createBookButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        createBookButton.layer.shadowRadius = 12

        // Add icon (optional)
        let icon = UIImage(
            systemName: "book",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 30, weight: .light))
        createBookButton.setImage(icon, for: .normal)
        createBookButton.tintColor = .white

        gradientLayer.frame = createBookButton.bounds
        createBookButton.layer.insertSublayer(gradientLayer, at: 0)
        createBookButton.addTarget(
            self, action: #selector(self.createBookButtonTapped),
            for: .touchUpInside)
        view.addSubview(createBookButton)
        NSLayoutConstraint.activate([
            createBookButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            createBookButton.rightAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -15),
            createBookButton.heightAnchor.constraint(
                equalTo: view.widthAnchor, multiplier: 0.25),
            createBookButton.widthAnchor.constraint(
                equalTo: view.widthAnchor, multiplier: 0.25),
        ])
        self.createBookButton = createBookButton
    }
    func switchCreateBookButtonIcon(to icon: String) {
        let image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 30, weight: .light))
        self.createBookButton?.setImage(image, for: .normal)
    }
}

extension GameViewController {
    func positionJoystick(size: CGSize) {
        let padding = min(size.width * 0.1, 20)
        let x = padding
        let y = size.height - movementJoyStick.baseSize - padding
        movementJoyStick.setCoords(
            x: x,
            y: y
        )
    }
    func setupJoystick() {
        positionJoystick(
            size: .init(width: view.bounds.width, height: view.bounds.height))
        movementJoyStick.backgroundColor = .clear
        view.addSubview(movementJoyStick)
    }
}
