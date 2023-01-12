import UIKit

public enum FrameCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

public enum FrameBorder {
    case left
    case right
    case top
    case bottom
}

public class VideoFeedLayoutView: UIView {
    
    private struct Constant {
        static let padding = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
    }
    
    private var selfFeedView: UIView = UIView()
    private var thumbnailFrameView = ThumbnailVideoView()
    
    public var thumbnailFeedView: UIView? {
        didSet {
            if let view = thumbnailFeedView,
               view !== oldValue {
                thumbnailFrameView.pinSubview(view)
            } else {
                oldValue?.removeFromSuperview()
            }
        }
    }
    
    public var feedView: UIView? {
        didSet {
            if let view = feedView,
               view !== oldValue {
                selfFeedView.pinSubview(view)
            } else {
                oldValue?.removeFromSuperview()
            }
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        addSubview(selfFeedView)
        addSubview(thumbnailFrameView)
        
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.selfFeedView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        self.thumbnailFrameView.frame = bounds.inset(by: Constant.padding)
        
    }
    
}

internal class ThumbnailVideoView: UIView {
    
    private struct Constant {
        static let thumbnailViewSize = CGSize(width: 120, height: 160)
        static let snapAnimDuration: TimeInterval = 0.325
        static let snapAnimMinDuration: TimeInterval = 0.125
    }
    
    private var thumbnailView = UIView()
    
    private var isHoldingTouch: Bool = false
    /// This is for tracking the distance between finger and center of `thumbnailView` to maintain distance when dragging happen.
    private var centerFingerDiff: CGPoint = .zero
    
    /**
     
     Ratio of the thumbnail frame to the corner to decide if the thumbnail view should snap to a corner instead of just a border.
     
     - Note: Set the value to `0` to disable corner snapping but only the border.
     
     */
    public var cornerSnappingRatio: CGFloat = 0.1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        thumbnailView.backgroundColor = UIColor.yellow
        addSubview(thumbnailView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let snappingOrigin = calculatedSnappingThumbnailOrigin()
        thumbnailView.frame = CGRect(origin: snappingOrigin,
                                     size: Constant.thumbnailViewSize)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isHoldingTouch = true
        if let touch = touches.first {
            let location = touch.location(in: thumbnailView)
            let center = CGPoint(x: thumbnailView.frame.width / 2,
                                 y: thumbnailView.frame.height / 2)
            centerFingerDiff = CGPoint(x: location.x - center.x,
                                       y: location.y - center.y)
        }
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            if thumbnailView.frame.contains(location) {
                thumbnailView.center = CGPoint(x: location.x - centerFingerDiff.x,
                                               y: location.y - centerFingerDiff.y)
            }
        }
        super.touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isHoldingTouch = false
        centerFingerDiff = .zero
        
        let snappingOrigin = calculatedSnappingThumbnailOrigin()
        let duration = snappingAnimationDuration(targetOrigin: snappingOrigin)
        UIView.animate(withDuration: duration, delay: 0) {
            self.thumbnailView.frame.origin = snappingOrigin
        }
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
    
}

// MARK: - Calcute Snapping Frame
extension ThumbnailVideoView {
    
    private func calculatedSnappingThumbnailOrigin() -> CGPoint {
        /// if it's in `cornerSnappingRatio` ratio of the corner, snap to the corner.
        if let corner = self.snappingCorner() {
            return snappingCornerFrame(corner: corner, size: thumbnailView.frame.size).origin
        }
        /// else snapping to the closet border
        var snappingSide: FrameBorder = .top
        let distances: [CGFloat: FrameBorder] = [thumbnailView.center.x: .left,    thumbnailView.center.y: .top,
                                                 frame.width - thumbnailView.center.x: .right,
                                                 frame.height - thumbnailView.center.y: .bottom]
        if let minDistances = distances.keys.min(),
            let minSide = distances[minDistances] {
            snappingSide = minSide
        }
        var x: CGFloat = thumbnailView.frame.origin.x
        var y: CGFloat = thumbnailView.frame.origin.y
        switch snappingSide {
        case .top: y = 0
        case .bottom: y = frame.height - thumbnailView.frame.height
        case .left: x = 0
        case .right: x = frame.width - thumbnailView.frame.width
        }
        return CGPoint(x: x, y: y)
    }
    
    private func snappingCorner() -> FrameCorner? {
        let rect = thumbnailView.frame
        let size = CGSize(width: frame.width * cornerSnappingRatio,
                          height: frame.height * cornerSnappingRatio)
        if snappingCornerFrame(corner: .topLeft, size: size).intersects(rect) {
            return .topLeft
        } else if snappingCornerFrame(corner: .topRight, size: size).intersects(rect) {
            return .topRight
        } else if snappingCornerFrame(corner: .bottomLeft, size: size).intersects(rect) {
            return .bottomLeft
        } else if snappingCornerFrame(corner: .bottomRight, size: size).intersects(rect) {
            return .bottomRight
        }
        return nil
    }
    
    /**
     The frame to check if the thumnail overlap with, if yes, can consider to snap to it
     */
    private func snappingCornerFrame(corner: FrameCorner, size: CGSize) -> CGRect {
        switch corner {
        case .topLeft:
            return CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        case .topRight:
            return CGRect(origin: CGPoint(x: frame.width - size.width, y: 0),
                          size: size)
        case .bottomLeft:
            return CGRect(origin: CGPoint(x: 0, y: frame.height - size.height),
                          size: size)
        case .bottomRight:
            return CGRect(origin: CGPoint(x: frame.width - size.width,
                                          y: frame.height - size.height),
                          size: size)
        }
    }
    
}

// MARK: Animation
extension ThumbnailVideoView {
    
    private func snappingAnimationDuration(targetOrigin: CGPoint) -> TimeInterval {
        let longest = sqrt((center.x * center.x) + (center.y * center.y))
        let tCenterX = abs(targetOrigin.x - thumbnailView.center.x)
        let tCenterY = abs(targetOrigin.y - thumbnailView.center.y)
        let current = sqrt((tCenterX * tCenterX) + (tCenterY * tCenterY))
        return min(Constant.snapAnimMinDuration, (current * Constant.snapAnimDuration) / longest)
    }
    
}

