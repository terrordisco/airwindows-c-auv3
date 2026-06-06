//
//  AirwindowsAudioUnit.mm
//  AirwindowsDSP framework
//
//  The plugin's audio engine. An AUv3 AUAudioUnit subclass that wraps
//  Chris Johnson's ~350 Airwindows effects. Each effect is a C++ class
//  derived from AirwinConsolidatedBase (in ../Airwin/); this AU swaps the
//  active processor whenever the user picks a different effect from the
//  browser.
//
//  ARCHITECTURE — why this class lives in the framework
//  ----------------------------------------------------
//  The Airwindows C++ source uses static-initialiser self-registration to
//  populate AirwinRegistry. That registry MUST populate exactly ONCE per
//  process. If this AU subclass lived in the AUv3 extension target instead,
//  the standalone host app and the extension would each compile their own
//  copy of the C++ code → two registries, double effect counts, hard-to-
//  debug ghosts. Putting AU + DSP in a shared framework (AirwindowsDSP)
//  means the registry initialises once and both targets just link to it.
//
//  THREADING
//  ---------
//  Main thread   — UI calls: selectEffectAtIndex:, setParameterValue:,
//                  fullState / setFullState:.
//  Audio thread  — internalRenderBlock and the C++ it calls.
//                  Realtime constraint: NEVER allocates, deletes, or locks.
//
//  Cross-thread handoffs:
//    _paramValues[]      Plain float array. Main writes, audio reads.
//                        Torn writes here don't matter at UI-knob rates.
//    _pendingProcessor   std::atomic<…*>. Main creates a new processor and
//                        publishes it; audio swaps it in on the next render
//                        and posts the old one back to main via
//                        dispatch_async to be deleted there.
//    _activeParamCount   atomic int, capped at kMaxEffectParams.
//
//  PARAMETER LAYOUT (AUParameterTree addresses)
//  --------------------------------------------
//    0  .. 36   Per-effect params (Chris's slots A, B, … up to 37 per
//               effect. Current effects don't reach 37, but the ceiling
//               has to be a fixed compile-time constant for the tree.)
//    37         effectIndex — which Airwindows effect is active.
//    38         inputLevel  — linear gain, range 0..2, unity at 1.0.
//    39         outputLevel — linear gain, range 0..2, unity at 1.0.
//
//  TWO PROCESSORS ARE ALWAYS LIVE
//  ------------------------------
//    _activeProcessor    The realtime audio path.
//    _displayProcessor   A duplicate used only on the main thread to answer
//                        UI queries (parameter labels, value→string
//                        formatting, stepped-parameter detection) without
//                        touching the audio thread's processor.
//
//  RELATED FILES
//  -------------
//    AirwindowsAudioUnit.h     Public ObjC interface, called from Swift.
//    AirwindowsBridge.mm       Non-AU helpers: registry exposure, the
//                              override-JSON layer, effect metadata.
//    ../Airwin/AirwinRegistry  Chris's upstream registry (do not edit).
//    AUv3ViewController.swift  Extension entry point — creates this AU
//                              and bolts the SwiftUI UI on top.
//

#import "AirwindowsAudioUnit.h"
#import "AirwindowsBridge.h"
#include <atomic>
#include <memory>
#include <os/log.h>
#include "../Airwin/AirwinRegistry.h"

static os_log_t airwindowsLog() {
    static os_log_t log = os_log_create("com.terrordisco.airwindows.consolidated", "AudioUnit");
    return log;
}

NSString * const AirwindowsAudioUnitDidRestoreStateNotification =
    @"AirwindowsAudioUnitDidRestoreStateNotification";

static const NSInteger kMaxEffectParams = 37;
static const AUParameterAddress kEffectIndexAddress = 37;
static const AUParameterAddress kInputLevelAddress = 38;
static const AUParameterAddress kOutputLevelAddress = 39;

@interface AirwindowsAudioUnit () {
    AUAudioUnitBus *_inputBus;
    AUAudioUnitBus *_outputBus;
    AUAudioUnitBusArray *_inputBusArray;
    AUAudioUnitBusArray *_outputBusArray;

