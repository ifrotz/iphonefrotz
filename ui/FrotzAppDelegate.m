//
//  FrotzAppDelegate.m
//  Frotz
//
//  Created by Craig Smith on 6/17/08.
//  Copyright Craig Smith 2008. All rights reserved.
//

#import "FrotzAppDelegate.h"
#import "StoryBrowser.h"
#import "StoryMainViewController.h"
#import "StatusLine.h"
#import "StoryInputLine.h"
#import "StoryView.h"
#import "StoryDetailsController.h"
#import "FrotzDB.h"

@interface FrotzWindow : UIWindow
{
}
- (void)sendEvent:(UIEvent *)event;                    // called by UIApplication to dispatch events to views inside the window
@end

@implementation FrotzWindow
- (void)sendEvent:(UIEvent *)event {
    static UIView *prevView;
    for (UITouch *touch in [event allTouches]) {
        UIView *view = [touch view];
        UITouchPhase phase = [touch phase];

        if (!view && phase != UITouchPhaseBegan)
            view = prevView; // for some reason sometomes view is nil and we lose the phase ended event!
        if ([touch tapCount]>=1 || phase == UITouchPhaseEnded) {
            if ([view isDescendantOfView: theInputLine]) {
                prevView = view;
                if (![theInputLine handleTouch: touch withEvent: event])
                    return;
            } else if ([view isDescendantOfView: theStoryView]) {
                prevView = view;
                if (![theStoryView handleTouch: touch withEvent: event])
                    return;
                } else if ([view isDescendantOfView: theStatusLine]) {
                    prevView = view;
                    if (![theStatusLine handleTouch: touch withEvent: event])
                        return;
                }
        }
    }
    if (@available(iOS 13.4, *)) {
        if ([event isKindOfClass: [UIPressesEvent class]]) {
            if (theInputLine.isFirstResponder == NO)
                [theInputLine becomeFirstResponder];
        }
    }
    [super sendEvent: event];
}
@end

@implementation FrotzAppDelegate

@synthesize window = m_window;

-(void)setWindow:(UIWindow*)window {
    m_window = window;
}

