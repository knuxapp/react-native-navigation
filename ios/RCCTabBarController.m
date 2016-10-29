#import "RCCTabBarController.h"
#import "RCCViewController.h"
#import "RCTConvert.h"
#import "RCCManager.h"
#import "RCTEventDispatcher.h"
#import <objc/runtime.h>

NSString const *TAB_CALLBACK_ASSOCIATED_KEY = @"RCCTabBarController.CALLBACK_ASSOCIATED_KEY";
NSString const *TAB_CALLBACK_ASSOCIATED_ID = @"RCCTabBarController.CALLBACK_ASSOCIATED_ID";

@implementation RCCTabBarController

- (UIImage *)image:(UIImage*)image withColor:(UIColor *)color1
{
  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(context, 0, image.size.height);
  CGContextScaleCTM(context, 1.0, -1.0);
  CGContextSetBlendMode(context, kCGBlendModeNormal);
  CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
  CGContextClipToMask(context, rect, image.CGImage);
  [color1 setFill];
  CGContextFillRect(context, rect);
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newImage;
}

-(BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:viewController
{
  RCCViewController *vc = viewController;
  
  NSString *callbackId = objc_getAssociatedObject(vc, &TAB_CALLBACK_ASSOCIATED_KEY);
  
  if (callbackId) {
    NSString *buttonId = objc_getAssociatedObject(vc, &TAB_CALLBACK_ASSOCIATED_ID);
    [[[RCCManager sharedInstance] getBridge].eventDispatcher sendAppEventWithName:callbackId body:@
     {
       @"type": @"TabBarButtonPress",
       @"id": buttonId ? buttonId : [NSNull null]
     }];
    
    if ([@"preventDefault" isEqualToString:buttonId]) {
      return NO;
    }
  }
  
  return YES;
}

- (instancetype)initWithProps:(NSDictionary *)props children:(NSArray *)children globalProps:(NSDictionary*)globalProps bridge:(RCTBridge *)bridge
{
  self = [super init];
  if (!self) return nil;
  
  self.delegate = self;

  self.tabBar.translucent = YES; // default
  
  UIColor *buttonColor = nil;
  UIColor *selectedButtonColor = nil;
  NSDictionary *tabsStyle = props[@"style"];
  if (tabsStyle)
  {
    NSString *tabBarButtonColor = tabsStyle[@"tabBarButtonColor"];
    if (tabBarButtonColor)
    {
      UIColor *color = tabBarButtonColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarButtonColor] : nil;
      self.tabBar.tintColor = color;
      buttonColor = color;
      selectedButtonColor = color;
    }
    
    NSString *tabBarSelectedButtonColor = tabsStyle[@"tabBarSelectedButtonColor"];
    if (tabBarSelectedButtonColor)
    {
      UIColor *color = tabBarSelectedButtonColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarSelectedButtonColor] : nil;
      self.tabBar.tintColor = color;
      selectedButtonColor = color;
    }
    
    NSString *tabBarBackgroundColor = tabsStyle[@"tabBarBackgroundColor"];
    if (tabBarBackgroundColor)
    {
      UIColor *color = tabBarBackgroundColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarBackgroundColor] : nil;
      self.tabBar.barTintColor = color;
    }
  }

  NSMutableArray *viewControllers = [NSMutableArray array];

  // go over all the tab bar items
  for (NSDictionary *tabItemLayout in children)
  {
    // make sure the layout is valid
    if (![tabItemLayout[@"type"] isEqualToString:@"TabBarControllerIOS.Item"]) continue;
    if (!tabItemLayout[@"props"]) continue;

    // get the view controller inside
    if (!tabItemLayout[@"children"]) continue;
    if (![tabItemLayout[@"children"] isKindOfClass:[NSArray class]]) continue;
    if ([tabItemLayout[@"children"] count] < 1) continue;
    NSDictionary *childLayout = tabItemLayout[@"children"][0];
    UIViewController *viewController = [RCCViewController controllerWithLayout:childLayout globalProps:globalProps bridge:bridge];
    if (!viewController) continue;

    id tintOverride = tabItemLayout[@"props"][@"shouldTint"];
    BOOL shouldTintIcon = tintOverride != (id)[NSNull null] ? [RCTConvert BOOL:tintOverride] : YES;

    // create the tab icon and title
    NSString *title = tabItemLayout[@"props"][@"title"];
    UIImage *iconImage = nil;
    id icon = tabItemLayout[@"props"][@"icon"];
    if (icon)
    {
      iconImage = [[RCTConvert UIImage:icon] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
      if (buttonColor && shouldTintIcon)
      {
        iconImage = [[self image:iconImage withColor:buttonColor] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
      }
    }
    UIImage *iconImageSelected = nil;
    id selectedIcon = tabItemLayout[@"props"][@"selectedIcon"];
    if (selectedIcon) iconImageSelected = [RCTConvert UIImage:selectedIcon];

    viewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:iconImage tag:0];
    viewController.tabBarItem.accessibilityIdentifier = tabItemLayout[@"props"][@"testID"];
    
    if (shouldTintIcon)
    {
      viewController.tabBarItem.selectedImage = iconImageSelected;
    }else{
      viewController.tabBarItem.selectedImage = [iconImageSelected imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
     
    id position = tabItemLayout[@"props"][@"position"];
    if (position) {
      id xId = position[@"x"];
      id yId = position[@"y"];
       
      NSInteger x = [RCTConvert NSInteger:xId];
      NSInteger y = [RCTConvert NSInteger:yId];
       
      viewController.tabBarItem.imageInsets = UIEdgeInsetsMake(y, x, -y, -x);
    }
    
    if (buttonColor)
    {
      [viewController.tabBarItem setTitleTextAttributes:
       @{NSForegroundColorAttributeName : buttonColor} forState:UIControlStateNormal];
    }
    
    if (selectedButtonColor)
    {
      [viewController.tabBarItem setTitleTextAttributes:
       @{NSForegroundColorAttributeName : selectedButtonColor} forState:UIControlStateSelected];
    }
    
    // create badge
    NSObject *badge = tabItemLayout[@"props"][@"badge"];
    if (badge == nil || [badge isEqual:[NSNull null]])
    {
      viewController.tabBarItem.badgeValue = nil;
    }
    else
    {
      viewController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%@", badge];
    }

    [viewControllers addObject:viewController];

    NSArray *buttons = tabItemLayout[@"props"][@"buttons"];
    if (buttons) {
      NSDictionary *button = buttons[0];
      objc_setAssociatedObject(viewController, &TAB_CALLBACK_ASSOCIATED_KEY, button[@"onPress"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      NSString *buttonId = button[@"id"];
      if (buttonId)
      {
        objc_setAssociatedObject(viewController, &TAB_CALLBACK_ASSOCIATED_ID, buttonId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      }
    }
  }

  // replace the tabs
  self.viewControllers = viewControllers;

  int activeTabIndex = (int)[(NSNumber *)props[@"activeTabIndex"] integerValue];
  if (activeTabIndex < [viewControllers count]) {
    [self setSelectedViewController:[viewControllers objectAtIndex:activeTabIndex]];
  }

  return self;
}

- (void)performAction:(NSString*)performAction actionParams:(NSDictionary*)actionParams bridge:(RCTBridge *)bridge completion:(void (^)(void))completion
{
    if ([performAction isEqualToString:@"setBadge"])
    {
      UIViewController *viewController = nil;
      NSNumber *tabIndex = actionParams[@"tabIndex"];
      if (tabIndex)
      {
        int i = (int)[tabIndex integerValue];
      
        if ([self.viewControllers count] > i)
        {
          viewController = [self.viewControllers objectAtIndex:i];
        }
      }
      NSString *contentId = actionParams[@"contentId"];
      NSString *contentType = actionParams[@"contentType"];
      if (contentId && contentType)
      {
        viewController = [[RCCManager sharedInstance] getControllerWithId:contentId componentType:contentType];
      }
      
      if (viewController)
      {
        NSObject *badge = actionParams[@"badge"];
        
        if (badge == nil || [badge isEqual:[NSNull null]])
        {
          viewController.tabBarItem.badgeValue = nil;
        }
        else
        {
          viewController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%@", badge];
        }
      }
    }
  
    if ([performAction isEqualToString:@"switchTo"])
    {
      UIViewController *viewController = nil;
      NSNumber *tabIndex = actionParams[@"tabIndex"];
      if (tabIndex)
      {
        int i = (int)[tabIndex integerValue];
      
        if ([self.viewControllers count] > i)
        {
          viewController = [self.viewControllers objectAtIndex:i];
        }
      }
      NSString *contentId = actionParams[@"contentId"];
      NSString *contentType = actionParams[@"contentType"];
      if (contentId && contentType)
      {
        viewController = [[RCCManager sharedInstance] getControllerWithId:contentId componentType:contentType];
      }
    
      if (viewController)
      {
        [self setSelectedViewController:viewController];
      }
    }

    if ([performAction isEqualToString:@"setTabBarHidden"])
    {
        BOOL hidden = [actionParams[@"hidden"] boolValue];
        [UIView animateWithDuration: ([actionParams[@"animated"] boolValue] ? 0.45 : 0)
                              delay: 0
             usingSpringWithDamping: 0.75
              initialSpringVelocity: 0
                            options: (hidden ? UIViewAnimationOptionCurveEaseIn : UIViewAnimationOptionCurveEaseOut)
                         animations:^()
         {
             self.tabBar.transform = hidden ? CGAffineTransformMakeTranslation(0, self.tabBar.frame.size.height) : CGAffineTransformIdentity;
         }
                         completion:^(BOOL finished)
        {
            if (completion != nil)
            {
                completion();
            }
        }];
        return;
    }
    else if (completion != nil)
    {
      completion();
    }
}

@end
