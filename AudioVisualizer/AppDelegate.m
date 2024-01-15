//
//  AppDelegate.m
//  Audio Visualizer
//
//  Created by content on 2023/11/25.
//

#import "AppDelegate.h"
#import "View.h"
#import "Screen_Capture.h"

extern float bands[BAND_NUM];

@interface AppDelegate ()

@property (weak) IBOutlet NSMenu *appMenu;
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) View *view;
@property (nonatomic, strong)NSStatusItem *statusItem;
@property (nonatomic) screen_capture_t sc;
@property (strong, nonatomic) NSMenu *menu;

@end

/**
 * Function to check if the current application is on the active desktop.
 */
BOOL isAppOnActiveDesktop(void) {
    // Get the current running application
    NSRunningApplication *currentApp = [NSRunningApplication currentApplication];
    // Get the process identifier of the current application
    pid_t currentProcessIdentifier = currentApp.processIdentifier;
    
    // Get a list of windows on the screen
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    
    // Iterate through the window list
    for (NSDictionary *windowInfo in (__bridge NSArray *)windowList) {
        // Get the process identifier of the window
        pid_t windowProcessIdentifier = [windowInfo[(__bridge NSString *)kCGWindowOwnerPID] intValue];
        
        // Check if the window belongs to the current application
        if (windowProcessIdentifier == currentProcessIdentifier) {
            CFRelease(windowList);
            return YES;
        }
    }
    
    // Release the window list and return false if the active desktop is not found
    CFRelease(windowList);
    
    return NO;
}

@implementation AppDelegate

- (void)initMenu:(NSMenu *)menu {
    // Create status bar item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    // Set tooltip
    self.statusItem.button.toolTip = @"Wallpaper";
    self.statusItem.button.target = self;
    // Load and set image
    NSImage *image = [NSImage imageNamed:@"MenuBarImage"];
    image.template = YES;
    self.statusItem.button.image = image;
    // Set menu delegate
    self.statusItem.menu.delegate = self;

    // Configure menu
    self.statusItem.menu = menu;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    CGFloat screenWidth;
    //CGFloat screenHeight;
    CGFloat winX;
    CGFloat winY;
    
    // Create status bar menu
    [self initMenu:self.appMenu];

    // Check if there is already an instance running
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([[NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier] count] > 1) {
        // Quit app
        [NSApp terminate:nil];
    }

    // Listen for screen wake
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(screenDidWake:)
                                                               name:NSWorkspaceScreensDidWakeNotification
                                                             object:nil];
    // Listen for screen sleep
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(screenDidSleep:)
                                                               name:NSWorkspaceScreensDidSleepNotification
                                                             object:nil];
    // Listen for active space change
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(activeSpaceDidChange:)
                                                               name:NSWorkspaceActiveSpaceDidChangeNotification
                                                             object:nil];
    
    if (@available(macOS 13.0, *)) {
        // Get current screen
        NSScreen *mainScreen = [NSScreen mainScreen];

        NSRect screenFrame = [mainScreen frame];

        // Get screen width and height
        screenWidth = NSWidth(screenFrame);
        // screenHeight = NSHeight(screenFrame);

        winX = (screenWidth - VIEW_WIDE) / 2;
        winY = 70;

        // Create window
        self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(winX, winY, VIEW_WIDE, VIEW_HEIGHT)
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];

        // Set window to be transparent
        [self.window setBackgroundColor:[NSColor clearColor]];
        [self.window setOpaque:NO];

        // Create view
        self.view = [[View alloc] initWithFrame:NSMakeRect(0, 0, VIEW_WIDE, VIEW_HEIGHT)];

        [self.window.contentView addSubview:self.view];

        // Set window to ignore mouse events, allowing the mouse to pass through the window
        [self.window setIgnoresMouseEvents:YES];
            
        // Display window
        [self.window setLevel:NSFloatingWindowLevel];
        [self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary];

        [self.window orderFront:nil];
        
        screen_capture_init(&_sc);
        
        if (!screen_get_content_list(&_sc)) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"提示"];
            [alert setInformativeText:@"应用需要屏幕录制权限！\n本应用不会上传保存任何音视频数据。\nGitHub开源地址：qanshangi/Audio Visualizer"];
            [alert addButtonWithTitle:@"确定"];

            [alert runModal];
        } else {
            screen_stream_init_audio(&_sc);
            
            screen_stream_start_audio(&_sc);
        }
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert setMessageText:@"警告"];
        [alert setInformativeText:@"应用只支持 macOS 13.0 及之后版本！"];
        
        [alert addButtonWithTitle:@"确定"];
        
        [alert setAlertStyle:NSAlertStyleWarning];
        
        [alert runModal];
        
        exit(0);
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    
    // Remove observer
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)screenDidWake:(NSNotification *)notification {
    screen_get_content_list(&_sc);
    screen_stream_init_audio(&_sc);
    screen_stream_start_audio(&_sc);
}

- (void)screenDidSleep:(NSNotification *)notification {
    screen_stream_stop_audio(&_sc);
}

- (void)activeSpaceDidChange:(NSNotification *)notification {
    /* Check if the current application is on the active desktop. */
    if (isAppOnActiveDesktop()) {
        [self.view startRefresh];
        screen_stream_start_audio(&_sc);
    } else {
        screen_stream_stop_audio(&_sc);
        
        for(int i = 0; i < BAND_NUM; i++)
        {
            bands[i] = 0.0;
        }
        [self.view nowRefresh];
        
        [self.view stopRefresh];
    }
}

- (IBAction)changeWindowLevel:(NSMenuItem *)sender {
    // Toggle the state
    BOOL hide = (sender.state == NSControlStateValueOn) ? YES : NO;

    // Set the new state
    [sender setState:(hide ? NSControlStateValueOff : NSControlStateValueOn)];

    // Save the state in UserDefaults
    //[[NSUserDefaults standardUserDefaults] setBool:hide forKey:@"HideNotch"];

    // Additional logic for when hide is YES
    if (hide) {
        [self.window setLevel:NSNormalWindowLevel];
        [self.window orderBack:nil];
    } else {
        [self.window setLevel:NSFloatingWindowLevel];
        [self.window orderFront:nil];
    }
}

- (IBAction)openAboutPanel:(NSMenuItem *)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:sender];
}

@end
