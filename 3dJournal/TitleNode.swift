//
//  TitleNode.swift
//  3dJournal
//
//  Created by Trevor Clute on 6/10/25.
//

import Foundation
import SceneKit

class TitleNode: SCNNode {
    var attributedString:NSAttributedString = .init(string: "")
    func setTitle(title:String){
        self.attributedString = self.createAttributedString(string: title)
        let text = createTextGeometry(text: self.attributedString)
        self.geometry = text
    }
    
    private func createTextGeometry(text:NSAttributedString) -> SCNText{
        let text = SCNText(string: text, extrusionDepth: 0.2)
        text.alignmentMode = "center"
        text.font = UIFont.systemFont(ofSize: 4)
        text.flatness = 0.1
        text.firstMaterial?.diffuse.contents = UIColor.white
        return text
    }
    
    func createAttributedString(string:String) -> NSAttributedString{
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrString = NSAttributedString(string: string, attributes: [.paragraphStyle : paragraphStyle])
        return attrString
    }
    
    init(bookNode:BookNode, scene:SCNScene, title:String){
        super.init()
        
        let attrString = createAttributedString(string:title)
        self.attributedString = attrString
        let text = createTextGeometry(text: attrString)
        self.geometry = text
        self.scale = SCNVector3(0.05, 0.05, 0.05)
        let (min, max) = text.boundingBox
        let dx = (max.x - min.x) / 2 + min.x
        let dy = (max.y - min.y) / 2 + min.y
        let dz = (max.z - min.z) / 2 + min.z
        self.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        self.position = bookNode.position
        self.position.y += 1.5
        let constraints = SCNBillboardConstraint()
        self.constraints = [constraints]
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