    // DSP state
    std::unique_ptr<AirwinConsolidatedBase> _activeProcessor;
    std::atomic<AirwinConsolidatedBase *> _pendingProcessor;
    std::unique_ptr<AirwinConsolidatedBase> _displayProcessor;

    // Parameter values (written by param observer, read by audio thread)
    float _paramValues[kMaxEffectParams];
    std::atomic<int> _activeParamCount;
    std::atomic<NSInteger> _effectIndex;
    float _inputLevel;
    float _outputLevel;

    // Old processor to be freed on main thread
    std::atomic<AirwinConsolidatedBase *> _processorToFree;
}

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property (nonatomic, readwrite) NSArray<AUParameter *> *effectParameters;
@property (nonatomic, readwrite) AUParameter *effectIndexParam;

@end

@implementation AirwindowsAudioUnit

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError **)outError {
    os_log(airwindowsLog(), "initWithComponentDescription called");
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    if (!self) {
        os_log_error(airwindowsLog(), "super init FAILED: %{public}@", outError ? *outError : nil);
        return nil;
    }
    os_log(airwindowsLog(), "super init succeeded");

    [AirwindowsEngine initializeRegistry];
    os_log(airwindowsLog(), "registry initialized, effect count: %lu", (unsigned long)AirwinRegistry::registry.size());

    // Set default sample rate
    AirwinConsolidatedBase::defaultSampleRate = 44100.f;

    // Initialize parameter values
    for (int i = 0; i < kMaxEffectParams; i++) {
        _paramValues[i] = 0.5f;
    }
    _activeParamCount = 0;
    // -1 = "no effect selected" → render block passes audio through unchanged
    // until the user picks an effect from the browser.
    _effectIndex = -1;
    _inputLevel = 1.0f;
    _outputLevel = 1.0f;
    _pendingProcessor = nullptr;
    _processorToFree = nullptr;

    // Create audio buses
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
    _inputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    _inputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses:@[_inputBus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[_outputBus]];

    // Build parameter tree (no effect selected yet → passthrough)
    [self setupParameterTree];

    self.maximumFramesToRender = 4096;

    return self;
}

- (void)setupParameterTree {
    NSInteger regSize = (NSInteger)AirwinRegistry::registry.size();

    // Create kMaxEffectParams fixed per-effect parameter slots. They're
    // generic ("Param 1"..."Param N") here — the names/labels become
    // meaningful once an effect is selected and we query its display
    // strings via _displayProcessor.
    NSMutableArray *effectParams = [NSMutableArray arrayWithCapacity:kMaxEffectParams];
    for (int i = 0; i < kMaxEffectParams; i++) {
        AUParameter *p = [AUParameterTree createParameterWithIdentifier:[NSString stringWithFormat:@"param%d", i]
                                                                   name:[NSString stringWithFormat:@"Param %d", i + 1]
                                                                address:i
                                                                    min:0.0
                                                                    max:1.0
                                                                   unit:kAudioUnitParameterUnit_Generic
                                                               unitName:nil
                                                                  flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                           valueStrings:nil
                                                    dependentParameters:nil];
        p.value = 0.5;
        [effectParams addObject:p];
    }
    self.effectParameters = effectParams;

    // Effect index parameter
    self.effectIndexParam = [AUParameterTree createParameterWithIdentifier:@"effectIndex"
                                                                      name:@"Effect"
                                                                   address:kEffectIndexAddress
                                                                       min:0
                                                                       max:MAX(0, regSize - 1)
                                                                      unit:kAudioUnitParameterUnit_Indexed
                                                                  unitName:nil
                                                                     flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                              valueStrings:nil
                                                       dependentParameters:nil];

    // Input/output level parameters. Range 0..2 (linear gain); 1.0 = unity
    // (0 dB), 2.0 ≈ +6.02 dB. The DSP path multiplies the audio buffer by the
    // raw value, so a host writing a value > 1.0 simply boosts the signal —
    // no extra mapping required. Default stays at 1.0 so existing presets and
    // fresh sessions are pass-through.
    AUParameter *inputLevel = [AUParameterTree createParameterWithIdentifier:@"inputLevel"
                                                                        name:@"Input Level"
                                                                     address:kInputLevelAddress
                                                                         min:0.0
                                                                         max:2.0
                                                                        unit:kAudioUnitParameterUnit_Generic
                                                                    unitName:nil
                                                                       flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                valueStrings:nil
                                                         dependentParameters:nil];
    inputLevel.value = 1.0;

    AUParameter *outputLevel = [AUParameterTree createParameterWithIdentifier:@"outputLevel"
                                                                          name:@"Output Level"
                                                                       address:kOutputLevelAddress
                                                                           min:0.0
                                                                           max:2.0
                                                                          unit:kAudioUnitParameterUnit_Generic
                                                                      unitName:nil
                                                                         flags:kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable
                                                                  valueStrings:nil
                                                           dependentParameters:nil];
    outputLevel.value = 1.0;

    // Assemble tree
    NSMutableArray *allParams = [NSMutableArray arrayWithArray:effectParams];
    [allParams addObject:self.effectIndexParam];
    [allParams addObject:inputLevel];
    [allParams addObject:outputLevel];

    self.parameterTree = [AUParameterTree createTreeWithChildren:allParams];

    // Parameter value observer
    __weak __typeof(self) weakSelf = self;
    self.parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf setParameterValue:value forAddress:param.address];
    };

    self.parameterTree.implementorValueProvider = ^AUValue(AUParameter *param) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return 0;
        return [strongSelf getParameterValueForAddress:param.address];
    };

    self.parameterTree.implementorStringFromValueCallback = ^NSString * _Nonnull(AUParameter *param, const AUValue *value) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return @"";
        AUValue v = value ? *value : param.value;
        return [strongSelf stringFromValue:v forAddress:param.address];
    };
}

