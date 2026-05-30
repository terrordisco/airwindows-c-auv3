//
//  AirwindowsBridge.h
//  AirwindowsDSP framework
//
//  Public ObjC interface for the metadata layer (effect listing, category
//  overrides, blog/video links) AND the host-shell preview engine.
//  The AUv3 audio path uses AirwindowsAudioUnit, not this class.
//
//  Architecture notes — including the override-JSON layer — live at the
//  top of AirwindowsBridge.mm.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AirwindowsEffectInfo : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *category;
@property (nonatomic, readonly) NSString *whatText;
@property (nonatomic, readonly) NSInteger nParams;
@property (nonatomic, readonly) BOOL isMono;
@property (nonatomic, readonly) NSInteger registryIndex;
@property (nonatomic, readonly) NSInteger catChrisOrdering;
@property (nonatomic, readonly) NSString *firstCommitDate;
@property (nonatomic, readonly) NSArray<NSString *> *collections;
@property (nonatomic, readonly, nullable) NSString *postURL;
@property (nonatomic, readonly, nullable) NSString *videoURL;
@end

@interface AirwindowsEngine : NSObject

+ (void)initializeRegistry;
+ (NSArray<AirwindowsEffectInfo *> *)allEffects;
+ (NSArray<NSString *> *)allCategories;
+ (NSArray<NSString *> *)effectNamesInCategory:(NSString *)category;
+ (NSInteger)effectCount;
+ (nullable AirwindowsEffectInfo *)effectInfoAtIndex:(NSInteger)index;
+ (NSInteger)indexForEffectName:(NSString *)name;

/// Returns the effective category for an effect — applies the
/// category_overrides.json override if one exists, otherwise returns the
/// supplied registry default. Exposed so the AU subclass can mirror the
/// browser's view of categories without duplicating the lookup logic.
+ (NSString *)effectiveCategoryForEffectName:(NSString *)name
                              defaultCategory:(NSString *)defaultCategory;

- (instancetype)init;

- (void)selectEffectAtIndex:(NSInteger)index;
- (NSInteger)currentEffectIndex;
- (NSString *)currentEffectName;
- (NSString *)currentEffectCategory;
- (NSInteger)currentParameterCount;

- (NSString *)parameterNameAtIndex:(NSInteger)paramIndex;
- (NSString *)parameterLabelAtIndex:(NSInteger)paramIndex;
- (NSString *)parameterDisplayAtIndex:(NSInteger)paramIndex;
- (float)parameterValueAtIndex:(NSInteger)paramIndex;
- (void)setParameterValue:(float)value atIndex:(NSInteger)paramIndex;

- (void)setSampleRate:(double)sampleRate;

- (void)processFloatInputL:(const float *)inL
                    inputR:(const float *)inR
                   outputL:(float *)outL
                   outputR:(float *)outR
                    frames:(int)frames;

@end

NS_ASSUME_NONNULL_END
