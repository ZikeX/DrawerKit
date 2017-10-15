import UIKit

final class PresentationController: UIPresentationController {
    let configuration: DrawerConfiguration // intentionally internal and immutable
    private var lastDrawerY: CGFloat = 0
    private var containerViewDismissalTapGR: UITapGestureRecognizer?
    private var presentedViewDragGR: UIPanGestureRecognizer?
    private let inDebugMode: Bool

    init(presentingVC: UIViewController?, presentedVC: UIViewController,
         configuration: DrawerConfiguration, inDebugMode: Bool = false) {
        self.configuration = configuration
        self.inDebugMode = inDebugMode
        super.init(presentedViewController: presentedVC, presenting: presentingVC)
    }
}

extension PresentationController {
    override var frameOfPresentedViewInContainerView: CGRect {
        var frame: CGRect = .zero
        frame.size = size(forChildContentContainer: presentedViewController,
                          withParentContainerSize: containerViewSize)
        frame.origin.y = (supportsPartialExpansion ? drawerPartialY : 0)
        return frame
    }

    override func presentationTransitionWillBegin() {
        containerView?.backgroundColor = .clear
        setupContainerViewDismissalTapRecogniser()
        setupPresentedViewDragRecogniser()
        setupDebugHeightMarks()
        addCornerRadiusAnimationEnding(at: drawerPartialY)
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        if currentDrawerY == 0 || currentDrawerY == containerViewH {
            currentDrawerCornerRadius = 0
        }
    }

    override func dismissalTransitionWillBegin() {
        addCornerRadiusAnimationEnding(at: containerViewH)
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        removeContainerViewDismissalTapRecogniser()
        removePresentedViewDragRecogniser()
    }

