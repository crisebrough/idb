/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBProcessBuilder.h"

#import <FBControlCore/FBControlCore.h>

#import "FBDataBuffer.h"
#import "FBDataConsumer.h"
#import "FBProcessIO.h"
#import "FBProcessStream.h"
#import "FBSubprocess.h"
#import "FBProcessSpawnConfiguration.h"

@interface IDBProcessBuilder ()

@property (nonatomic, copy, readwrite) NSString *launchPath;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *arguments;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *environment;
@property (nonatomic, strong, nullable, readwrite) IDBProcessOutput *stdOut;
@property (nonatomic, strong, nullable, readwrite) IDBProcessOutput *stdErr;
@property (nonatomic, strong, nullable, readwrite) IDBProcessInput *stdIn;
@property (nonatomic, strong, nullable, readwrite) id<FBControlCoreLogger> logger;

@end

@implementation IDBProcessBuilder

#pragma mark Initializers

- (instancetype)initWithLaunchPath:(NSString *)launchPath
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _launchPath = launchPath;
  _arguments = @[];
  _environment = IDBProcessBuilder.defaultEnvironmentForSubprocess;
  _stdOut = [IDBProcessOutput outputToStringBackedByMutableData:NSMutableData.data];
  _stdErr = [IDBProcessOutput outputToStringBackedByMutableData:NSMutableData.data];
  _stdIn = nil;
  _logger = nil;

  return self;
}

+ (instancetype)withLaunchPath:(NSString *)launchPath
{
  NSParameterAssert(launchPath);
  return [[self alloc] initWithLaunchPath:launchPath];
}

+ (instancetype)withLaunchPath:(NSString *)launchPath arguments:(NSArray<NSString *> *)arguments
{
  NSParameterAssert(launchPath);
  NSParameterAssert(arguments);
  return [[self withLaunchPath:launchPath] withArguments:arguments];
}

#pragma mark Spawn Configuration

- (instancetype)withLaunchPath:(NSString *)launchPath
{
  NSParameterAssert(launchPath);
  self.launchPath = launchPath;
  return self;
}

- (instancetype)withArguments:(NSArray<NSString *> *)arguments
{
  NSParameterAssert(arguments);
  self.arguments = arguments;
  return self;
}

- (instancetype)withEnvironment:(NSDictionary<NSString *, NSString *> *)environment
{
  NSParameterAssert(environment);
  self.environment = environment;
  return self;
}

- (instancetype)withEnvironmentAdditions:(NSDictionary<NSString *, NSString *> *)environment
{
  NSParameterAssert(environment);
  NSMutableDictionary<NSString *, NSString *> *dictionary = [self.environment mutableCopy];
  [dictionary addEntriesFromDictionary:environment];
  return [self withEnvironment:[dictionary copy]];
}

#pragma mark stdin

- (instancetype)withStdIn:(IDBProcessInput *)input
{
  self.stdIn = input;
  return self;
}

- (instancetype)withStdInConnected
{
  self.stdIn = [IDBProcessInput inputFromConsumer];
  return self;
}

- (instancetype)withStdInFromData:(NSData *)data
{
  self.stdIn = [IDBProcessInput inputFromData:data];
  return self;
}

#pragma mark stdout

- (instancetype)withStdOutInMemoryAsData
{
  self.stdOut = [IDBProcessOutput outputToMutableData:NSMutableData.data];
  return self;
}

- (instancetype)withStdOutInMemoryAsString
{
  self.stdOut = [IDBProcessOutput outputToStringBackedByMutableData:NSMutableData.data];
  return self;
}

- (instancetype)withStdOutPath:(NSString *)stdOutPath
{
  NSParameterAssert(stdOutPath);
  self.stdOut = [IDBProcessOutput outputForFilePath:stdOutPath];
  return self;
}

- (instancetype)withStdOutToDevNull
{
  self.stdOut = nil;
  return self;
}

- (instancetype)withStdOutToInputStream
{
  self.stdOut = [IDBProcessOutput outputToInputStream];
  return self;
}

- (instancetype)withStdOutConsumer:(id<FBDataConsumer>)consumer
{
  self.stdOut = [IDBProcessOutput outputForDataConsumer:consumer];
  return self;
}

- (instancetype)withStdOutLineReader:(void (^)(NSString *))reader
{
  return [self withStdOutConsumer:[FBBlockDataConsumer asynchronousLineConsumerWithBlock:reader]];
}

- (instancetype)withStdOutToLogger:(id<FBControlCoreLogger>)logger
{
  self.stdOut = [IDBProcessOutput outputForLogger:logger];
  return self;
}

