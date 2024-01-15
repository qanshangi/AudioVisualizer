//
//  Screen_Capture.m
//  Audio Visualizer
//
//  Created by content on 12/8/23.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import "Screen_Capture.h"

#define FFTSIZE 2048

float bands[BAND_NUM];

static float fftResultPink[BAND_NUM] = {1.15, 1.16, 1.18, 1.18, 1.20, 1.21, 1.23, 1.24, 1.23, 1.25, 1.27, 1.30, 1.31, 1.35, 1.39, 1.42, 1.43, 1.48, 1.50, 1.56, 1.59, 1.62, 1.63, 1.65, 1.68, 1.62, 1.75, 1.80, 1.91, 2.06, 2.34, 2.47, 2.64, 2.85, 3.01, 3.23, 3.56, 3.89, 4.23, 5.01, 5.44, 6.24};

typedef struct {
    // Complex number array
    DSPSplitComplex complexBuffer;
    float *magnitudeBuffer;
    FFTSetup setup;
    // Size of the complex number array
    int numFramesPadded;
    // Window function array
    float *window;
    
} fft_t;

static fft_t fft;

static float fft_add(float *magnitudeBuffer, int start, int end) {
    float result = 0;
    
    for(; start <= end; start++)
    {
        result += magnitudeBuffer[start];
    }
    
    return result;
}

static void fft_destroy(void)
{
    if (fft.setup != NULL)
    {
        vDSP_destroy_fftsetup(fft.setup);
        free(fft.complexBuffer.realp);
        free(fft.complexBuffer.imagp);
        free(fft.magnitudeBuffer);
        free(fft.window);
        
        fft.setup = NULL;
        fft.complexBuffer.realp = NULL;
        fft.complexBuffer.imagp = NULL;
        fft.magnitudeBuffer = NULL;
        fft.window = NULL;
    }
}