-(UIWindow*)window {
    if (!m_window)
        m_window = [[FrotzWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    return m_window;
}

- (instancetype)init {
	if ((self = [super init])) {
		// 
	} 
	return self;
}

-(void)fadeSplashScreen {
    [m_transitionView replaceSubview: m_splash withSubview:nil transition:kCATransitionFade  direction:kCATransitionFromTop duration:0.25];
}

bool gLargeScreenDevice;
int gLargeScreenPhone = 0;
bool gUseSplitVC;


- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    if ([[shortcutItem type] isEqualToString: @"storylist"]) {
        [m_browser setPostLaunch];
        [[m_browser navigationController] popToViewController:m_browser animated:YES];
        completionHandler(YES);
    }
}

//- (void)applicationDidFinishLaunching:(UIApplication *)application
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOption {
    // Configure and show the window
    CGRect rect = [[UIScreen mainScreen] bounds];
    BOOL usingStoryBoard = NO;
    gLargeScreenDevice = (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad);
	gLargeScreenPhone = (rect.size.height >= 375 && rect.size.width >= 375) + (rect.size.height >= 414 && rect.size.width >= 414);
    gUseSplitVC = gLargeScreenDevice;
    //Create a full-screen window
    if (!m_window) { // not using storyboard
        m_window = [[FrotzWindow alloc] initWithFrame:rect];

        rect = [[UIScreen mainScreen] applicationFrame];
        BOOL useSplashTransition = NO;

        if (useSplashTransition && !gLargeScreenDevice) { // Fade splash screen gradually to story browser, but not on iPad; see comment below
            m_transitionView = [[TransitionView alloc] initWithFrame: rect];
            m_transitionView.backgroundColor = [UIColor clearColor];
        #if 1
            UIImage *splashImage = [UIImage imageNamed: @"Default"];
            if (!splashImage)
                splashImage = [UIImage imageNamed: @"Default.png"];
            m_splash = [[UIImageView alloc] initWithImage: splashImage];	
        #else // Device orientation isn't yet correctly set when launched in landscape; this doesn't work, so we don't even try on iPad
            if (!gLargeScreenDevice)
                m_splash = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"Default.png"]];
            else if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation]))
                m_splash = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"Default-Landscpe.png"]];
            else
                m_splash = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"Default-Portrait.png"]];
        #endif
            [m_transitionView setDelegate: self];
            [m_transitionView addSubview: m_splash];
            [m_transitionView bringSubviewToFront: m_splash];
              
            m_activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];

            [m_activityView setFrame: CGRectMake(rect.size.width/2-10, rect.size.height - 80, 20, 20)];
            [m_transitionView addSubview: m_activityView];
            [m_transitionView bringSubviewToFront: m_activityView];
            [m_activityView startAnimating];
        }
    } else
        usingStoryBoard = YES;

    NSURL *launchURL = nil;
    BOOL handledShortcut = YES;
    if (usingStoryBoard)
        m_browser = [m_window.rootViewController.childViewControllers[0] childViewControllers][0];
    else
        m_browser = [[StoryBrowser alloc] init];

    if (launchOption) {
        NSURL *url = launchOption[UIApplicationLaunchOptionsURLKey];
        if (url) 
            launchURL = url;
        if (launchOption[UIApplicationLaunchOptionsShortcutItemKey]) {
            [m_browser setPostLaunch];
            handledShortcut = YES;
        }
    }
    if (usingStoryBoard) {
//        UINavigationController* navigationController = [[UINavigationController alloc] initWithRootViewController: [m_browser storyMainViewController]];
        [m_browser storyMainViewController].storyNavController = m_window.rootViewController.childViewControllers[1];  //navigationController;
        NSLog(@"smbc snc %@ nc %@", [m_browser storyMainViewController].storyNavController, [m_browser storyMainViewController].navigationController);
        gUseSplitVC = YES;
    } else {
        if (gUseSplitVC) {
            UISplitViewController* splitVC = [[UISplitViewController alloc] initWithNibName:nil bundle:nil];
            [splitVC setDelegate: m_browser];

            m_navigationController = [[UINavigationController alloc] initWithRootViewController: m_browser];

            UINavigationController* navigationController = [[UINavigationController alloc] initWithRootViewController: [m_browser storyMainViewController]];
            [m_browser storyMainViewController].storyNavController = navigationController;

            StoryDetailsController *detailsController = [m_browser detailsController];
            UINavigationController *nc = [detailsController navigationController];
            if (!nc) {
                nc = [[UINavigationController alloc] initWithRootViewController: detailsController];
                detailsController.detailsNavigationController = nc;
                [nc.navigationBar setBarStyle: UIBarStyleBlackOpaque];
            }
            
            splitVC.viewControllers = @[m_navigationController, nc];

            if ([m_window respondsToSelector:@selector(setRootViewController:)])
                [m_window setRootViewController: splitVC];
            else
                [m_window addSubview: splitVC.view];
        } else {
            m_navigationController = [[UINavigationController alloc] initWithRootViewController: m_browser];
            if ([m_window respondsToSelector:@selector(setRootViewController:)])
                [m_window setRootViewController: m_navigationController];
            else
                [m_window addSubview:[m_navigationController view]];
            if (m_transitionView) {
                [m_window addSubview: m_transitionView];
                [m_window bringSubviewToFront: m_transitionView];
            }
        }
    } // !usingStoryBoard