- (instancetype)withStdOutToLoggerAndErrorMessage:(id<FBControlCoreLogger>)logger
{
  self.stdOut = [IDBProcessOutput outputForDataConsumer:[FBDataBuffer accumulatingBufferWithCapacity:IDBProcessOutputErrorMessageLength] logger:logger];
  return self;
}

#pragma mark stderr

- (instancetype)withStdErrInMemoryAsData
{
  self.stdErr = [IDBProcessOutput outputToMutableData:NSMutableData.data];
  return self;
}

- (instancetype)withStdErrInMemoryAsString
{
  self.stdErr = [IDBProcessOutput outputToStringBackedByMutableData:NSMutableData.data];
  return self;
}

- (instancetype)withStdErrPath:(NSString *)stdErrPath
{
  NSParameterAssert(stdErrPath);
  self.stdErr = [IDBProcessOutput outputForFilePath:stdErrPath];
  return self;
}

- (instancetype)withStdErrToDevNull
{
  self.stdErr = nil;
  return self;
}

- (instancetype)withStdErrConsumer:(id<FBDataConsumer>)consumer
{
  self.stdErr = [IDBProcessOutput outputForDataConsumer:consumer];
  return self;
}

- (instancetype)withStdErrLineReader:(void (^)(NSString *))reader
{
  return [self withStdErrConsumer:[FBBlockDataConsumer asynchronousLineConsumerWithBlock:reader]];
}

- (instancetype)withStdErrToLogger:(id<FBControlCoreLogger>)logger
{
  self.stdErr = [IDBProcessOutput outputForLogger:logger];
  return self;
}

- (instancetype)withStdErrToLoggerAndErrorMessage:(id<FBControlCoreLogger>)logger
{
  self.stdErr = [IDBProcessOutput outputForDataConsumer:[FBDataBuffer accumulatingBufferWithCapacity:IDBProcessOutputErrorMessageLength] logger:logger];
  return self;
}

#pragma mark Loggers

- (instancetype)withTaskLifecycleLoggingTo:(id<FBControlCoreLogger>)logger;
{
  self.logger = logger;
  return self;
}

#pragma mark Building

<<<<<<< HEAD
- (FBFuture<IDBProcess *> *)start
{
  return [IDBProcess launchProcessWithConfiguration:self.buildConfiguration logger:self.logger];
}

- (FBFuture<IDBProcess *> *)runUntilCompletionWithAcceptableExitCodes:(NSSet<NSNumber *> *)exitCodes
=======
- (FBFuture<FBSubprocess *> *)start
{
  return [FBSubprocess launchProcessWithConfiguration:self.buildConfiguration logger:self.logger];
}

- (FBFuture<FBSubprocess *> *)runUntilCompletionWithAcceptableExitCodes:(NSSet<NSNumber *> *)exitCodes
>>>>>>> upstream/main
{
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
  return [[self
    start]
<<<<<<< HEAD
    onQueue:queue fmap:^(IDBProcess *process) {
=======
    onQueue:queue fmap:^(FBSubprocess *process) {
>>>>>>> upstream/main
      return [[process exitedWithCodes:exitCodes] mapReplace:process];
    }];
}

#pragma mark Private

- (FBProcessSpawnConfiguration *)buildConfiguration
{
  return [[FBProcessSpawnConfiguration alloc]
    initWithLaunchPath:self.launchPath
    arguments:self.arguments
    environment:self.environment
    io:[[FBProcessIO alloc] initWithStdIn:self.stdIn stdOut:self.stdOut stdErr:self.stdErr]
    mode:FBProcessSpawnModeDefault];
}

+ (NSDictionary<NSString *, NSString *> *)defaultEnvironmentForSubprocess
{
  static dispatch_once_t onceToken;
  static NSDictionary<NSString *, NSString *> *environment = nil;
  dispatch_once(&onceToken, ^{
    NSArray<NSString *> *applicableVariables = @[@"DEVELOPER_DIR", @"HOME", @"PATH"];
    NSDictionary<NSString *, NSString *> *parentEnvironment = NSProcessInfo.processInfo.environment;
    NSMutableDictionary<NSString *, NSString *> *taskEnvironment = [NSMutableDictionary dictionary];

    for (NSString *key in applicableVariables) {
      if (parentEnvironment[key]) {
        taskEnvironment[key] = parentEnvironment[key];
      }
    }
    environment = [taskEnvironment copy];
  });
  return environment;
}

@end