// MARK: - Parameter Handling

- (void)setParameterValue:(AUValue)value forAddress:(AUParameterAddress)address {
    if (address < kMaxEffectParams) {
        _paramValues[address] = value;
        // Also update the display processor for UI queries
        if (_displayProcessor) {
            _displayProcessor->setParameter((VstInt32)address, value);
        }
    } else if (address == kEffectIndexAddress) {
        NSInteger newIndex = (NSInteger)value;
        if (newIndex != _effectIndex.load()) {
            [self selectEffectAtIndex:newIndex];
        }
    } else if (address == kInputLevelAddress) {
        _inputLevel = value;
    } else if (address == kOutputLevelAddress) {
        _outputLevel = value;
    }
}

- (AUValue)getParameterValueForAddress:(AUParameterAddress)address {
    if (address < kMaxEffectParams) {
        return _paramValues[address];
    } else if (address == kEffectIndexAddress) {
        return (AUValue)_effectIndex.load();
    } else if (address == kInputLevelAddress) {
        return _inputLevel;
    } else if (address == kOutputLevelAddress) {
        return _outputLevel;
    }
    return 0;
}

- (NSString *)stringFromValue:(AUValue)value forAddress:(AUParameterAddress)address {
    if (address < kMaxEffectParams && _displayProcessor) {
        // Temporarily set the value to get the display string
        float oldVal = _displayProcessor->getParameter((VstInt32)address);
        _displayProcessor->setParameter((VstInt32)address, value);
        char text[256] = {0};
        _displayProcessor->getParameterDisplay((VstInt32)address, text);
        char label[256] = {0};
        _displayProcessor->getParameterLabel((VstInt32)address, label);
        _displayProcessor->setParameter((VstInt32)address, oldVal);

        NSString *display = [NSString stringWithUTF8String:text];
        NSString *labelStr = [NSString stringWithUTF8String:label];
        if (labelStr.length > 0) {
            return [NSString stringWithFormat:@"%@ %@", display, labelStr];
        }
        return display;
    } else if (address == kEffectIndexAddress) {
        NSInteger idx = (NSInteger)value;
        if (idx >= 0 && idx < (NSInteger)AirwinRegistry::registry.size()) {
            return [NSString stringWithUTF8String:AirwinRegistry::registry[idx].name.c_str()];
        }
    } else if (address == kInputLevelAddress || address == kOutputLevelAddress) {
        // Show as dB
        if (value <= 0.00001f) return @"-inf dB";
        float db = 20.0f * log10f(value);
        return [NSString stringWithFormat:@"%.1f dB", db];
    }
    return [NSString stringWithFormat:@"%.4f", value];
}

