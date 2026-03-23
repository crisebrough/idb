/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import <FBControlCore/FBSubprocess.h>
#import <FBControlCore/FBFuture.h>

NS_ASSUME_NONNULL_BEGIN
@class IDBProcessInput;

@protocol FBDataConsumer;

@protocol FBDapServerCommand <NSObject, FBiOSTargetCommand>

<<<<<<< HEAD
- (FBFuture<IDBProcess<id, id<FBDataConsumer>, NSString *> *> *) launchDapServer:dapPath stdIn:(IDBProcessInput *)stdIn stdOut:(id<FBDataConsumer>)stdOut;
=======
- (FBFuture<FBSubprocess<id, id<FBDataConsumer>, NSString *> *> *) launchDapServer:dapPath stdIn:(FBProcessInput *)stdIn stdOut:(id<FBDataConsumer>)stdOut;
>>>>>>> upstream/main

@end

NS_ASSUME_NONNULL_END
