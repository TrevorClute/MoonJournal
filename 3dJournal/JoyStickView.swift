//
//  JoyStickView.swift
//  3dJournal
//
//  Created by Trevor Clute on 4/4/25.
//

import UIKit

class JoystickView: UIView {

    var onMove: ((CGVector) -> Void)? = nil
    let baseView = UIView()
    let handleView = UIView()
    var handleSize: CGFloat = 50
    var baseSize: CGFloat = 120
    var isTouchActive = false
    var offset: CGVector = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    init(handleSize: CGFloat, baseSize:CGFloat) {
        super.init(frame: .init(x: 0, y: 0, width: baseSize, height: baseSize))
        self.handleSize = handleSize
        self.baseSize = baseSize
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setCoords(x:CGFloat, y:CGFloat){
        self.frame = CGRect(x: x, y: y, width: baseSize, height: baseSize)
    }
 

    private func setup() {
        // Setup base view (moon pad look)
        baseView.frame = CGRect(x: 0, y: 0, width: baseSize, height: baseSize)
        baseView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        baseView.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        baseView.layer.cornerRadius = baseSize / 2
        baseView.layer.borderWidth = 1
        baseView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        baseView.layer.shadowColor = UIColor.white.cgColor
        baseView.layer.shadowOpacity = 0.2
        baseView.layer.shadowOffset = CGSize(width: 0, height: 2)
        baseView.layer.shadowRadius = 8
        addSubview(baseView)

        // Setup handle view (glowy floating orb)
        handleView.frame = CGRect(x: 0, y: 0, width: handleSize, height: handleSize)
        handleView.center = baseView.center
        handleView.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
        handleView.layer.cornerRadius = handleSize / 2
        handleView.layer.borderWidth = 1
        handleView.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        handleView.layer.shadowColor = UIColor.white.cgColor
        handleView.layer.shadowOpacity = 0.4
        handleView.layer.shadowOffset = CGSize(width: 0, height: 3)
        handleView.layer.shadowRadius = 10
        addSubview(handleView)
    }


    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            isTouchActive = true
            updateHandle(position: touch.location(in: self))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTouchActive, let touch = touches.first {
            updateHandle(position: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetHandle()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetHandle()
    }

    private func updateHandle(position: CGPoint) {
        let center = baseView.center
        var offset = CGPoint(x: position.x - center.x, y: position.y - center.y)
        let distance = sqrt(offset.x * offset.x + offset.y * offset.y)
        let maxDistance = baseSize / 2

        if distance > maxDistance {
            let angle = atan2(offset.y, offset.x)
            offset.x = cos(angle) * maxDistance
            offset.y = sin(angle) * maxDistance
        }

        let newPosition = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
        handleView.center = newPosition

        let normalized = CGVector(dx: offset.x / maxDistance, dy: offset.y / maxDistance)
        self.offset = normalized
        onMove?(normalized)
    }

    private func resetHandle() {
        UIView.animate(withDuration: 0.2) {
            self.handleView.center = self.baseView.center
        }
        onMove?(CGVector.zero)
        self.offset = .zero
        isTouchActive = false
    }
}