// MARK: - Effect Selection

- (void)selectEffectAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)AirwinRegistry::registry.size()) return;

    const auto &reg = AirwinRegistry::registry[index];

    // Create new processor for audio thread
    auto newProcessor = reg.generator();
    if (newProcessor) {
        newProcessor->setSampleRate((float)(_outputBus.format.sampleRate ?: 44100.0));

        // Read default parameter values
        for (int i = 0; i < MIN(reg.nParams, (int)kMaxEffectParams); i++) {
            _paramValues[i] = newProcessor->getParameter(i);
        }
        // Zero out unused slots
        for (int i = reg.nParams; i < kMaxEffectParams; i++) {
            _paramValues[i] = 0.0f;
        }
    }

    // Create display processor for UI parameter queries
    _displayProcessor = reg.generator();
    if (_displayProcessor) {
        _displayProcessor->setSampleRate((float)(_outputBus.format.sampleRate ?: 44100.0));
        for (int i = 0; i < MIN(reg.nParams, (int)kMaxEffectParams); i++) {
            _displayProcessor->setParameter(i, _paramValues[i]);
        }
    }

    _activeParamCount = MIN(reg.nParams, (int)kMaxEffectParams);

    // Per-instance short name tracks the active effect (Peter's request): when
    // a host shows several Airwindows instances side by side, the short name
    // lets the user tell them apart. `audioUnitShortName` has no setter, so we
    // override its getter (below) and post manual KVO here so an observing host
    // refreshes its label. Whether a given host picks the change up at runtime
    // or only reads the name at instantiation is host-dependent — we do our
    // part and let it update if it listens. This runs on the main thread (all
    // selectEffectAtIndex: callers are main-thread), where KVO is safe.
    [self willChangeValueForKey:@"audioUnitShortName"];
    _effectIndex = index;
    [self didChangeValueForKey:@"audioUnitShortName"];

    // Atomic swap for audio thread
    AirwinConsolidatedBase *raw = newProcessor.release();
    AirwinConsolidatedBase *old = _pendingProcessor.exchange(raw);
    // If there was a pending processor that the audio thread hasn't picked up yet, free it
    if (old) {
        delete old;
    }

    // Update parameter values in the tree
    for (int i = 0; i < kMaxEffectParams; i++) {
        self.effectParameters[i].value = _paramValues[i];
    }
    self.effectIndexParam.value = (AUValue)index;
}

- (NSInteger)currentEffectIndex {
    return _effectIndex.load();
}

- (NSString *)currentEffectName {
    NSInteger idx = _effectIndex.load();
    if (idx < 0 || idx >= (NSInteger)AirwinRegistry::registry.size()) return @"";
    return [NSString stringWithUTF8String:AirwinRegistry::registry[idx].name.c_str()];
}

// Override the inherited short name so it reflects the selected effect rather
// than the static component name. Returns the full effect name — hosts that
// only show ~6 characters truncate it themselves; returning the whole thing
// keeps it useful in hosts with more room. Falls back to the component default
// while no effect is selected. See the manual KVO in selectEffectAtIndex:.
- (NSString *)audioUnitShortName {
    NSInteger idx = _effectIndex.load();
    if (idx >= 0 && idx < (NSInteger)AirwinRegistry::registry.size()) {
        return [NSString stringWithUTF8String:AirwinRegistry::registry[idx].name.c_str()];
    }
    return [super audioUnitShortName];
}