static void audio_stream_update(CMSampleBufferRef sampleBuffer)
{
    const AudioStreamBasicDescription *audioStreamDescription =
        CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));

    if (audioStreamDescription->mChannelsPerFrame != 1) {
        DebugLog("The sample buffer is not a channel:'%d')\n",
                 audioStreamDescription->mChannelsPerFrame);
        return;
    }

    char *_Nullable bytes = NULL;
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t dataLength = CMBlockBufferGetDataLength(dataBuffer);
    CMBlockBufferGetDataPointer(dataBuffer, 0, &dataLength, NULL, &bytes);

    // Audio data
    float *audioData = (float*)bytes;
    UInt32 numFrames = (UInt32)dataLength / sizeof(float);

    if (fft.setup == NULL)
    {
        // Calculate the number of frames for the audio data
        fft.numFramesPadded = FFTSIZE * ceil((float)numFrames / FFTSIZE);
        
        fft.setup = vDSP_create_fftsetup(log2(FFTSIZE), FFT_RADIX2);
        
        fft.complexBuffer.realp = (float *)malloc(fft.numFramesPadded * sizeof(float));
        fft.complexBuffer.imagp = (float *)malloc(fft.numFramesPadded * sizeof(float));
        
        fft.magnitudeBuffer = (float *)malloc(FFTSIZE / 2 * sizeof(float));
        
        fft.window = (float *)malloc(numFrames * sizeof(float));
        
        // Initialize window function array.
        vDSP_hamm_window(fft.window, numFrames, 0);
    }

    // Apply window function to audio data.
    vDSP_vmul(audioData, 1, fft.window, 1, audioData, 1, numFrames);

    // Copy audio data to the real part
    memcpy(fft.complexBuffer.realp, audioData, numFrames * sizeof(float));

    // Fill the remaining part.
    //memset(fft.complexBuffer.realp + numFrames, 0, (fft.numFramesPadded - numFrames) * sizeof(float));

    vDSP_vclr(fft.complexBuffer.realp + numFrames, 1, fft.numFramesPadded - numFrames);
    // Zero out the imaginary part
    vDSP_vclr(fft.complexBuffer.imagp, 1, fft.numFramesPadded);


    // Perform FFT
    vDSP_fft_zip(fft.setup, &fft.complexBuffer, 1, log2(FFTSIZE), FFT_FORWARD);

    // Calculate magnitude spectrum
    vDSP_zvabs(&fft.complexBuffer, 1, fft.magnitudeBuffer, 1, FFTSIZE / 2);

    // Normalize FFT output.
    float normalizeFactor = 1.0 / FFTSIZE;
    vDSP_vsmul(fft.magnitudeBuffer, 1, &normalizeFactor, fft.magnitudeBuffer, 1, FFTSIZE / 2);
    
    bands[0] = fft_add(fft.magnitudeBuffer, 0, 1) / 2;
    bands[1] = fft_add(fft.magnitudeBuffer, 1, 3) / 3;
    bands[2] = fft_add(fft.magnitudeBuffer, 3, 4) / 2;
    bands[3] = fft_add(fft.magnitudeBuffer, 4, 6) / 3;
    bands[4] = fft_add(fft.magnitudeBuffer, 6, 9) / 4;
    bands[5] = fft_add(fft.magnitudeBuffer, 9, 13) / 5;
    bands[6] = fft_add(fft.magnitudeBuffer, 13, 17) / 5;
    bands[7] = fft_add(fft.magnitudeBuffer, 17, 22) / 6;
    bands[8] = fft_add(fft.magnitudeBuffer, 22, 27) / 6;
    bands[9] = fft_add(fft.magnitudeBuffer, 27, 33) / 7;
    bands[10] = fft_add(fft.magnitudeBuffer, 33, 40) / 7;
    bands[11] = fft_add(fft.magnitudeBuffer, 40, 47) / 8;
    bands[12] = fft_add(fft.magnitudeBuffer, 47, 54) / 8;
    bands[13] = fft_add(fft.magnitudeBuffer, 54, 60) / 7;
    bands[14] = fft_add(fft.magnitudeBuffer, 60, 67) / 8;
    bands[15] = fft_add(fft.magnitudeBuffer, 67, 75) / 9;
    bands[16] = fft_add(fft.magnitudeBuffer, 75, 82) / 8;
    bands[17] = fft_add(fft.magnitudeBuffer, 82, 91) / 10;
    bands[18] = fft_add(fft.magnitudeBuffer, 91, 100) / 10;
    bands[19] = fft_add(fft.magnitudeBuffer, 100, 110) / 11;
    bands[20] = fft_add(fft.magnitudeBuffer, 110,  119) / 10;
    bands[21] = fft_add(fft.magnitudeBuffer, 119, 127) / 9;
    bands[22] = fft_add(fft.magnitudeBuffer, 127, 135) / 9;
    bands[23] = fft_add(fft.magnitudeBuffer, 135, 144) / 10;
    bands[24] = fft_add(fft.magnitudeBuffer, 144, 153) / 10;
    bands[25] = fft_add(fft.magnitudeBuffer, 153, 163) / 11;
    bands[26] = fft_add(fft.magnitudeBuffer, 163, 174) / 12;
    bands[27] = fft_add(fft.magnitudeBuffer, 174, 186) / 13;
    bands[28] = fft_add(fft.magnitudeBuffer, 186, 197) / 12;
    bands[29] = fft_add(fft.magnitudeBuffer, 197, 209) / 13;
    bands[30] = fft_add(fft.magnitudeBuffer, 209, 222) / 14;
    bands[31] = fft_add(fft.magnitudeBuffer, 222, 236) / 15;
    bands[32] = fft_add(fft.magnitudeBuffer, 236, 249) / 14;
    bands[33] = fft_add(fft.magnitudeBuffer, 249,  262) / 14;
    bands[34] = fft_add(fft.magnitudeBuffer, 262, 276) / 15;
    bands[35] = fft_add(fft.magnitudeBuffer, 276,  291) / 16;
    
    bands[36] = fft_add(fft.magnitudeBuffer, 291, 308) / 18;
    bands[37] = fft_add(fft.magnitudeBuffer, 308,  328) /  21;
    bands[38] = fft_add(fft.magnitudeBuffer, 328, 353) / 26;
    
    bands[39] = fft_add(fft.magnitudeBuffer, 353,  384) / 32;
    bands[40] = fft_add(fft.magnitudeBuffer, 384, 423) / 40;
    bands[41] = fft_add(fft.magnitudeBuffer, 423, 474) /  52;
    
    for(int i = 0; i < BAND_NUM; i++)
    {
        bands[i] *= fftResultPink[i];
    }
}

/*
 * https://github.com/obsproject/obs-studio/tree/master/plugins/mac-capture
 */
@implementation ScreenCaptureDelegate

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type == SCStreamOutputTypeAudio) {
        audio_stream_update(sampleBuffer);
   }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    switch (error.code) {
        case SCStreamErrorUserStopped:
            DebugLog("User stopped stream.");
            break;
        case SCStreamErrorNoCaptureSource:
            DebugLog("Stream stopped as no capture source was not found.");
            break;
        default:
            DebugLog("Stream stopped with error %ld (\"%s\")", error.code,
                                                      error.localizedDescription.UTF8String);
            break;
    }

    self.sc->stream = nil;
    fft_destroy();
}

