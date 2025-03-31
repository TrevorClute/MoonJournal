//
//  Book.swift
//  3dJournal
//
//  Created by Trevor Clute on 4/4/25.
//

import Foundation
import SceneKit

enum BookStatus {
    case open
    case closed
}

let bookWidth: CGFloat = 0.2
let bookHeight: CGFloat = 1.0
let booklength: CGFloat = 0.7
let coverThickness: CGFloat = 0.05
let backOfBookZIndex = Float(-(booklength / 2) + coverThickness / 2)
let pageWidth = CGFloat(
    Float(bookWidth) / 2.0 - Float(coverThickness) / 2.0)

class BookNode: SCNNode {
    static var pageMaterial: SCNMaterial {
        let pm = SCNMaterial()
        pm.diffuse.contents = UIColor.white
        pm.shininess = 0.1
        pm.specular.contents = UIColor.white
        pm.reflective.contents = nil
        pm.metalness.contents = nil
        pm.roughness.contents = 1.0
        pm.lightingModel = .physicallyBased
        return pm
    }
    var status: BookStatus = .closed
    var color:UIColor = .black
    var isAnimating = false
    var defaultPosition: SCNVector3 = SCNVector3Zero
    var text: NSAttributedString = .init(string: "")
    var textMaterials: [SCNMaterial] = []
    let maxPageCharacterCount = 445
    var leftPageIndex = 0
    var titleNode:TitleNode?
    var id:UUID = UUID()

