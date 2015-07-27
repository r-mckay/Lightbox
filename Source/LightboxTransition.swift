import UIKit

class LightboxTransition: UIPercentDrivenInteractiveTransition {

  struct Timing {
    static let transition: NSTimeInterval = 0.5
  }

  lazy var panGestureRecognizer: UIPanGestureRecognizer = {
    let panGestureRecognizer = UIPanGestureRecognizer()
    panGestureRecognizer.addTarget(self, action: "handlePanGesture:")
    panGestureRecognizer.delegate = self

    return panGestureRecognizer
    }()

  var presentingViewController = false
  var interactive = false
  var animator: UIDynamicAnimator!
  var attachmentBehavior: UIAttachmentBehavior!
  var gravityBehaviour: UIGravityBehavior!
  var snapBehavior: UISnapBehavior!
  var sourceViewController: LightboxController!

  var sourceViewCell: LightboxViewCell! {
    didSet {
      sourceViewCell.addGestureRecognizer(panGestureRecognizer)
    }
  }

  func transition(controller: LightboxController, show: Bool) {
    controller.view.backgroundColor = show ? .blackColor() : .clearColor()
    controller.view.alpha = show ? 1 : 0
    controller.collectionView.alpha = show ? 1 : 0
    //controller.collectionView.transform = show ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.5, 0.5)
    controller.pageLabel.transform = show ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 100)
    controller.closeButton.transform = show ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, -100)

    if sourceViewCell != nil {
      //sourceViewCell.lightboxView.imageView.transform = show ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, -100)
      self.sourceViewCell.lightboxView.imageView.center = CGPointMake(
        UIScreen.mainScreen().bounds.width/2, UIScreen.mainScreen().bounds.height/2)
    }
  }
}

// MARK: Transitioning delegate

extension LightboxTransition : UIViewControllerAnimatedTransitioning {

  func transitionDuration(transitionContext: UIViewControllerContextTransitioning) -> NSTimeInterval {
    return Timing.transition
  }

  func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
    let containerView = transitionContext.containerView()
    let duration = transitionDuration(transitionContext)

    let screens : (from: UIViewController, to: UIViewController) = (
      transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!,
      transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!)

    let lightboxViewController = !presentingViewController
      ? screens.from as! LightboxController
      : screens.to as! LightboxController

    let viewController = !presentingViewController
      ? screens.to as UIViewController
      : screens.from as UIViewController

    [viewController, lightboxViewController].map { containerView.addSubview($0.view) }

    if presentingViewController {
      transition(lightboxViewController, show: false)
    }

    UIView.animateWithDuration(Timing.transition, animations: { [unowned self] in
      self.transition(lightboxViewController, show: self.presentingViewController)
      }, completion: { _ in
        if transitionContext.transitionWasCancelled() {
          transitionContext.completeTransition(false)
          UIApplication.sharedApplication().keyWindow?.addSubview(screens.from.view)
        } else {
          transitionContext.completeTransition(true)
          UIApplication.sharedApplication().keyWindow?.addSubview(screens.to.view)
        }
    })
  }
}

// MARK: Transition delegate

extension LightboxTransition : UIViewControllerTransitioningDelegate {

  func animationControllerForPresentedController(presented: UIViewController,
    presentingController presenting: UIViewController,
    sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
      presentingViewController = true
      return self
  }

  func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    presentingViewController = false
    return self
  }

  func interactionControllerForDismissal(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return interactive ? self : nil
  }

  func interactionControllerForPresentation(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    return interactive ? self : nil
  }
}

// MARK: Interactive transition delegate

extension LightboxTransition {
  
  func handlePanGesture(panGestureRecognizer: UIPanGestureRecognizer) {
    let imageView = sourceViewCell.lightboxView.imageView
    let location = panGestureRecognizer.locationInView(sourceViewCell.lightboxView)
    let boxLocation = panGestureRecognizer.locationInView(imageView)
    let translation = panGestureRecognizer.translationInView(sourceViewCell.lightboxView)
    let maximumValue = UIScreen.mainScreen().bounds.height
    let calculation = abs(translation.y) / maximumValue
    let alphaValue = 1 - calculation
    let percentage = fabs(translation.y / UIScreen.mainScreen().bounds.height)

    if !sourceViewCell.parentViewController.physics {
      if panGestureRecognizer.state == UIGestureRecognizerState.Began {
        interactive = true
        sourceViewController.dismissViewControllerAnimated(true, completion: nil)
        animator.removeBehavior(snapBehavior)
        let centerOffset = UIOffsetMake(boxLocation.x - CGRectGetMidX(imageView.bounds),
          boxLocation.y - CGRectGetMidY(imageView.bounds))
        attachmentBehavior = UIAttachmentBehavior(item: imageView,
          offsetFromCenter: centerOffset, attachedToAnchor: location)
        attachmentBehavior.frequency = 0
        animator.addBehavior(attachmentBehavior)
      } else if panGestureRecognizer.state == UIGestureRecognizerState.Changed {
        updateInteractiveTransition(percentage)
        attachmentBehavior.anchorPoint = location
      } else if panGestureRecognizer.state == UIGestureRecognizerState.Ended {
        finishInteractiveTransition()
        animator.removeBehavior(attachmentBehavior)
        snapBehavior = UISnapBehavior(item: imageView,
          snapToPoint: sourceViewCell.lightboxView.center)
        animator.addBehavior(snapBehavior)
      }
    } else {
      if panGestureRecognizer.state == .Began {
        interactive = true
        sourceViewController.dismissViewControllerAnimated(true, completion: nil)
      } else if panGestureRecognizer.state == .Changed {
        imageView.center = CGPointMake(imageView.center.x, UIScreen.mainScreen().bounds.height/2 + translation.y)
        updateInteractiveTransition(percentage)
      } else {
        interactive = false
        if percentage > 0.25 {
          finishInteractiveTransition()
        } else {
          UIView.animateWithDuration(Timing.transition, animations: { () -> Void in
            self.sourceViewCell.lightboxView.imageView.center = CGPointMake(
              UIScreen.mainScreen().bounds.width/2, UIScreen.mainScreen().bounds.height/2)
          })
          cancelInteractiveTransition()
        }
      }
    }
  }
}

// MARK: Gesture recognizer delegate methods

extension LightboxTransition : UIGestureRecognizerDelegate {

  func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
    if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
      let translation = panGestureRecognizer.translationInView(sourceViewCell.superview!)
      if fabs(translation.x) < fabs(translation.y) {
        return true
      }
    }
    return false
  }
}
