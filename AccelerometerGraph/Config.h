//
//  Config.h
//  Simple Track Playback
//
//  Created by Per-Olov Jernberg on 2014-11-18.
//  Copyright (c) 2014 Your Company. All rights reserved.
//

#ifndef Simple_Track_Playback_Config_h
#define Simple_Track_Playback_Config_h

#warning Please update these values to match the settings for your own application as these example values could change at any time.
// For an in-depth auth demo, see the "Basic Auth" demo project supplied with the SDK.
// Don't forget to add your callback URL's prefix to the URL Types section in the target's Info pane!

#define kClientId "8396a42c4a7c446594de64c19bc6ef87"
#define kCallbackURL "tempofy-login://callback"

#define kTokenSwapServiceURL "http://158.130.174.185:1234/swap"
// or "http://localhost:1234/swap" with example token swap service

// If you don't provide a token swap service url the login will use implicit grant tokens, which
// means that your user will need to sign in again every time the token expires.

#define kTokenRefreshServiceURL "http://localhost:1234/refresh"
// or "http://localhost:1234/refresh" with example token refresh service

// If you don't provide a token refresh service url, the user will need to sign in again every
// time their token expires.


#endif