    init(position: SCNVector3, color: UIColor) {
        super.init()
        self.name = "book"
        var newpos = position
        if newpos.y < 1 {
            newpos.y = 1
        }
        self.position = newpos
        self.defaultPosition = newpos
        self.color = color
        createTextMaterials()

        // Create materials
        let coverMaterial = SCNMaterial()
        coverMaterial.diffuse.contents = color
        coverMaterial.normal.intensity = 0.5
        coverMaterial.roughness.contents = 0.8
        coverMaterial.metalness.contents = 0.1
        coverMaterial.lightingModel = .physicallyBased

        // Create spine (back of the book)
        let spineNode = SCNNode(
            geometry: SCNBox(
                width: bookWidth,
                height: bookHeight,
                length: coverThickness,
                chamferRadius: 0.01)
        )
        spineNode.name = "spine"
        spineNode.geometry?.materials = [coverMaterial]
        spineNode.position = SCNVector3(0, 0, -backOfBookZIndex)
        self.addChildNode(spineNode)

        // Create left cover
        let rightCover = SCNNode(
            geometry: SCNBox(
                width: coverThickness,
                height: bookHeight,
                length: booklength,
                chamferRadius: 0.01)
        )
        rightCover.geometry?.materials = [coverMaterial]
        rightCover.position = SCNVector3(
            -Float(bookWidth / 2 - coverThickness / 2), 0, -backOfBookZIndex)
        rightCover.pivot = SCNMatrix4MakeTranslation(
            Float(coverThickness) / 2, 0, -backOfBookZIndex)
        rightCover.name = "rightCover"
        self.addChildNode(rightCover)

        // Create right cover
        let leftCover = rightCover.clone()
        leftCover.position = SCNVector3(
            Float(bookWidth / 2 - coverThickness / 2), 0, -backOfBookZIndex)
        leftCover.pivot = SCNMatrix4MakeTranslation(
            -Float(coverThickness) / 2, 0, -backOfBookZIndex)
        leftCover.name = "leftCover"
        self.addChildNode(leftCover)

        let rightPage = SCNNode(
            geometry: SCNBox(
                width: pageWidth,
                height: bookHeight - 0.01,
                length: booklength - coverThickness,
                chamferRadius: 0)
        )

        rightPage.position = SCNVector3(
            Float(bookWidth / 2 - coverThickness / 2 - pageWidth), 0,
            -backOfBookZIndex - Float(coverThickness / 2))
        rightPage.pivot = SCNMatrix4MakeTranslation(
            Float(pageWidth) / 2, 0, -backOfBookZIndex)
        rightPage.name = "rightPage"
        self.addChildNode(rightPage)
        setRightPageText(index: leftPageIndex + 1)

        let leftPage = SCNNode(
            geometry: SCNBox(
                width: pageWidth,
                height: bookHeight - 0.01,
                length: booklength - coverThickness,
                chamferRadius: 0)
        )
        leftPage.position = SCNVector3(
            -Float(bookWidth / 2 - coverThickness / 2 - pageWidth), 0,
            -backOfBookZIndex - Float(coverThickness / 2))
        leftPage.pivot = SCNMatrix4MakeTranslation(
            -Float(pageWidth) / 2, 0, -backOfBookZIndex)
        leftPage.name = "leftPage"
        self.addChildNode(leftPage)
        setLeftPageText(index: leftPageIndex)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func getSinglePageMaterial(index: Int) -> SCNMaterial {
        return textMaterials.indices.contains(index)
            ? textMaterials[index] : Self.pageMaterial
    }

    private func setLeftPageText(index: Int) {
        guard
            let leftPage = self.childNode(
                withName: "leftPage", recursively: false)
        else { return }
        leftPage.geometry?.materials = [
            Self.pageMaterial, Self.pageMaterial, Self.pageMaterial,
            getSinglePageMaterial(index: index), Self.pageMaterial,
            Self.pageMaterial,
        ]
    }

    private func setRightPageText(index: Int) {
        guard
            let rightPage = self.childNode(
                withName: "rightPage", recursively: false)
        else { return }
        rightPage.geometry?.materials = [
            Self.pageMaterial, getSinglePageMaterial(index: index),
            Self.pageMaterial, Self.pageMaterial, Self.pageMaterial,
            Self.pageMaterial,
        ]
    }

    func nextPage() -> Bool {
        if leftPageIndex >= textMaterials.count - 2 {
            return false
        }
        self.leftPageIndex += 2
        guard
            let rightPage = self.childNode(
                withName: "rightPage", recursively: false)
        else { return false }
        let cloneRightPage = rightPage.clone()
        cloneRightPage.pivot = SCNMatrix4MakeTranslation(
            0, 0, -backOfBookZIndex)
        let cloneGeometry = rightPage.geometry!.copy() as! SCNBox
        cloneGeometry.materials = [
            Self.pageMaterial, getSinglePageMaterial(index: leftPageIndex - 1),
            Self.pageMaterial, getSinglePageMaterial(index: leftPageIndex),
            Self.pageMaterial, Self.pageMaterial,
        ]
        cloneGeometry.width = 0.01
        cloneRightPage.geometry = cloneGeometry
        self.addChildNode(cloneRightPage)
        let animation = CABasicAnimation(keyPath: "eulerAngles.y")
        animation.fromValue = 80 * CGFloat.pi / 180
        animation.toValue = -80 * CGFloat.pi / 180
        animation.duration = 0.6
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        cloneRightPage.addAnimation(animation, forKey: "rightAnimation")
        self.setRightPageText(index: self.leftPageIndex + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            cloneRightPage.removeAllActions()
            cloneRightPage.removeAllAnimations()
            cloneRightPage.removeFromParentNode()
            if let self = self {
                self.setLeftPageText(index: self.leftPageIndex)
            }
        }
        return true
    }
    func setText(_ text: NSAttributedString) {
        self.text = text
        let newMats = self.createTextMaterials()
        let oldMatsCount = self.textMaterials.count
        self.setTextMaterials(newMats)
        self.setLeftPageText(index: self.leftPageIndex)
        self.setRightPageText(index: self.leftPageIndex + 1)
        if(newMats.count > oldMatsCount && oldMatsCount % 2 == 0){
            self.nextPage()
            return
        }
        
        if(newMats.count < oldMatsCount && oldMatsCount % 2 == 1){
            self.previousPage()
            return
        }
        self.setLeftPageText(index: self.leftPageIndex)
        self.setRightPageText(index: self.leftPageIndex + 1)
    }

    func previousPage() {
        if leftPageIndex <= 0 {
            return
        }
        self.leftPageIndex -= 2
        guard
            let leftPage = self.childNode(
                withName: "leftPage", recursively: false)
        else { return }
        let cloneLeftPage = leftPage.clone()
        cloneLeftPage.pivot = SCNMatrix4MakeTranslation(0, 0, -backOfBookZIndex)
        let cloneGeometry = leftPage.geometry!.copy() as! SCNBox
        cloneGeometry.materials = [
            Self.pageMaterial, getSinglePageMaterial(index: leftPageIndex + 1),
            Self.pageMaterial, getSinglePageMaterial(index: leftPageIndex + 2),
            Self.pageMaterial, Self.pageMaterial,
        ]
        cloneGeometry.width = 0.01
        cloneLeftPage.geometry = cloneGeometry
        self.addChildNode(cloneLeftPage)
        let animation = CABasicAnimation(keyPath: "eulerAngles.y")
        animation.fromValue = -80 * CGFloat.pi / 180
        animation.toValue = 80 * CGFloat.pi / 180
        animation.duration = 0.6
        animation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        cloneLeftPage.addAnimation(animation, forKey: "leftAnimation")
        self.setLeftPageText(index: self.leftPageIndex)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            cloneLeftPage.removeAllActions()
            cloneLeftPage.removeAllAnimations()
            cloneLeftPage.removeFromParentNode()
            if let self = self {
                self.setRightPageText(index: self.leftPageIndex + 1)
            }
        }
    }