    override func containerViewWillLayoutSubviews() {
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

private extension PresentationController {
    var containerViewSize: CGSize {
        return containerView?.bounds.size ?? .zero
    }

    var containerViewH: CGFloat {
        return containerViewSize.height
    }

    var drawerPartialH: CGFloat {
        guard let presentedVC = presentedViewController as? DrawerPresentable else { return 0 }
        return presentedVC.heightOfPartiallyExpandedDrawer
    }

    var drawerPartialY: CGFloat {
        return containerViewH - drawerPartialH
    }

    var upperMarkY: CGFloat {
        return (containerViewH - drawerPartialH) - upperMarkGap
    }

    var lowerMarkY: CGFloat {
        return drawerPartialY + lowerMarkGap
    }

    var currentDrawerY: CGFloat {
        get { return presentedView?.frame.origin.y ?? 0 }
        set { presentedView?.frame.origin.y = newValue }
    }

    var currentDrawerCornerRadius: CGFloat {
        get { return presentedView?.layer.cornerRadius ?? 0 }
        set { presentedView?.layer.cornerRadius = newValue }
    }
}

private extension PresentationController {
    func setupContainerViewDismissalTapRecogniser() {
        guard containerViewDismissalTapGR == nil else { return }
        let isDismissable = isDismissableByOutsideDrawerTaps
        let numTapsRequired = numberOfTapsForOutsideDrawerDismissal
        guard isDismissable && numTapsRequired > 0 else { return }
        let gr = UITapGestureRecognizer(target: self,
                                        action: #selector(handleContainerViewDismissalTap))
        gr.numberOfTouchesRequired = 1
        gr.numberOfTapsRequired = numTapsRequired
        containerView?.addGestureRecognizer(gr)
        containerViewDismissalTapGR = gr
    }

    func removeContainerViewDismissalTapRecogniser() {
        guard let gr = containerViewDismissalTapGR else { return }
        containerView?.removeGestureRecognizer(gr)
        containerViewDismissalTapGR = nil
    }

    @objc func handleContainerViewDismissalTap() {
        guard let gr = containerViewDismissalTapGR else { return }
        let tapY = gr.location(in: containerView).y
        guard tapY < currentDrawerY else { return }
        presentedViewController.dismiss(animated: true)
    }
}

private extension PresentationController {
    func setupPresentedViewDragRecogniser() {
        guard presentedViewDragGR == nil else { return }
        guard isDrawerDraggable else { return }
        let gr = UIPanGestureRecognizer(target: self,
                                        action: #selector(handlePresentedViewDrag))
        presentedView?.addGestureRecognizer(gr)
        presentedViewDragGR = gr
    }

    func removePresentedViewDragRecogniser() {
        guard let gr = presentedViewDragGR else { return }
        presentedView?.removeGestureRecognizer(gr)
        presentedViewDragGR = nil
    }

    @objc func handlePresentedViewDrag() {
        guard let gr = presentedViewDragGR, let view = gr.view else { return }

        switch gr.state {
        case .began:
            lastDrawerY = currentDrawerY

        case .changed:
            lastDrawerY = currentDrawerY
            let offsetY = gr.translation(in: view).y
            gr.setTranslation(.zero, in: view)
            let positionY = currentDrawerY + offsetY
            currentDrawerY = min(max(positionY, 0), containerViewH)
            currentDrawerCornerRadius = cornerRadius(at: currentDrawerY)

        case .ended:
            let drawerVelocityY = gr.velocity(in: view).y / containerViewH
            let endPosY = endingPositionY(positionY: currentDrawerY,
                                          velocityY: drawerVelocityY)
            animateTransition(to: endPosY)

        case .cancelled:
            animateTransition(to: lastDrawerY, clamping: true)

        default:
            break
        }
    }
}

private extension PresentationController {
    func animateTransition(to endPositionY: CGFloat, clamping: Bool = false) {
        addPositionAnimationEnding(at: endPositionY, clamping: clamping)
        addCornerRadiusAnimationEnding(at: endPositionY, clamping: clamping)
    }

    func addPositionAnimationEnding(at endPositionY: CGFloat, clamping: Bool = false) {
        guard endPositionY != currentDrawerY else { return }

        let endPosY = (clamping ? clamped(endPositionY) : endPositionY)
        guard endPosY != currentDrawerY else { return }

        let animator = UIViewPropertyAnimator(duration: durationInSeconds,
                                              timingParameters: timingCurveProvider)

        animator.addAnimations { [weak self] in
            self?.currentDrawerY = endPosY
        }

        if endPosY == containerViewH {
            animator.addCompletion { [weak self] _ in
                self?.presentedViewController.dismiss(animated: true)
            }
        }

        animator.startAnimation()
    }

    func addCornerRadiusAnimationEnding(at endPositionY: CGFloat, clamping: Bool = false) {
        guard drawerPartialY > 0 else { return }
        guard endPositionY != currentDrawerY else { return }

        let endPosY = (clamping ? clamped(endPositionY) : endPositionY)
        guard endPosY != currentDrawerY else { return }

        let animator = UIViewPropertyAnimator(duration: durationInSeconds,
                                              timingParameters: timingCurveProvider)

        let endingCornerRadius = cornerRadius(at: endPosY)
        animator.addAnimations { [weak self] in
            self?.currentDrawerCornerRadius = endingCornerRadius
        }

        if endPosY == 0 || endPosY == containerViewH {
            animator.addCompletion { [weak self] _ in
                self?.currentDrawerCornerRadius = 0
            }
        }

        animator.startAnimation()
    }

    func cornerRadius(at positionY: CGFloat) -> CGFloat {
        guard drawerPartialY > 0 && drawerPartialY < containerViewH else { return 0 }
        guard positionY >= 0 && positionY <= containerViewH else { return 0 }

        let fraction: CGFloat
        if supportsPartialExpansion {
            if positionY < drawerPartialY {
                fraction = positionY / drawerPartialY
            } else {
                fraction = 1 - (positionY - drawerPartialY) / (containerViewH - drawerPartialY)
            }
        } else {
            fraction = 1 - positionY / containerViewH
        }

        return fraction * maximumCornerRadius
    }
}

private extension PresentationController {
    func endingPositionY(positionY: CGFloat, velocityY: CGFloat) -> CGFloat {
        let isNotMoving = (velocityY == 0)
        let isMovingUp = (velocityY < 0) // recall that Y-axis points down
        let isMovingDown = (velocityY > 0)
        // flickSpeedThreshold == 0 disables speed-dependence
        let isMovingQuickly = (flickSpeedThreshold > 0) && (abs(velocityY) > flickSpeedThreshold)
        let isMovingUpQuickly = isMovingUp && isMovingQuickly
        let isMovingDownQuickly = isMovingDown && isMovingQuickly
        let isAboveUpperMark = (positionY < upperMarkY)
        let isAboveLowerMark = (positionY < lowerMarkY)

        if isMovingUpQuickly { return 0 }
        if isMovingDownQuickly { return containerViewH }

        if isAboveUpperMark {
            if isMovingUp || isNotMoving {
                return 0
            } else {
                let inStages = supportsPartialExpansion && dismissesInStages
                return inStages ? drawerPartialY : containerViewH
            }
        }

        if isAboveLowerMark {
            if isMovingDown {
                return containerViewH
            } else {
                return (supportsPartialExpansion ? drawerPartialY : 0)
            }
        }

        return containerViewH
    }

    func clamped(_ positionY: CGFloat) -> CGFloat {
        if positionY < upperMarkY {
            return 0
        } else if positionY > lowerMarkY {
            return containerViewH
        } else {
            return (supportsPartialExpansion ? drawerPartialY : 0)
        }
    }
}

private extension PresentationController {
    func setupDebugHeightMarks() {
        guard inDebugMode else { return }
        guard let containerView = containerView else { return }

        let upperMarkYView = UIView()
        upperMarkYView.backgroundColor = .black
        upperMarkYView.frame = CGRect(x: 0, y: upperMarkY,
                                      width: containerView.bounds.size.width, height: 3)
        containerView.addSubview(upperMarkYView)

        let lowerMarkYView = UIView()
        lowerMarkYView.backgroundColor = .black
        lowerMarkYView.frame = CGRect(x: 0, y: lowerMarkY,
                                      width: containerView.bounds.size.width, height: 3)
        containerView.addSubview(lowerMarkYView)

        let drawerMarkView = UIView()
        drawerMarkView.backgroundColor = .white
        drawerMarkView.frame = CGRect(x: 0, y: drawerPartialY,
                                      width: containerView.bounds.size.width, height: 3)
        containerView.addSubview(drawerMarkView)
    }
}