// We post KVO for audioUnitShortName by hand (from selectEffectAtIndex:), so
// opt it out of automatic notification to avoid duplicate change events.
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"audioUnitShortName"]) {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

- (NSString *)currentEffectCategory {
    NSInteger idx = _effectIndex.load();
    if (idx < 0 || idx >= (NSInteger)AirwinRegistry::registry.size()) return @"";
    const auto &r = AirwinRegistry::registry[idx];
    NSString *name = [NSString stringWithUTF8String:r.name.c_str()];
    NSString *defaultCat = [NSString stringWithUTF8String:r.category.c_str()];
    return [AirwindowsEngine effectiveCategoryForEffectName:name
                                             defaultCategory:defaultCat];
}

- (NSInteger)currentParameterCount {
    return _activeParamCount.load();
}

- (NSString *)parameterNameAtIndex:(NSInteger)paramIndex {
    if (!_displayProcessor || paramIndex < 0 || paramIndex >= _activeParamCount.load()) return @"";
    char text[256] = {0};
    _displayProcessor->getParameterName((VstInt32)paramIndex, text);
    return [NSString stringWithUTF8String:text];
}

- (NSString *)parameterDisplayAtIndex:(NSInteger)paramIndex {
    if (!_displayProcessor || paramIndex < 0 || paramIndex >= _activeParamCount.load()) return @"";
    // Seed the display processor with the live value before reading. External
    // modulation (host LFOs in AUM, CV in miRack, any render-thread automation)
    // lands in _paramValues without ever passing through setParameterValue:,
    // so the display processor's own internal value goes stale. Reading it
    // blind would return last-edited text while the knob — driven by the
    // parameter observer's fresh value — has already moved. _paramValues is
    // the single source of truth every write path updates; the float read is a
    // pre-existing benign race with the render thread (same as setParameterValue:).
    _displayProcessor->setParameter((VstInt32)paramIndex, _paramValues[paramIndex]);
    char text[256] = {0};
    _displayProcessor->getParameterDisplay((VstInt32)paramIndex, text);
    return [NSString stringWithUTF8String:text];
}

- (NSString *)parameterLabelAtIndex:(NSInteger)paramIndex {
    if (!_displayProcessor || paramIndex < 0 || paramIndex >= _activeParamCount.load()) return @"";
    char text[256] = {0};
    _displayProcessor->getParameterLabel((VstInt32)paramIndex, text);
    return [NSString stringWithUTF8String:text];
}

- (NSInteger)parameterStepCountAtIndex:(NSInteger)paramIndex {
    if (!_displayProcessor || paramIndex < 0 || paramIndex >= _activeParamCount.load()) return 0;

    // 257 samples is fine-grained enough to catch up to ~32-step parameters
    // without false-positives from a continuous param that happens to round
    // to the same printed string at a few adjacent points.
    const int sampleCount = 257;
    const int maxSteps = 32;

    float oldVal = _displayProcessor->getParameter((VstInt32)paramIndex);

    NSMutableSet<NSString *> *unique = [NSMutableSet setWithCapacity:maxSteps + 1];
    char text[256] = {0};

    for (int i = 0; i < sampleCount; i++) {
        float v = (float)i / (float)(sampleCount - 1);
        _displayProcessor->setParameter((VstInt32)paramIndex, v);
        _displayProcessor->getParameterDisplay((VstInt32)paramIndex, text);
        [unique addObject:[NSString stringWithUTF8String:text]];
        if ((int)unique.count > maxSteps) {
            // Too many distinct strings — treat as continuous.
            _displayProcessor->setParameter((VstInt32)paramIndex, oldVal);
            return 0;
        }
    }

    _displayProcessor->setParameter((VstInt32)paramIndex, oldVal);

    NSInteger count = (NSInteger)unique.count;
    return (count >= 2 && count <= maxSteps) ? count : 0;
}

// MARK: - AUAudioUnit Overrides

- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) return NO;

    double sr = _outputBus.format.sampleRate;
    if (_activeProcessor) {
        _activeProcessor->setSampleRate((float)sr);
    }
    if (_displayProcessor) {
        _displayProcessor->setSampleRate((float)sr);
    }

    return YES;
}

- (void)deallocateRenderResources {
    [super deallocateRenderResources];
}