@end

void screen_capture_init(screen_capture_t *sc) {
    // Create semaphore
    sc->semaphore = dispatch_semaphore_create(0);
}

bool screen_get_content_list(screen_capture_t *sc) {
    __block BOOL result = true;
    typedef void (^shareable_content_callback)(SCShareableContent *, NSError *);
    
    shareable_content_callback new_content_received = ^void(SCShareableContent *shareableContent, NSError *error) {
        if (error == nil) {
            sc->shareableContent = shareableContent;
        } else {
            DebugLog("Failed to get shareable content with error %s\n",
                       [[error localizedFailureReason] cStringUsingEncoding:NSUTF8StringEncoding]);
            
            result = false;
        }
        // Release signal
        dispatch_semaphore_signal(sc->semaphore);
    };
    
    [SCShareableContent getShareableContentExcludingDesktopWindows:YES      onScreenWindowsOnly:NO
        completionHandler:new_content_received];
    
    // Wait for signal
    dispatch_semaphore_wait(sc->semaphore, DISPATCH_TIME_FOREVER);
    
    return result;
}

bool screen_stream_init_audio(screen_capture_t *sc) {
    SCContentFilter *contentFilter;
    SCDisplay *scDisplay;
    
    sc->captureDelegate = [[ScreenCaptureDelegate alloc] init];
    sc->captureDelegate.sc = sc;
    
    sc->streamConfiguration = [[SCStreamConfiguration alloc] init];
    
    sc->displayID = CGMainDisplayID();
    
    for (SCDisplay *display in sc->shareableContent.displays) {
        if (display.displayID == sc->displayID) {
            scDisplay = display;
            break;
        }
    }
    
    NSArray *empty = [[NSArray alloc] init];
    contentFilter = [[SCContentFilter alloc] initWithDisplay:scDisplay excludingWindows:empty];

    [sc->streamConfiguration setCapturesAudio:YES];
    [sc->streamConfiguration setExcludesCurrentProcessAudio:YES];
    [sc->streamConfiguration setChannelCount:1];

    sc->stream = [[SCStream alloc] initWithFilter:contentFilter configuration:sc->streamConfiguration
                                       delegate:sc->captureDelegate];

    NSError *error = nil;
    BOOL result = [sc->stream addStreamOutput:sc->captureDelegate type:SCStreamOutputTypeScreen
                                 sampleHandlerQueue:nil
                                              error:&error];
    if (!result) {
        DebugLog("Failed to add video stream output with error %s\n", [[error localizedFailureReason] cStringUsingEncoding:NSUTF8StringEncoding]);
        return !result;
    }

    result = [sc->stream addStreamOutput:sc->captureDelegate type:SCStreamOutputTypeAudio sampleHandlerQueue:nil
                                         error:&error];
    if (!result) {
        DebugLog("Failed to add audio stream output with error %s\n",
                   [[error localizedFailureReason] cStringUsingEncoding:NSUTF8StringEncoding]);
        return !result;
    }

    return true;
}

bool screen_stream_start_audio(screen_capture_t *sc) {
    __block BOOL did_stream_start = false;
    NSError *error = nil;
    
    [sc->stream startCaptureWithCompletionHandler:^(NSError *_Nullable error2) {
        did_stream_start = (BOOL) (error2 == nil);
        if (!did_stream_start) {
            DebugLog("Failed to start capture with error %s\n", [[error localizedFailureReason] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        dispatch_semaphore_signal(sc->semaphore);
    }];
    dispatch_semaphore_wait(sc->semaphore, DISPATCH_TIME_FOREVER);
    
    return did_stream_start;
}

bool screen_stream_stop_audio(screen_capture_t *sc) {
    __block BOOL did_stream_stop = true;
    NSError *error = nil;
    
    if (sc->stream != nil) {
        [sc->stream stopCaptureWithCompletionHandler:^(NSError *_Nullable error2) {
            did_stream_stop = (BOOL) (error2 == nil);
            if (!did_stream_stop) {
                DebugLog("Failed to start capture with error %s\n", [[error localizedFailureReason] cStringUsingEncoding:NSUTF8StringEncoding]);
            }
            dispatch_semaphore_signal(sc->semaphore);
        }];
        dispatch_semaphore_wait(sc->semaphore, DISPATCH_TIME_FOREVER);
    }
    
    return did_stream_stop;
}