    private func startOpenAnimation(
        duration: TimeInterval = 0.7
    ) {
        guard
            let leftCover = self.childNode(
                withName: "leftCover", recursively: false),
            let rightCover = self.childNode(
                withName: "rightCover", recursively: false),
            let leftPage = self.childNode(
                withName: "leftPage", recursively: false),
            let rightPage = self.childNode(
                withName: "rightPage", recursively: false)
        else {
            return
        }
        // Animate left cover (opens to -110 degrees)
        let leftAnimation = CABasicAnimation(keyPath: "eulerAngles.y")
        leftAnimation.fromValue = 0
        leftAnimation.toValue = -80 * CGFloat.pi / 180
        leftAnimation.duration = duration
        leftAnimation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        leftAnimation.fillMode = .forwards
        leftAnimation.isRemovedOnCompletion = false
        leftCover.addAnimation(leftAnimation, forKey: "openLeft")
        leftPage.addAnimation(leftAnimation, forKey: "openLeft")

        // Animate right cover (opens to 110 degrees)
        let rightAnimation = leftAnimation.copy() as! CABasicAnimation
        rightAnimation.toValue = 80 * CGFloat.pi / 180
        rightCover.addAnimation(rightAnimation, forKey: "openRight")
        rightPage.addAnimation(rightAnimation, forKey: "openRight")
    }