#ifdef NSFoundationVersionNumber_iOS_6_1
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
        if (@available(iOS 13.0, *)) {
            [[UINavigationBar appearance] setTintColor:[UIColor labelColor]];
            [[UIButton appearanceWhenContainedIn: [UITableViewCell class], nil] setTintColor: [UIColor systemIndigoColor]];
        } else {
            [[UINavigationBar appearance] setTintColor:[UIColor darkGrayColor]];
            [[UINavigationBar appearance] setBarTintColor: [UIColor whiteColor]];
            [[UIButton appearanceWhenContainedIn: [UITableViewCell class], nil] setTintColor: [UIColor purpleColor]];
        }

        // This is now done explicitly for buttons in the StoryDetailsController, and in the xib files
        // because of bugs/misfeatures in the iOS 11 SDK.
        // See: http://www.openradar.me/radar?id=5064333964869632
        //[[UIButton appearance] setTintColor: [UIColor whiteColor]];
        //[[UIButton appearance] setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        //[[UIButton appearanceWhenContainedIn: [UINavigationBar class], nil] setTintColor: textColor];
        
        [[UIButton appearanceWhenContainedIn: [StoryDetailsController class], nil] setTitleColor: [UIColor whiteColor] forState:UIControlStateNormal];
    }
#endif
    
    [[m_browser storyMainViewController] initializeDropbox];
#if 0
    if (!usingStoryBoard) {
        [m_window makeKeyAndVisible];
        [self performSelector: @selector(fadeSplashScreen) withObject: nil afterDelay: 0.01];
    }
#endif
    if (usingStoryBoard) {
        [m_browser view];
        m_browser.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAutomatic;
    }
    if (launchURL)
        [self application:application handleOpenURL: launchURL];
    return !handledShortcut;
}

- (void)transitionViewDidFinish:(TransitionView *)view {
    [m_window addSubview: [m_navigationController view]];
    [m_splash removeFromSuperview];
    [m_activityView stopAnimating];
    [m_activityView removeFromSuperview];
    [m_transitionView removeFromSuperview];    
}

- (void)applicationWillTerminate:(UIApplication *)application {
    StoryMainViewController *storyMainViewController = [m_browser storyMainViewController];
    [storyMainViewController suspendStory];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    StoryMainViewController *storyMainViewController = [m_browser storyMainViewController];
    [storyMainViewController autoSaveStory];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    StoryMainViewController *storyMainViewController = [m_browser storyMainViewController];
    [storyMainViewController autosize];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication*)app {
    NSLog(@"memory warning!");
}

- (BOOL)application: (UIApplication*)application handleOpenURL: (NSURL*)launchURL {
    NSLog(@"handleOpenURL %@", launchURL);
#if UseNewDropBoxSDK
    DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:launchURL];
    if (authResult != nil) {
        if ([authResult isSuccess]) {
            NSLog(@"Success! User is logged into Dropbox.");
            [[m_browser navigationController] popViewControllerAnimated: YES];
            [[m_browser storyMainViewController] dropboxDidLinkAccount];
            return YES;
        } else if ([authResult isCancel]) {
            NSLog(@"Authorization flow was manually canceled by user!");
        } else if ([authResult isError]) {
            NSLog(@"Error: %@", authResult);
        }
        return YES;
    }
#else
    if ([[DBSession sharedSession] handleOpenURL:launchURL]) {
        if ([[DBSession sharedSession] isLinked]) {
            if ([[launchURL path] hasSuffix: @"/cancel"])
                return YES;
            NSLog(@"DB App linked successfully!");
            [[m_browser storyMainViewController] dropboxDidLinkAccount];
            // At this point you can start making API calls
        }
        return YES;
    }
#endif
    if (launchURL && [launchURL isFileURL]) {
        NSString *launchPath = [launchURL path];

        [m_browser setLaunchPath: launchPath];
        if ((launchPath = [m_browser launchPath])) { // nil if file couldn't be accessed
            [m_browser addRecentStory: launchPath];
            StoryInfo *si = [[StoryInfo alloc] initWithPath: launchPath browser:m_browser];
            [m_browser setStoryDetails: si];
            [m_browser performSelector:@selector(launchStory:) withObject:launchPath afterDelay:0.05];
        }
    } else {
        NSLog(@"Frotz launched w/unknown URL: %@", launchURL);
        UIAlertView *alert = [[UIAlertView alloc]  initWithTitle:@"Frotz cannot handle URL"
                message: [NSString stringWithFormat:@"%@", launchURL]
                delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
    }

    return NO;
}



@end