- (AUInternalRenderBlock)internalRenderBlock {
    // Capture ivars for the render block — avoid capturing self
    float *paramValues = _paramValues;
    std::atomic<int> *activeParamCount = &_activeParamCount;
    std::atomic<AirwinConsolidatedBase *> *pendingProcessor = &_pendingProcessor;
    std::atomic<AirwinConsolidatedBase *> *processorToFree = &_processorToFree;
    float *inputLevelPtr = &_inputLevel;
    float *outputLevelPtr = &_outputLevel;

    __block AirwinConsolidatedBase *processorPtr = _activeProcessor.get();

    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags,
                               const AudioTimeStamp *timestamp,
                               AVAudioFrameCount frameCount,
                               NSInteger outputBusNumber,
                               AudioBufferList *outputData,
                               const AURenderEvent *realtimeEventListHead,
                               AURenderPullInputBlock __unsafe_unretained pullInputBlock) {

        // Pull input audio
        AudioUnitRenderActionFlags pullFlags = 0;
        AUAudioUnitStatus err = pullInputBlock(&pullFlags, timestamp, frameCount, 0, outputData);
        if (err != noErr) return err;

        // Check for pending processor swap
        AirwinConsolidatedBase *newProc = pendingProcessor->exchange(nullptr, std::memory_order_acquire);
        if (newProc) {
            // Schedule old processor for deallocation on main thread
            AirwinConsolidatedBase *oldProc = processorPtr;
            processorPtr = newProc;
            if (oldProc) {
                AirwinConsolidatedBase *prevFree = processorToFree->exchange(oldProc, std::memory_order_release);
                if (prevFree) {
                    // Edge case: main thread hasn't freed the previous one yet.
                    // We can't free on audio thread, so just leak it (extremely rare).
                    // In practice, dispatch_async below ensures this doesn't happen.
                }
            }
            // Signal main thread to free old processor
            dispatch_async(dispatch_get_main_queue(), ^{
                AirwinConsolidatedBase *toFree = processorToFree->exchange(nullptr, std::memory_order_acquire);
                if (toFree) {
                    delete toFree;
                }
            });
        }

        if (!processorPtr) return noErr;

        // Walk the realtime event list and apply parameter changes.
        // Hosts send LFO/automation as AURenderEvents — without processing these,
        // host-side modulation (LFOs, envelopes, etc.) won't reach the AU.
        const AURenderEvent *event = realtimeEventListHead;
        while (event != NULL) {
            switch (event->head.eventType) {
                case AURenderEventParameter:
                case AURenderEventParameterRamp: {
                    const AUParameterEvent *paramEvent = &event->parameter;
                    AUParameterAddress addr = paramEvent->parameterAddress;
                    AUValue value = paramEvent->value;
                    if (addr < kMaxEffectParams) {
                        paramValues[addr] = value;
                    } else if (addr == kInputLevelAddress) {
                        *inputLevelPtr = value;
                    } else if (addr == kOutputLevelAddress) {
                        *outputLevelPtr = value;
                    }
                    // effectIndex changes are handled on the main thread, not here
                    break;
                }
                default:
                    break;
            }
            event = event->head.next;
        }

        // Get buffer pointers
        UInt32 numBuffers = outputData->mNumberBuffers;
        float *outL = (float *)outputData->mBuffers[0].mData;
        float *outR = (numBuffers > 1) ? (float *)outputData->mBuffers[1].mData : outL;

        // Apply input level
        float inGain = *inputLevelPtr;
        if (inGain != 1.0f) {
            for (AVAudioFrameCount i = 0; i < frameCount; i++) {
                outL[i] *= inGain;
                outR[i] *= inGain;
            }
        }

        // Apply current parameter values to processor
        int nParams = activeParamCount->load(std::memory_order_relaxed);
        for (int i = 0; i < nParams; i++) {
            processorPtr->setParameter(i, paramValues[i]);
        }

        // Process audio (in-place)
        float *inputs[2] = { outL, outR };
        float *outputs[2] = { outL, outR };
        processorPtr->processReplacing(inputs, outputs, (VstInt32)frameCount);

        // Apply output level
        float outGain = *outputLevelPtr;
        if (outGain != 1.0f) {
            for (AVAudioFrameCount i = 0; i < frameCount; i++) {
                outL[i] *= outGain;
                outR[i] *= outGain;
            }
        }

        return noErr;
    };
}

