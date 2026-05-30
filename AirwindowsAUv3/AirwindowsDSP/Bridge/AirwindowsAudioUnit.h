//
//  AirwindowsAudioUnit.h
//  AirwindowsDSP framework
//
//  Public ObjC interface for the AUv3 audio unit. Swift talks to this
//  header to read the current effect, change effect, and ask for
//  parameter display strings.
//
//  Full architecture / threading / parameter-layout notes live at the
//  top of AirwindowsAudioUnit.mm.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface AirwindowsAudioUnit : AUAudioUnit

// Current effect info (readable from Swift for UI)
@property (nonatomic, readonly) NSInteger currentEffectIndex;
@property (nonatomic, readonly) NSString *currentEffectName;
@property (nonatomic, readonly) NSString *currentEffectCategory;
@property (nonatomic, readonly) NSInteger currentParameterCount;

// Effect selection
- (void)selectEffectAtIndex:(NSInteger)index;

// Parameter info for current effect
- (NSString *)parameterNameAtIndex:(NSInteger)paramIndex;
- (NSString *)parameterDisplayAtIndex:(NSInteger)paramIndex;
- (NSString *)parameterLabelAtIndex:(NSInteger)paramIndex;

// For "popup" (stepped/notched) parameters — Chris implements these in the
// DSP via casts like `(VstInt32)(A * N.999)` that map 0..1 onto N discrete
// cases. We detect them by sampling getParameterDisplay across the range
// and counting unique strings. Returns 0 when the parameter is continuous.
- (NSInteger)parameterStepCountAtIndex:(NSInteger)paramIndex;

@end