    private func startCloseAnimation(
        duration: TimeInterval = 0.7
    ) {
        guard
            let leftCover = self.childNode(
                withName: "leftCover", recursively: true),
            let rightCover = self.childNode(
                withName: "rightCover", recursively: true),
            let leftPage = self.childNode(
                withName: "leftPage", recursively: true),
            let rightPage = self.childNode(
                withName: "rightPage", recursively: true)
        else {
            return
        }

        // Animate left cover (opens to -110 degrees)
        let leftAnimation = CABasicAnimation(keyPath: "eulerAngles.y")
        leftAnimation.fromValue = -80 * CGFloat.pi / 180
        leftAnimation.toValue = 0
        leftAnimation.duration = duration
        leftAnimation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)
        leftAnimation.fillMode = .forwards
        leftAnimation.isRemovedOnCompletion = false
        leftCover.addAnimation(leftAnimation, forKey: "openLeft")
        leftPage.addAnimation(leftAnimation, forKey: "openLeft")
        // Animate right cover (opens to 110 degrees)
        let rightAnimation = leftAnimation.copy() as! CABasicAnimation
        rightAnimation.fromValue = 80 * CGFloat.pi / 180
        rightCover.addAnimation(rightAnimation, forKey: "openRight")
        rightPage.addAnimation(rightAnimation, forKey: "openLeft")
    }

    private func bring(inFrontOf target: SCNNode) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(
            name: .linear)
        let tempNode = SCNNode()
        tempNode.simdTransform = target.simdWorldTransform
        tempNode.simdOrientation *= simd_quatf(
            angle: .pi / 14, axis: SIMD3<Float>(1, 0, 0))

        // Extract forward direction from new transform
        let rotatedTransform = tempNode.simdWorldTransform
        let cameraPosition = SIMD3<Float>(
            target.simdWorldTransform.columns.3.x,
            target.simdWorldTransform.columns.3.y,
            target.simdWorldTransform.columns.3.z)

        let forward = -SIMD3<Float>(
            rotatedTransform.columns.2.x,
            rotatedTransform.columns.2.y,
            rotatedTransform.columns.2.z)

        let distance: Float = 1.5
        let targetPosition = cameraPosition + forward * distance
        self.simdPosition = targetPosition
        SCNTransaction.commit()
    }

    public func open(cameraNode: SCNNode) {
        if self.isAnimating {
            return
        }
        self.isAnimating = true
        self.status = .open

        let spine = self.childNode(withName: "spine", recursively: false)
        self.bring(inFrontOf: cameraNode)
        self.look(
            at: cameraNode.position, up: SCNVector3(x: 0, y: 1, z: 0),
            localFront: SCNVector3(0, 0, -1))
        spine?.position.z = -backOfBookZIndex + Float(coverThickness) / 2
        self.startOpenAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.isAnimating = false
        }
    }

    public func close(cameraNode: SCNNode) {
        if self.isAnimating {
            return
        }
        self.isAnimating = true
        self.status = .closed

        let fullRange = NSRange(location: 0, length: self.text.length)
        let mutableText = NSMutableAttributedString(attributedString: self.text)
        mutableText.enumerateAttribute(.init("caret"), in: fullRange) { value, range, _ in
            if value as? Bool == true {
                mutableText.deleteCharacters(in: range)
            }
        }
        
        self.setText(mutableText)

        let spine = self.childNode(withName: "spine", recursively: true)
        self.position = self.defaultPosition
        self.look(
            at: cameraNode.position, up: SCNVector3(x: 0, y: 1, z: 0),
            localFront: SCNVector3(1, 0, 0))
        spine?.position.z = -backOfBookZIndex
        self.startCloseAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.isAnimating = false
        }
        return
    }

    func textToImage(
        text: NSAttributedString, size: CGSize = CGSize(width: 512, height: 512)
    ) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)

        // Fill background if needed
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Text attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: BookManager.fontSize),
//            .foregroundColor: UIColor.black,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .left
                return style
            }(),
        ]
        let mutableText = NSMutableAttributedString(attributedString: text)
        mutableText.addAttributes(attributes, range: NSRange(location: 0, length: mutableText.length))

        let rect = CGRect(origin: .zero, size: size)
//        text.draw(in: rect.insetBy(dx: 20, dy: 20), withAttributes: attributes)
        mutableText.draw(in: rect.insetBy(dx: 20, dy: 20))

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }

    func createTextMaterials() -> [SCNMaterial] {
        let pageSize = CGSize(width: 512 - 40, height: 512 - 40) // account for padding
        let font = UIFont.systemFont(ofSize: BookManager.fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font:font,
        ]

        let attributedText = NSMutableAttributedString(attributedString: text)
        attributedText.addAttributes(attributes, range: NSRange(location: 0, length: attributedText.length))

        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        var materials: [SCNMaterial] = []
        var pageOffset = 0

        while pageOffset < layoutManager.numberOfGlyphs {
            let textContainer = NSTextContainer(size: pageSize)
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = 0
            textContainer.lineBreakMode = .byWordWrapping
            layoutManager.addTextContainer(textContainer)

            // Determine range for this container
            let glyphRange = layoutManager.glyphRange(for: textContainer)

            let nsRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
//            let pageText = (text as NSString).substring(with: nsRange)
            let pageText = text.attributedSubstring(from: nsRange)

            let image = textToImage(text: pageText)
            let material = SCNMaterial()
            material.diffuse.contents = image
            material.shininess = 0.1
            material.roughness.contents = 1.0
            material.lightingModel = .physicallyBased

            materials.append(material)
            pageOffset = NSMaxRange(glyphRange)
        }

        return materials
    }


    func setTextMaterials(_ mats: [SCNMaterial]) {
        self.textMaterials = mats
    }
}