// MARK: - State

- (NSDictionary<NSString *, id> *)fullState {
    NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:[super fullState]];

    NSInteger idx = _effectIndex.load();
    if (idx >= 0 && idx < (NSInteger)AirwinRegistry::registry.size()) {
        state[@"effectName"] = [NSString stringWithUTF8String:AirwinRegistry::registry[idx].name.c_str()];
    }
    state[@"effectIndex"] = @(idx);

    NSMutableArray *params = [NSMutableArray arrayWithCapacity:kMaxEffectParams];
    for (int i = 0; i < kMaxEffectParams; i++) {
        [params addObject:@(_paramValues[i])];
    }
    state[@"parameterValues"] = params;
    state[@"inputLevel"] = @(_inputLevel);
    state[@"outputLevel"] = @(_outputLevel);

    return state;
}

- (NSDictionary<NSString *, id> *)fullStateForDocument {
    NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:[self fullState]];
    NSDictionary<NSString *, id> *documentState = [super fullStateForDocument];
    if (documentState) {
        [state addEntriesFromDictionary:documentState];
    }
    // documentState may overwrite our custom keys if super and we collide; we
    // don't expect that, but re-stamp the critical ones to be safe.
    NSInteger idx = _effectIndex.load();
    if (idx >= 0 && idx < (NSInteger)AirwinRegistry::registry.size()) {
        state[@"effectName"] = [NSString stringWithUTF8String:AirwinRegistry::registry[idx].name.c_str()];
    }
    state[@"effectIndex"] = @(idx);
    return state;
}

- (void)setFullState:(NSDictionary<NSString *, id> *)fullState {
    // Two delivery paths feed this method, with very different dictionaries:
    //
    //   1. AUM session restore — fullState contains BOTH our custom keys
    //      (effectName / effectIndex / parameterValues / inputLevel / etc.)
    //      AND super's standard data blob.
    //   2. Apple `.aupreset` restore (and AUM's "save preset") — the host
    //      strips non-standard keys when writing the preset to disk, so on
    //      load fullState contains ONLY super's keys. The saved param tree
    //      values still arrive (via the data blob) but our custom effectName
    //      key is gone.
    //
    // For path 2 to work we MUST call [super setFullState:] first so the
    // parameter tree is repopulated, then read `effectIndex` from the tree
    // and run the side effect ourselves. Apple's super does NOT fire the
    // implementorValueObserver during restore (it uses a private originator
    // that excludes implementer observers), so without this manual sync the
    // effect would never actually switch and the UI would show
    // "Pick an effect" — which is exactly what was happening.
    [super setFullState:fullState];
    [self applyRestoredStateFromDictionary:fullState];
}

