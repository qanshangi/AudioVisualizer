#import <Cocoa/Cocoa.h>
#import "View.h"
#import "Screen_Capture.h"

extern float bands[BAND_NUM];

bool darkMode = false;

@implementation View {
    CVDisplayLinkRef displayLink;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    
    if (self) {
        
        // Create displayLink
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
        CVDisplayLinkSetOutputCallback(displayLink, &displayLinkCallback, (__bridge void *)(self));

        // Start displayLink
        CVDisplayLinkStart(displayLink);
    }
    
    return self;
}

- (void)dealloc {
    // Stop and release displayLink
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
}

- (void)startRefresh {
    CVDisplayLinkStart(displayLink);
}

- (void)stopRefresh {
    CVDisplayLinkStop(displayLink);
}

- (void)nowRefresh {
    // Call setNeedsDisplay: on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
}


// Time of the last frame
static CFTimeInterval lastFrameTime = 0.0;

// Refresh rate 30Hz
CFTimeInterval targetFrameDuration = 1.0 / 30.0;

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
                                     const CVTimeStamp *now,
                                     const CVTimeStamp *outputTime,
                                     CVOptionFlags flagsIn,
                                     CVOptionFlags *flagsOut,
                                     void *displayLinkContext) {
    @autoreleasepool {
        View *self = (__bridge View *)displayLinkContext;

        // Get current time
        CFTimeInterval currentTime = CACurrentMediaTime();

        CFTimeInterval elapsedTime = currentTime - lastFrameTime;

        if (elapsedTime < targetFrameDuration) {
            return kCVReturnSuccess;
        }

        // Update time of the last frame
        lastFrameTime = currentTime;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsDisplay:YES];
        });

        return kCVReturnSuccess;
    }
}

int count = 0;

- (void)layout {
    [super layout];
    
    darkMode = [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Get current context
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];

    // Set fill color and stroke color
    if (darkMode){
        [[NSColor colorWithCalibratedWhite:0.9 alpha:0.95] setFill];
        
        [[NSColor colorWithCalibratedWhite:0.8 alpha:0.9] setStroke];
    } else {
        [[NSColor colorWithCalibratedWhite:0.6 alpha:0.95] setFill];
        
        [[NSColor colorWithCalibratedWhite:0.65 alpha:0.9] setStroke];
    }

    count = 0;

    @autoreleasepool {
        for(int i = 0; i < BAND_NUM; i++)
        {
            int height = bands[i] * 5000;
            
            if (height == 0 && i < 13)
            {
                count++;
            }
            
            height = height > 0 ? height + 6 : 6;
            height = height > 300 ? 300 : height;
            
            // Create rounded rectangle path
            NSRect bounds = NSMakeRect(i * 16, 0, 6, height);
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:3 yRadius:3];
            [path setLineWidth:1.0];
            
            [path fill];
            [path stroke];
        }
    }
    
    if (count >= 13)
    {
        // 4Hz.
        if (targetFrameDuration != 0.25) {
            targetFrameDuration = 0.25;
        }
    }
    else
    {
        // 30Hz.
        if (targetFrameDuration == 0.25) {
            targetFrameDuration = 1.0 / 30.0;
        }
    }
    
    [context restoreGraphicsState];
}

@end
