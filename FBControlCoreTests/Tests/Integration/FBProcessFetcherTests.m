/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <FBControlCore/FBControlCore.h>

@interface IDBProcessFetcherTests : XCTestCase
  @property(nonatomic, retain)NSTask *task;
@end

@implementation IDBProcessFetcherTests
- (void)setUp {
  NSTask* task = [[NSTask alloc] init];
  task.launchPath = @"/bin/sleep";
  task.arguments = @[@"10"];
  self.task = task;
  [self.task launch];
}

- (void)tearDown {
  if (self.task.running) {
    [self.task terminate];
    [self.task waitUntilExit];
  }
  
  self.task = nil;
}

- (void)testIsProcessRunningRunningProcess
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;

  BOOL output = [fetcher isProcessRunning:self.task.processIdentifier error:&error];
  
  XCTAssertNil(error);
  XCTAssertTrue(output);
}

- (void)testIsProcessRunningDeadProcess
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;
  
  [self.task terminate];
  [self.task waitUntilExit];
  BOOL output = [fetcher isProcessRunning:self.task.processIdentifier error:&error];
  
  XCTAssertNotNil(error);
  XCTAssertFalse(output);
}

- (void)testIsProcessRunningSuspendedProcess
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;
  
  [self.task suspend];
  BOOL output = [fetcher isProcessRunning:self.task.processIdentifier error:&error];
  
  XCTAssertNil(error);
  XCTAssertFalse(output);
}


- (void)testIsProcessStoppedRunningProcess
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;

  BOOL output = [fetcher isProcessStopped:self.task.processIdentifier error:&error];
  
  XCTAssertNil(error);
  XCTAssertFalse(output);
}

- (void)testIsProcessStoppedDeadProcess
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;
  
  [self.task terminate];
  [self.task waitUntilExit];
  BOOL output = [fetcher isProcessStopped:self.task.processIdentifier error:&error];
  
  XCTAssertNotNil(error);
  XCTAssertFalse(output);
}

- (void)testIsProcessStoppedSuspendedProcess
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;
  
  [self.task suspend];
  BOOL output = [fetcher isProcessStopped:self.task.processIdentifier error:&error];
  
  XCTAssertNil(error);
  XCTAssertTrue(output);
}

- (void)testIsDebuggerAttachedToDeadProcess
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;
  
  [self.task terminate];
  [self.task waitUntilExit];
  BOOL output = [fetcher isDebuggerAttachedTo:self.task.processIdentifier error:&error];
  
  XCTAssertNotNil(error);
  XCTAssertFalse(output);
}

- (void)testIsDebuggerAttachedToProcessNoDebugger
{
  IDBProcessFetcher *fetcher = [[IDBProcessFetcher alloc] init];
  NSError *error;
  
  BOOL output = [fetcher isDebuggerAttachedTo:self.task.processIdentifier error:&error];
  
  XCTAssertNil(error);
  XCTAssertFalse(output);
}

@end