// Applies our custom restore on top of whatever super just rewrote into the
// parameter tree. Split out of -setFullState: so the *ForDocument variant
// (used by Cubasis and other project-based hosts) can run the SAME side
// effects after calling ITS matching super — see -setFullStateForDocument:.
// The dictionary may carry our custom keys (path 1) or only super's blob
// (path 2); both are handled below.
- (void)applyRestoredStateFromDictionary:(NSDictionary<NSString *, id> *)fullState {
    // Step 1: figure out the target effect. Prefer custom keys (path 1);
    // otherwise read the parameter tree (path 2). Treat -1 / out-of-range
    // as "no effect" to preserve the unselected initial state.
    NSInteger targetIndex = -1;
    NSString *effectName = fullState[@"effectName"];
    if (effectName) {
        auto it = AirwinRegistry::nameToIndex.find([effectName UTF8String]);
        if (it != AirwinRegistry::nameToIndex.end()) {
            targetIndex = (NSInteger)it->second;
        }
    }
    if (targetIndex < 0) {
        NSNumber *idxNumber = fullState[@"effectIndex"];
        if (idxNumber) targetIndex = idxNumber.integerValue;
    }
    if (targetIndex < 0 && self.effectIndexParam) {
        AUValue v = self.effectIndexParam.value;
        if (v >= 0 && v < (AUValue)AirwinRegistry::registry.size()) {
            targetIndex = (NSInteger)v;
        }
    }
    // Step 2: snapshot the parameter values BEFORE selectEffectAtIndex runs.
    // selectEffectAtIndex reseeds _paramValues with the new effect's
    // defaults — fine for user-driven switches, wrong here. Prefer our
    // custom array, fall back to whatever super already wrote into the
    // parameter tree.
    float restoredParams[kMaxEffectParams];
    NSArray *paramsArray = fullState[@"parameterValues"];
    if ([paramsArray isKindOfClass:[NSArray class]] && paramsArray.count > 0) {
        for (int i = 0; i < kMaxEffectParams; i++) {
            restoredParams[i] = (i < (int)paramsArray.count)
                ? [paramsArray[i] floatValue]
                : 0.5f;
        }
    } else {
        for (int i = 0; i < kMaxEffectParams; i++) {
            AUParameter *p = self.effectParameters[i];
            restoredParams[i] = p ? p.value : 0.5f;
        }
    }

    // Step 3: switch effect if needed. selectEffectAtIndex updates
    // _effectIndex, _displayProcessor, the audio thread's pending
    // processor, and the parameter tree's effectIndex value (which fires
    // the SwiftUI observer so the browser/header refresh).
    if (targetIndex >= 0 && targetIndex != _effectIndex.load()) {
        [self selectEffectAtIndex:targetIndex];
    }

    // Step 4: apply the saved parameter values, overriding the defaults
    // selectEffectAtIndex just installed.
    for (int i = 0; i < kMaxEffectParams; i++) {
        _paramValues[i] = restoredParams[i];
        if (_displayProcessor) {
            _displayProcessor->setParameter(i, _paramValues[i]);
        }
        self.effectParameters[i].value = _paramValues[i];
    }

    // Step 5: levels. Custom key wins; otherwise read what super wrote.
    NSNumber *inLvl = fullState[@"inputLevel"];
    if (inLvl) {
        _inputLevel = inLvl.floatValue;
    } else if (self.parameterTree) {
        AUParameter *p = [self.parameterTree parameterWithAddress:kInputLevelAddress];
        if (p) _inputLevel = p.value;
    }
    NSNumber *outLvl = fullState[@"outputLevel"];
    if (outLvl) {
        _outputLevel = outLvl.floatValue;
    } else if (self.parameterTree) {
        AUParameter *p = [self.parameterTree parameterWithAddress:kOutputLevelAddress];
        if (p) _outputLevel = p.value;
    }

    // Tell the UI the AU's state changed underneath it. The host may have
    // restored this state AFTER the view model already configured and read a
    // stale (often "no effect") index, and Apple doesn't fire parameter
    // observers during restore — so without this nudge the parameter page can
    // stay blank even though the effect is correctly loaded (this was the exact
    // Cubasis symptom). Posted on the main thread because the observer touches
    // @Observable UI state.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:AirwindowsAudioUnitDidRestoreStateNotification
                          object:self];
    });
}

// Document-level state. Hosts split into two camps for project persistence:
// AUM and friends call -fullState / -setFullState:, while others — Cubasis
// most notably — persist a project through the *ForDocument variants. The
// getter -fullStateForDocument lives up near -fullState; here is the matching
// setter. Without this bridge, a Cubasis project reload comes back with no
// effect selected even though AUM restores fine.
- (void)setFullStateForDocument:(NSDictionary<NSString *, id> *)fullStateForDocument {
    // Call the MATCHING super (NOT -setFullState:) so super restores the
    // parameter tree from the *document*-format blob. Cubasis was observed to
    // preserve our custom keys here, but the param-tree blob (which carries the
    // effectIndex at address 37) is the canonical, host-agnostic record — so we
    // route through super's document variant and then run the same side effects
    // to switch the processor and apply the restored values. The UI sync after
    // restore is handled by the notification posted in
    // -applyRestoredStateFromDictionary:.
    [super setFullStateForDocument:fullStateForDocument];
    [self applyRestoredStateFromDictionary:fullStateForDocument];
}

- (BOOL)supportsUserPresets {
    return YES;
}

@end
