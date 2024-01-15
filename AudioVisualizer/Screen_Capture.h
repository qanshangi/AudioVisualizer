//
//  Screen_Capture.h
//  Audio Visualizer
//
//  Created by content on 12/8/23.
//

#ifndef Screen_Capture_h
#define Screen_Capture_h

#include <IOSurface/IOSurface.h>
#include <ScreenCaptureKit/ScreenCaptureKit.h>
#include <CoreMedia/CMSampleBuffer.h>
#include <CoreVideo/CVPixelBuffer.h>

#ifdef DEBUG
#define DebugLog(fmt, ...) printf("[Debug] " fmt "\n", ##__VA_ARGS__)
#else
#define DebugLog(fmt, ...)
#endif

#define BAND_NUM 42

typedef struct __screen_capture_t screen_capture_t;

@interface ScreenCaptureDelegate : NSObject <SCStreamOutput, SCStreamDelegate>

@property screen_capture_t *sc;

@end

struct __screen_capture_t {
    SCStream *stream;
    SCStreamConfiguration *streamConfiguration;
    SCShareableContent *shareableContent;
    ScreenCaptureDelegate *captureDelegate;
    CGDirectDisplayID displayID;
    dispatch_semaphore_t semaphore;
    
};

void screen_capture_init(screen_capture_t *sc);

bool screen_get_content_list(screen_capture_t *sc);

bool screen_stream_init_audio(screen_capture_t *sc);

bool screen_stream_start_audio(screen_capture_t *sc);

bool screen_stream_stop_audio(screen_capture_t *sc);

#endif /* Screen_Capture_h */
