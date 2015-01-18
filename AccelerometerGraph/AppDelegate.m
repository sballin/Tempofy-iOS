/*
     File: AppDelegate.m
 Abstract: Responsbile for loading the initial UI and responding to application events.
  Version: 2.6
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "AppDelegate.h"
#import "Config.h"
#import "MainViewController.h"
#import <Spotify/Spotify.h>

@interface AppDelegate ()
@property (nonatomic, strong) IBOutlet UIViewController *viewController;
@end

#define kSessionUserDefaultsKey "SpotifySession"

@implementation AppDelegate

-(void)enableAudioPlaybackWithSession:(SPTSession *)session {
    NSData *sessionData = [NSKeyedArchiver archivedDataWithRootObject:session];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:sessionData forKey:@kSessionUserDefaultsKey];
    [userDefaults synchronize];
    MainViewController *mainViewController = (MainViewController *)self.window.rootViewController;
    [mainViewController handleNewSession:session];
}

- (void)openLoginPage {
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    NSString *swapUrl = @kTokenSwapServiceURL;
    NSURL *loginURL;
    if (swapUrl == nil || [swapUrl isEqualToString:@""]) {
        // If we don't have a token exchange service, we need to request the token response type.
        loginURL = [auth loginURLForClientId:@kClientId
                         declaredRedirectURL:[NSURL URLWithString:@kCallbackURL]
                                      scopes:@[SPTAuthStreamingScope]
                            withResponseType:@"token"];
    }
    else {
        loginURL = [auth loginURLForClientId:@kClientId
                         declaredRedirectURL:[NSURL URLWithString:@kCallbackURL]
                                      scopes:@[SPTAuthStreamingScope]];
        
    }
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        // If you open a URL during application:didFinishLaunchingWithOptions:, you
        // seem to get into a weird state.
        [[UIApplication sharedApplication] openURL:loginURL];
    });
}

- (void)renewTokenAndEnablePlayback {
    id sessionData = [[NSUserDefaults standardUserDefaults] objectForKey:@kSessionUserDefaultsKey];
    SPTSession *session = sessionData ? [NSKeyedUnarchiver unarchiveObjectWithData:sessionData] : nil;
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    [auth renewSession:session withServiceEndpointAtURL:[NSURL URLWithString:@kTokenRefreshServiceURL] callback:^(NSError *error, SPTSession *session) {
        if (error) {
            NSLog(@"*** Error renewing session: %@", error);
            return;
        }
        
        [self enableAudioPlaybackWithSession:session];
    }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    id sessionData = [[NSUserDefaults standardUserDefaults] objectForKey:@kSessionUserDefaultsKey];
    SPTSession *session = sessionData ? [NSKeyedUnarchiver unarchiveObjectWithData:sessionData] : nil;
    
    NSString *refreshUrl = @kTokenRefreshServiceURL;
    
    if (session) {
        // We have a session stored.
        if ([session isValid]) {
            // It's still valid, enable playback.
            [self enableAudioPlaybackWithSession:session];
        } else {
            // Oh noes, the token has expired.
            
            // If we're not using a backend token service we need to prompt the user to sign in again here.
            if (refreshUrl == nil || [refreshUrl isEqualToString:@""]) {
                [self openLoginPage];
            } else {
                [self renewTokenAndEnablePlayback];
            }
        }
    } else {
        // We don't have an session, prompt the user to sign in.
        [self openLoginPage];
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // [NSBundle mainBundle] load
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:[NSBundle mainBundle]];
    UIViewController *viewController = [storyboard instantiateInitialViewController];
    [self.window setRootViewController:viewController];
    [self.window makeKeyAndVisible];
    
    [self enableAudioPlaybackWithSession:session];
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
    SPTAuthCallback authCallback = ^(NSError *error, SPTSession *session) {
        // This is the callback that'll be triggered when auth is completed (or fails).
        
        if (error != nil) {
            NSLog(@"*** Auth error: %@", error);
            return;
        }
        
        NSData *sessionData = [NSKeyedArchiver archivedDataWithRootObject:session];
        [[NSUserDefaults standardUserDefaults] setObject:sessionData
                                                  forKey:@kSessionUserDefaultsKey];
        [self enableAudioPlaybackWithSession:session];
    };
    
    /*
     STEP 2: Handle the callback from the authentication service. -[SPAuth -canHandleURL:withDeclaredRedirectURL:]
     helps us filter out URLs that aren't authentication URLs (i.e., URLs you use elsewhere in your application).
     */
    NSString *swapUrl = @kTokenSwapServiceURL;
    if ([[SPTAuth defaultInstance] canHandleURL:url withDeclaredRedirectURL:[NSURL URLWithString:@kCallbackURL]]) {
        if (swapUrl == nil || [swapUrl isEqualToString:@""]) {
            // If we don't have a token exchange service, we'll just handle the implicit token response directly.
            [[SPTAuth defaultInstance] handleAuthCallbackWithTriggeredAuthURL:url callback:authCallback];
        } else {
            // If we have a token exchange service, we'll call it and get the token.
            [[SPTAuth defaultInstance] handleAuthCallbackWithTriggeredAuthURL:url
                                                tokenSwapServiceEndpointAtURL:[NSURL URLWithString:swapUrl]
                                                                     callback:authCallback];
        }
        return YES;
    }
    
    return NO;
}

@end
