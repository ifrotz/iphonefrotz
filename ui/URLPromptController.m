//
//  URLPromptController.m
//  Frotz
//
//  Created by Craig Smith on 8/6/08.
//  Copyright 2008 Craig Smith. All rights reserved.
//

#import "URLPromptController.h"
#include "iosfrotz.h"

@implementation URLPromptController
@synthesize delegate = m_delegate;

- (instancetype)init
{
    self = [super init];
    if (self) {
        // this title will appear in the navigation bar
        self.title = NSLocalizedString(@"URL", @"");
    }
    
    return self;
}


- (void)setText:(NSString*)text {
    [m_textbar setText: text];
}

- (void)setPlaceholder:(NSString*)text {
    [m_textbar setPlaceholder: text];
}

- (void)loadView
{
    // add the top-most parent view
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
    CGRect frame = CGRectMake(0, 0, appFrame.size.width, kSearchBarHeight);
    UIView *contentView = [[UIView alloc] initWithFrame: frame];

    [contentView setAutoresizingMask: UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin];
    [contentView setAutoresizesSubviews: YES];

    contentView.backgroundColor = [UIColor whiteColor];
    self.view = contentView;
    
    m_textbar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, appFrame.size.width, kSearchBarHeight)];
    
    UIImage *img = [UIImage imageNamed: @"icon-url-srch"];
    UIImageView *imgView = [[UIImageView alloc] initWithImage: img];
    [m_textbar addSubview: imgView];
    [m_textbar bringSubviewToFront:imgView];
    CGSize isz = [img size];
    [imgView setFrame: CGRectMake(14, 9, isz.width, isz.height)];

    m_textbar.placeholder = @"URL";
    m_textbar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleRightMargin;
    m_textbar.barStyle = UIBarStyleDefault;

    m_textbar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    m_textbar.autocorrectionType = UITextAutocorrectionTypeNo;
    m_textbar.delegate = self;
    m_textbar.showsCancelButton = NO;
    m_textbar.showsBookmarkButton = YES;
    m_textbar.keyboardType = UIKeyboardTypeURL;
    
    [self.view addSubview: m_textbar];
}


// called when keyboard search button pressed
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [m_textbar resignFirstResponder];
    if (!(iosif_ifrotz_verbose_debug & (2|8))) {
        NSString *text = [m_textbar text];
        if ([text rangeOfString:@"://"].length==0)
            text = [@"http://" stringByAppendingString: text];
        m_textbar.text = @"";
        [[UIApplication sharedApplication] openURL: [NSURL URLWithString: text]];
        [m_delegate dismissURLPrompt];
        return;
    }

    if (m_delegate)
        [m_delegate enterURL: [m_textbar text]];
}

// called when cancel button pressed
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [m_textbar resignFirstResponder];
    if (m_delegate)
        [m_delegate dismissURLPrompt];
}

- (void)searchBarBookmarkButtonClicked:(UISearchBar *)searchBar {
    [m_textbar resignFirstResponder];
    if (m_delegate)
        [m_delegate showBookmarks];
}

@end
