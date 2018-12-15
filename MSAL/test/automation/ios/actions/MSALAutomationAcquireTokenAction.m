//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALAutomationAcquireTokenAction.h"
#import "MSIDAutomation.h"
#import "MSIDAutomationTestResult.h"
#import <MSAL/MSAL.h>
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSALAutomationConstants.h"
#import "MSIDAutomationMainViewController.h"
#import "MSIDAutomationTestRequest.h"

@implementation MSALAutomationAcquireTokenAction

- (NSString *)actionIdentifier
{
    return @"acquire_token";
}

- (BOOL)needsRequestParameters
{
    return YES;
}

- (void)performActionWithParameters:(MSIDAutomationTestRequest *)testRequest
                containerController:(MSIDAutomationMainViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock
{
    NSError *applicationError = nil;
    MSALPublicClientApplication *application = [self applicationWithParameters:testRequest error:&applicationError];

    if (!application)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:applicationError];
        completionBlock(result);
        return;
    }

    NSError *accountError = nil;
    MSALAccount *account = [self accountWithParameters:testRequest application:application error:&accountError];

    if (accountError)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:applicationError];
        completionBlock(result);
        return;
    }

    NSOrderedSet *scopes = [NSOrderedSet msidOrderedSetFromString:testRequest.requestTarget];
    NSOrderedSet *extraScopes = [NSOrderedSet msidOrderedSetFromString:testRequest.extraScopes];
    NSUUID *correlationId = [NSUUID new];
    NSString *claims = testRequest.claims;
    NSDictionary *extraQueryParameters = testRequest.extraQueryParameters;

    MSALUIBehavior uiBehavior = MSALUIBehaviorDefault;

    if ([testRequest.uiBehavior isEqualToString:@"force"])
    {
        uiBehavior = MSALForceLogin;
    }
    else if ([testRequest.uiBehavior isEqualToString:@"consent"])
    {
        uiBehavior = MSALForceConsent;
    }
    else if ([testRequest.uiBehavior isEqualToString:@"prompt_if_necessary"])
    {
        uiBehavior = MSALPromptIfNecessary;
    }

    MSIDWebviewType webviewSelection = testRequest.webViewType;

    switch (webviewSelection) {
        case MSIDWebviewTypeWKWebView:
            application.webviewType = MSALWebviewTypeWKWebView;
            break;

        case MSIDWebviewTypeDefault:
            application.webviewType = MSALWebviewTypeDefault;
            break;

        case MSIDWebviewTypeSafariViewController:
            application.webviewType = MSALWebviewTypeSafariViewController;
            break;

        case MSIDWebviewTypeAuthenticationSession:
            application.webviewType = MSALWebviewTypeAuthenticationSession;
            break;

        default:
            break;
    }

    if (testRequest.usePassedWebView)
    {
        application.webviewType = MSALWebviewTypeWKWebView;
        application.customWebview = containerController.passedinWebView;
        [containerController showPassedInWebViewControllerWithContext:@{@"context": application}];
    }

    MSALAuthority *acquireTokenAuthority = nil;

    if (testRequest.acquireTokenAuthority)
    {
        NSURL *authorityUrl = [[NSURL alloc] initWithString:testRequest.acquireTokenAuthority];
        acquireTokenAuthority = [MSALAuthority authorityWithURL:authorityUrl error:nil];
    }

    if (account)
    {
        [application acquireTokenForScopes:scopes.array
                      extraScopesToConsent:extraScopes.array
                                   account:account
                                uiBehavior:uiBehavior
                      extraQueryParameters:extraQueryParameters
                                    claims:claims
                                 authority:acquireTokenAuthority
                             correlationId:correlationId
                           completionBlock:^(MSALResult *result, NSError *error)
         {
             MSIDAutomationTestResult *testResult = [self testResultWithMSALResult:result error:error];
             completionBlock(testResult);
         }];
    }
    else
    {
        [application acquireTokenForScopes:scopes.array
                      extraScopesToConsent:extraScopes.array
                                 loginHint:testRequest.loginHint
                                uiBehavior:uiBehavior
                      extraQueryParameters:extraQueryParameters
                                 authority:acquireTokenAuthority
                             correlationId:correlationId
                           completionBlock:^(MSALResult *result, NSError *error) {

                               MSIDAutomationTestResult *testResult = [self testResultWithMSALResult:result error:error];
                               completionBlock(testResult);
                           }];
    }
}

@end