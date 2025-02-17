/*
 * Copyright (C) 2017 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"
#import <WebKit/WKFoundation.h>

#import "PlatformUtilities.h"
#import "Test.h"
#import "TestWKWebView.h"
#import <WebKit/WKContentRuleList.h>
#import <WebKit/WKContentRuleListStorePrivate.h>
#import <WebKit/_WKUserContentFilterPrivate.h>
#import <wtf/RetainPtr.h>
#import <wtf/text/StringBuilder.h>
#import <wtf/text/StringConcatenate.h>
#import <wtf/text/StringConcatenateNumbers.h>

class WKContentRuleListStoreTest : public testing::Test {
public:
    virtual void SetUp()
    {
        [[WKContentRuleListStore defaultStore] _removeAllContentRuleLists];
    }
};

static NSString *basicFilter = @"[{\"action\":{\"type\":\"block\"},\"trigger\":{\"url-filter\":\".*webkit.org\"}}]";

TEST_F(WKContentRuleListStoreTest, Compile)
{
    __block bool doneCompiling = false;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"TestRuleList" encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
    
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);

        doneCompiling = true;
    }];
    TestWebKitAPI::Util::run(&doneCompiling);
}

static NSString *invalidFilter = @"[";

static void checkDomain(NSError *error)
{
    EXPECT_STREQ([[error domain] UTF8String], [WKErrorDomain UTF8String]);
}

TEST_F(WKContentRuleListStoreTest, InvalidRuleList)
{
    __block bool doneCompiling = false;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"TestRuleList" encodedContentRuleList:invalidFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
    
        EXPECT_NULL(filter);
        EXPECT_NOT_NULL(error);
        checkDomain(error);
        EXPECT_EQ(error.code, WKErrorContentRuleListStoreCompileFailed);
        EXPECT_STREQ("Rule list compilation failed: Failed to parse the JSON String.", [[error helpAnchor] UTF8String]);

        doneCompiling = true;
    }];
    TestWebKitAPI::Util::run(&doneCompiling);
}

TEST_F(WKContentRuleListStoreTest, Lookup)
{
    __block bool doneCompiling = false;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"TestRuleList" encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
    
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);

        doneCompiling = true;
    }];
    TestWebKitAPI::Util::run(&doneCompiling);

    __block bool doneLookingUp = false;
    [[WKContentRuleListStore defaultStore] lookUpContentRuleListForIdentifier:@"TestRuleList" completionHandler:^(WKContentRuleList *filter, NSError *error) {

        EXPECT_STREQ(filter.identifier.UTF8String, "TestRuleList");
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);

        doneLookingUp = true;
    }];
    TestWebKitAPI::Util::run(&doneLookingUp);
}

TEST_F(WKContentRuleListStoreTest, EncodedIdentifier)
{
    // FIXME: U+00C4 causes problems here. Using the output of encodeForFileName with
    // the filesystem changes it to U+0041 followed by U+0308
    NSString *identifier = @":;%25%+25И😍";
    __block bool done = false;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:identifier encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {

        EXPECT_STREQ(filter.identifier.UTF8String, identifier.UTF8String);

        [[WKContentRuleListStore defaultStore] getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
            EXPECT_EQ(identifiers.count, 1u);
            EXPECT_EQ(identifiers[0].length, identifier.length);
            EXPECT_STREQ(identifiers[0].UTF8String, identifier.UTF8String);

            done = true;
        }];
    }];
    TestWebKitAPI::Util::run(&done);
}

TEST_F(WKContentRuleListStoreTest, NonExistingIdentifierLookup)
{
    __block bool doneLookingUp = false;
    [[WKContentRuleListStore defaultStore] lookUpContentRuleListForIdentifier:@"DoesNotExist" completionHandler:^(WKContentRuleList *filter, NSError *error) {
    
        EXPECT_NULL(filter);
        EXPECT_NOT_NULL(error);
        checkDomain(error);
        EXPECT_EQ(error.code, WKErrorContentRuleListStoreLookUpFailed);
        EXPECT_STREQ("Rule list lookup failed: Unspecified error during lookup.", [[error helpAnchor] UTF8String]);
        
        doneLookingUp = true;
    }];
    TestWebKitAPI::Util::run(&doneLookingUp);
}

TEST_F(WKContentRuleListStoreTest, VersionMismatch)
{
    __block bool doneCompiling = false;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"TestRuleList" encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error)
    {
        
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);
        
        doneCompiling = true;
    }];
    TestWebKitAPI::Util::run(&doneCompiling);

    [[WKContentRuleListStore defaultStore] _invalidateContentRuleListVersionForIdentifier:@"TestRuleList"];
    
    __block bool doneLookingUp = false;
    [[WKContentRuleListStore defaultStore] lookUpContentRuleListForIdentifier:@"TestRuleList" completionHandler:^(WKContentRuleList *filter, NSError *error)
    {
        
        EXPECT_NULL(filter);
        EXPECT_NOT_NULL(error);
        checkDomain(error);
        EXPECT_EQ(error.code, WKErrorContentRuleListStoreVersionMismatch);
        EXPECT_STREQ("Rule list lookup failed: Version of file does not match version of interpreter.", [[error helpAnchor] UTF8String]);
        
        doneLookingUp = true;
    }];
    TestWebKitAPI::Util::run(&doneLookingUp);

    __block bool doneGettingSource = false;
    [[WKContentRuleListStore defaultStore] _getContentRuleListSourceForIdentifier:@"TestRuleList" completionHandler:^(NSString* source) {
        EXPECT_NULL(source);
        doneGettingSource = true;
    }];
    TestWebKitAPI::Util::run(&doneGettingSource);
}

TEST_F(WKContentRuleListStoreTest, Removal)
{
    __block bool doneCompiling = false;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"TestRuleList" encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
    
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);

        doneCompiling = true;
    }];
    TestWebKitAPI::Util::run(&doneCompiling);

    __block bool doneRemoving = false;
    [[WKContentRuleListStore defaultStore] removeContentRuleListForIdentifier:@"TestRuleList" completionHandler:^(NSError *error) {
        EXPECT_NULL(error);

        doneRemoving = true;
    }];
    TestWebKitAPI::Util::run(&doneRemoving);
}

TEST_F(WKContentRuleListStoreTest, NonExistingIdentifierRemove)
{
    __block bool doneRemoving = false;
    [[WKContentRuleListStore defaultStore] removeContentRuleListForIdentifier:@"DoesNotExist" completionHandler:^(NSError *error) {
        EXPECT_NOT_NULL(error);
        checkDomain(error);
        EXPECT_EQ(error.code, WKErrorContentRuleListStoreRemoveFailed);
        EXPECT_STREQ("Rule list removal failed: Unspecified error during remove.", [[error helpAnchor] UTF8String]);

        doneRemoving = true;
    }];
    TestWebKitAPI::Util::run(&doneRemoving);
}

TEST_F(WKContentRuleListStoreTest, NonDefaultStore)
{
    NSURL *tempDir = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"ContentRuleListTest"] isDirectory:YES];
    WKContentRuleListStore *store = [WKContentRuleListStore storeWithURL:tempDir];
    NSString *identifier = @"TestRuleList";
    NSString *fileName = @"ContentRuleList-TestRuleList";

    __block bool doneGettingAvailableIdentifiers = false;
    [store getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
        EXPECT_NOT_NULL(identifiers);
        EXPECT_EQ(identifiers.count, 0u);
        doneGettingAvailableIdentifiers = true;
    }];
    TestWebKitAPI::Util::run(&doneGettingAvailableIdentifiers);
    
    __block bool doneCompiling = false;
    [store compileContentRuleListForIdentifier:identifier encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);
        doneCompiling = true;
    }];
    TestWebKitAPI::Util::run(&doneCompiling);

    doneGettingAvailableIdentifiers = false;
    [store getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
        EXPECT_NOT_NULL(identifiers);
        EXPECT_EQ(identifiers.count, 1u);
        EXPECT_STREQ(identifiers[0].UTF8String, "TestRuleList");
        doneGettingAvailableIdentifiers = true;
    }];
    TestWebKitAPI::Util::run(&doneGettingAvailableIdentifiers);

    NSData *data = [NSData dataWithContentsOfURL:[tempDir URLByAppendingPathComponent:fileName]];
    EXPECT_NOT_NULL(data);
    EXPECT_EQ(data.length, 228u);
    
    __block bool doneCheckingSource = false;
    [store _getContentRuleListSourceForIdentifier:identifier completionHandler:^(NSString *source) {
        EXPECT_NOT_NULL(source);
        EXPECT_STREQ(basicFilter.UTF8String, source.UTF8String);
        doneCheckingSource = true;
    }];
    TestWebKitAPI::Util::run(&doneCheckingSource);
    
    __block bool doneRemoving = false;
    [store removeContentRuleListForIdentifier:identifier completionHandler:^(NSError *error) {
        EXPECT_NULL(error);
        doneRemoving = true;
    }];
    TestWebKitAPI::Util::run(&doneRemoving);

    NSData *dataAfterRemoving = [NSData dataWithContentsOfURL:[tempDir URLByAppendingPathComponent:fileName]];
    EXPECT_NULL(dataAfterRemoving);
}

TEST_F(WKContentRuleListStoreTest, MultipleRuleLists)
{
    __block bool done = false;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"FirstRuleList" encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);
        [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"SecondRuleList" encodedContentRuleList:basicFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
            EXPECT_NOT_NULL(filter);
            EXPECT_NULL(error);
            [[WKContentRuleListStore defaultStore] getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
                EXPECT_NOT_NULL(identifiers);
                EXPECT_EQ(identifiers.count, 2u);
                EXPECT_STREQ(identifiers[0].UTF8String, "FirstRuleList");
                EXPECT_STREQ(identifiers[1].UTF8String, "SecondRuleList");
                done = true;
            }];
        }];
    }];
    TestWebKitAPI::Util::run(&done);
}

TEST_F(WKContentRuleListStoreTest, NonASCIISource)
{
    static NSString *nonASCIIFilter = @"[{\"action\":{\"type\":\"block\"},\"trigger\":{\"url-filter\":\".*webkit.org\"}, \"unused\":\"ðŸ’©\"}]";
    NSURL *tempDir = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"ContentRuleListTest"] isDirectory:YES];
    WKContentRuleListStore *store = [WKContentRuleListStore storeWithURL:tempDir];
    NSString *identifier = @"TestRuleList";
    NSString *fileName = @"ContentRuleList-TestRuleList";
    
    __block bool done = false;
    [store compileContentRuleListForIdentifier:identifier encodedContentRuleList:nonASCIIFilter completionHandler:^(WKContentRuleList *filter, NSError *error) {
        EXPECT_NOT_NULL(filter);
        EXPECT_NULL(error);

        [store _getContentRuleListSourceForIdentifier:identifier completionHandler:^(NSString *source) {
            EXPECT_NOT_NULL(source);
            EXPECT_STREQ(nonASCIIFilter.UTF8String, source.UTF8String);

            [store _removeAllContentRuleLists];
            NSData *dataAfterRemoving = [NSData dataWithContentsOfURL:[tempDir URLByAppendingPathComponent:fileName]];
            EXPECT_NULL(dataAfterRemoving);

            done = true;
        }];
    }];
    TestWebKitAPI::Util::run(&done);
}

static size_t alertCount { 0 };
static bool receivedAlert { false };

@interface ContentRuleListDelegate : NSObject <WKUIDelegate>
@end

@implementation ContentRuleListDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    switch (alertCount++) {
    case 0:
        // Default behavior.
        EXPECT_STREQ("content blockers enabled", message.UTF8String);
        break;
    case 1:
        // After having removed the content RuleList.
        EXPECT_STREQ("content blockers disabled", message.UTF8String);
        break;
    default:
        EXPECT_TRUE(false);
    }
    receivedAlert = true;
    completionHandler();
}

@end

TEST_F(WKContentRuleListStoreTest, AddRemove)
{
    [[WKContentRuleListStore defaultStore] _removeAllContentRuleLists];

    __block bool doneCompiling = false;
    NSString* contentBlocker = @"[{\"action\":{\"type\":\"css-display-none\",\"selector\":\".hidden\"},\"trigger\":{\"url-filter\":\".*\"}}]";
    __block RetainPtr<WKContentRuleList> ruleList;
    [[WKContentRuleListStore defaultStore] compileContentRuleListForIdentifier:@"TestAddRemove" encodedContentRuleList:contentBlocker completionHandler:^(WKContentRuleList *compiledRuleList, NSError *error) {
        EXPECT_TRUE(error == nil);
        ruleList = compiledRuleList;
        doneCompiling = true;
    }];
    TestWebKitAPI::Util::run(&doneCompiling);
    EXPECT_NOT_NULL(ruleList);

    auto configuration = adoptNS([[WKWebViewConfiguration alloc] init]);
    [[configuration userContentController] addContentRuleList:ruleList.get()];

    auto webView = adoptNS([[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600) configuration:configuration.get()]);

    auto delegate = adoptNS([[ContentRuleListDelegate alloc] init]);
    [webView setUIDelegate:delegate.get()];

    NSURLRequest *request = [NSURLRequest requestWithURL:[[NSBundle mainBundle] URLForResource:@"contentBlockerCheck" withExtension:@"html" subdirectory:@"TestWebKitAPI.resources"]];
    alertCount = 0;
    receivedAlert = false;
    [webView loadRequest:request];
    TestWebKitAPI::Util::run(&receivedAlert);

    [[configuration userContentController] removeContentRuleList:ruleList.get()];

    receivedAlert = false;
    [webView reload];
    TestWebKitAPI::Util::run(&receivedAlert);
}

@interface TestSchemeHandlerSubresourceShouldBeBlocked : NSObject <WKURLSchemeHandler>
@end
@implementation TestSchemeHandlerSubresourceShouldBeBlocked
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)task
{
    EXPECT_TRUE([task.request.URL.path isEqualToString:@"/shouldload"]);
    [task didReceiveResponse:[[[NSURLResponse alloc] initWithURL:task.request.URL MIMEType:@"text/html" expectedContentLength:0 textEncodingName:nil] autorelease]];
    [task didFinish];
}
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id <WKURLSchemeTask>)task
{
    EXPECT_TRUE(false);
}
@end

TEST_F(WKContentRuleListStoreTest, UnsafeMMap)
{
    RetainPtr<NSString> tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"UnsafeMMapTest"];
    RetainPtr<WKContentRuleListStore> store = [WKContentRuleListStore storeWithURL:[NSURL fileURLWithPath:tempDir.get() isDirectory:YES]];
    static NSString *identifier = @"TestRuleList";
    static NSString *fileName = @"ContentRuleList-TestRuleList";
    static NSString *ruleListSourceString = @"[{\"action\":{\"type\":\"block\"},\"trigger\":{\"url-filter\":\"blockedsubresource\"}}]";
    RetainPtr<NSString> filePath = [tempDir stringByAppendingPathComponent:fileName];

    auto runTest = [&] (bool shouldUseCopiedMemory) {
        EXPECT_FALSE([[NSFileManager defaultManager] fileExistsAtPath:filePath.get()]);
        
        __block bool doneCompiling = false;
        __block RetainPtr<WKContentRuleList> ruleList;
        [store compileContentRuleListForIdentifier:identifier encodedContentRuleList:ruleListSourceString completionHandler:^(WKContentRuleList *filter, NSError *error) {
            EXPECT_NOT_NULL(filter);
            EXPECT_NULL(error);
            doneCompiling = true;
            ruleList = filter;
            EXPECT_TRUE([[[[_WKUserContentFilter alloc] _initWithWKContentRuleList:filter] autorelease] usesCopiedMemory] == shouldUseCopiedMemory);
        }];
        TestWebKitAPI::Util::run(&doneCompiling);
        
        EXPECT_TRUE([[NSFileManager defaultManager] fileExistsAtPath:filePath.get()]);

        auto handler = adoptNS([TestSchemeHandlerSubresourceShouldBeBlocked new]);
        auto configuration = adoptNS([WKWebViewConfiguration new]);
        [configuration setURLSchemeHandler:handler.get() forURLScheme:@"testmmap"];
        [[configuration userContentController] addContentRuleList:ruleList.get()];
        auto webView = adoptNS([[TestWKWebView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600) configuration:configuration.get()]);
        [webView synchronouslyLoadHTMLString:@"<html>main resource content</html>" baseURL:[NSURL URLWithString:@"testmmap://webkit.org/mainresource"]];

        auto loadingShouldSucceed = [&] (NSString *resourcePath, NSString *shouldSucceed) {
            __block bool doneEvaluating = false;
            [webView evaluateJavaScript:[NSString stringWithFormat:@"var caught = false; var xhr = new XMLHttpRequest(); xhr.open('GET', '%@', false); try{ xhr.send() } catch(e) { caught = true; }; caught != %@ ? 'success' : 'failure'", resourcePath, shouldSucceed] completionHandler:^(id result, NSError *error) {
                EXPECT_NULL(error);
                EXPECT_TRUE([@"success" isEqualToString:result]);
                doneEvaluating = true;
            }];
            TestWebKitAPI::Util::run(&doneEvaluating);
        };
        loadingShouldSucceed(@"/shouldload", @"true");
        loadingShouldSucceed(@"/blockedsubresource", @"false");

        [[configuration userContentController] removeContentRuleList:ruleList.get()];
        
        __block bool doneLookingUp = false;
        [store lookUpContentRuleListForIdentifier:identifier completionHandler:^(WKContentRuleList *filter, NSError *error) {
            EXPECT_NOT_NULL(filter);
            EXPECT_NULL(error);
            
            doneLookingUp = true;
            
            EXPECT_TRUE([[[[_WKUserContentFilter alloc] _initWithWKContentRuleList:filter] autorelease] usesCopiedMemory] == shouldUseCopiedMemory);
            ruleList = filter;
        }];
        TestWebKitAPI::Util::run(&doneLookingUp);

        [[configuration userContentController] addContentRuleList:ruleList.get()];
        loadingShouldSucceed(@"/shouldload", @"true");
        loadingShouldSucceed(@"/blockedsubresource", @"false");

        __block bool doneCheckingSource = false;
        [store _getContentRuleListSourceForIdentifier:identifier completionHandler:^(NSString *source) {
            EXPECT_TRUE([source isEqualToString:ruleListSourceString]);
            doneCheckingSource = true;
        }];
        TestWebKitAPI::Util::run(&doneCheckingSource);
        
        __block bool doneRemoving = false;
        [store removeContentRuleListForIdentifier:identifier completionHandler:^(NSError *error) {
            EXPECT_NULL(error);
            doneRemoving = true;
        }];
        TestWebKitAPI::Util::run(&doneRemoving);

        EXPECT_FALSE([[NSFileManager defaultManager] fileExistsAtPath:filePath.get()]);
    };
    
    runTest(false);
    [WKContentRuleListStore _registerPathAsUnsafeToMemoryMapForTesting:filePath.get()];
    runTest(true);
}
