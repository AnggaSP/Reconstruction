//  Copyright © 2016 MobDesign. All rights reserved.
//
//  Copyright © 2021 Angga Satya Putra. All rights reserved.

import UIKit

@IBDesignable
class CameraButton: UIButton {
    var pathLayer: CAShapeLayer!
    let animationDuration = 0.4

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    func setup() {
        // Add a shape layer for the inner shape to be able to animate it
        self.pathLayer = CAShapeLayer()

        // Show the right shape for the current state of the control
        self.pathLayer.path = self.currentInnerPath().cgPath

        // Don't use a stroke color, which would give a ring around the inner circle
        self.pathLayer.strokeColor = nil

        // Set the color for the inner shape
        self.pathLayer.fillColor = UIColor.red.cgColor

        // Add the path layer to the control layer so it gets drawn
        self.layer.addSublayer(self.pathLayer)

        // Clear the title
        self.setTitle("", for: UIControl.State.normal)

        // Lock the size to match the size of the camera button
        self.addConstraint(NSLayoutConstraint(item: self,
                                              attribute: .width,
                                              relatedBy: .equal,
                                              toItem: nil,
                                              attribute: .width,
                                              multiplier: 1,
                                              constant: 66.0))
        self.addConstraint(NSLayoutConstraint(item: self,
                                              attribute: .height,
                                              relatedBy: .equal,
                                              toItem: nil,
                                              attribute: .width,
                                              multiplier: 1,
                                              constant: 66.0))


        // Add out target for event handling
        self.addTarget(self, action: #selector(touchUpInside), for: UIControl.Event.touchUpInside)
        self.addTarget(self, action: #selector(touchDown), for: UIControl.Event.touchDown)
    }

    override var isSelected: Bool {
        didSet {
            // Change the inner shape to match the state
            let morph = CABasicAnimation(keyPath: "path")
            morph.duration = animationDuration
            morph.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

            // Change the shape according to the current state of the control
            morph.toValue = self.currentInnerPath().cgPath

            // Ensure the animation is not reverted once completed
            morph.fillMode = CAMediaTimingFillMode.forwards
            morph.isRemovedOnCompletion = false

            // Add the animation
            self.pathLayer.add(morph, forKey: "")
        }
    }

    @objc func touchUpInside(sender: UIButton) {
        // Create the animation to restore the color of the button
        let colorChange = CABasicAnimation(keyPath: "fillColor")
        colorChange.duration = animationDuration
        colorChange.toValue = UIColor.red.cgColor

        // Make sure that the color animation is not reverted once the animation is completed
        colorChange.fillMode = CAMediaTimingFillMode.forwards
        colorChange.isRemovedOnCompletion = false

        // Indicate which animation timing function to use, in this case ease in and ease out
        colorChange.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

        // Add the animation
        self.pathLayer.add(colorChange, forKey: "darkColor")

        // Change the state of the control to update the shape
        self.isSelected = !self.isSelected
    }

    @objc func touchDown(sender: UIButton) {
        /*
         * When the user touches the button, the inner shape should change transparency.
         * Create the animation for the fill color
         */
        let morph = CABasicAnimation(keyPath: "fillColor")
        morph.duration = animationDuration

        // Set the value we want to animate to
        morph.toValue = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5).cgColor

        // Ensure the animation does not get reverted once completed
        morph.fillMode = CAMediaTimingFillMode.forwards
        morph.isRemovedOnCompletion = false

        morph.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        self.pathLayer.add(morph, forKey: "")
    }

    override func draw(_ rect: CGRect) {
        // Always draw the outer ring, the inner control is drawn during the animations
        let outerRing = UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 60, height: 60))
        outerRing.lineWidth = 6
        UIColor.white.setStroke()
        outerRing.stroke()
    }

    func currentInnerPath () -> UIBezierPath {
        // Choose the correct inner path based on the control state
        var returnPath: UIBezierPath
        if (self.isSelected) {
            returnPath = self.innerSquarePath()
        } else {
            returnPath = self.innerCirclePath()
        }

        return returnPath
    }

    func innerCirclePath () -> UIBezierPath {
        return UIBezierPath(roundedRect: CGRect(x: 8, y: 8, width: 50, height: 50), cornerRadius: 25)
    }

    func innerSquarePath () -> UIBezierPath {
        return UIBezierPath(roundedRect: CGRect(x: 18, y: 18, width: 30, height: 30), cornerRadius: 4)
    }
}
