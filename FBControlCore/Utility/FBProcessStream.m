/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBProcessStream.h"

#import <sys/types.h>
#import <sys/stat.h>

#import "FBControlCoreError.h"
#import "FBDataBuffer.h"
#import "FBFileReader.h"
#import "FBFileWriter.h"
#import "FBSubprocess.h"
#import "FBProcessBuilder.h"
#import "FBFuture+Sync.h"

static NSTimeInterval ProcessDetachDrainTimeout = 4;

#pragma mark IDBProcessStreamAttachment

@implementation IDBProcessStreamAttachment

- (instancetype)initWithFileDescriptor:(int)fileDescriptor closeOnEndOfFile:(BOOL)closeOnEndOfFile mode:(IDBProcessStreamAttachmentMode)mode
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileDescriptor = fileDescriptor;
  _closeOnEndOfFile = closeOnEndOfFile;
  _mode = mode;

  return self;
}

- (void)close
{
  if (self.fileDescriptor) {
    close(self.fileDescriptor);
  }
}
@end

#pragma mark IDBProcessFileOutput

@interface IDBProcessFileOutput_DirectToFile : NSObject <IDBProcessFileOutput>

@end

@interface IDBProcessFileOutput_Consumer : NSObject <IDBProcessFileOutput>

@property (nonatomic, strong, readonly) id<FBDataConsumer> consumer;
<<<<<<< HEAD
@property (nonatomic, strong, nullable, readwrite) IDBProcess<NSNull *, id<FBDataConsumer>, NSNull *> *task;
=======
@property (nonatomic, strong, nullable, readwrite) FBSubprocess<NSNull *, id<FBDataConsumer>, NSNull *> *task;
>>>>>>> upstream/main
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

@end

@interface IDBProcessFileOutput_Reader : NSObject <IDBProcessFileOutput>

@property (nonatomic, strong, readonly) IDBProcessOutput *output;
@property (nonatomic, strong, nullable, readwrite) id<FBDataConsumer> writer;
@property (nonatomic, strong, nullable, readwrite) id<IDBProcessFileOutput> nested;
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

@end

@implementation IDBProcessFileOutput_DirectToFile

@synthesize filePath = _filePath;

#pragma mark Initializers

- (instancetype)initWithFilePath:(NSString *)filePath
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _filePath = filePath;

  return self;
}

#pragma mark IDBProcessFileOutput

- (FBFuture<NSNull *> *)startReading
{
  return [[FBFuture
    futureWithResult:NSNull.null]
    nameFormat:@"Start reading %@", self.description];
}

- (FBFuture<NSNull *> *)stopReading
{
  return [[FBFuture
    futureWithResult:NSNull.null]
    nameFormat:@"Stop reading %@", self.description];
}

#pragma mark NSObject

- (NSString *)description
{
  return [NSString stringWithFormat:@"File output to %@", self.filePath];
}

@end

@implementation IDBProcessFileOutput_Consumer

@synthesize filePath = _filePath;

#pragma mark Initializers

- (instancetype)initWithConsumer:(id<FBDataConsumer>)consumer filePath:(NSString *)filePath queue:(dispatch_queue_t)queue
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _consumer = consumer;
  _filePath = filePath;
  _queue = queue;

  return self;
}

#pragma mark IDBProcessFileOutput

- (FBFuture<NSNull *> *)startReading
{
  return [[FBFuture
<<<<<<< HEAD
    onQueue:self.queue resolve:^ FBFuture<IDBProcess<NSNull *, id<FBDataConsumer>, NSNull *> *> *{
=======
    onQueue:self.queue resolve:^ FBFuture<FBSubprocess<NSNull *, id<FBDataConsumer>, NSNull *> *> *{
>>>>>>> upstream/main
      if (self.task) {
        return [[FBControlCoreError
          describeFormat:@"Cannot start reading, already reading"]
          failFuture];
      }
      return [[[[IDBProcessBuilder
        withLaunchPath:@"/bin/cat" arguments:@[self.filePath]]
        withStdOutConsumer:self.consumer]
        withStdErrToDevNull]
        start];
    }]
<<<<<<< HEAD
    onQueue:self.queue map:^(IDBProcess<NSNull *, id<FBDataConsumer>, NSNull *> *task) {
=======
    onQueue:self.queue map:^(FBSubprocess<NSNull *, id<FBDataConsumer>, NSNull *> *task) {
>>>>>>> upstream/main
      self.task = task;
      return NSNull.null;
    }];
}

- (FBFuture<NSNull *> *)stopReading
{
  return [[FBFuture
    onQueue:self.queue resolve:^ FBFuture<NSNumber *> *{
<<<<<<< HEAD
      IDBProcess<NSNull *, id<FBDataConsumer>, NSNull *> *task = self.task;
=======
      FBSubprocess<NSNull *, id<FBDataConsumer>, NSNull *> *task = self.task;
>>>>>>> upstream/main
      self.task = nil;
      if (!task) {
        return [[FBControlCoreError
          describeFormat:@"Cannot stop reading, not reading"]
          failFuture];
      }
      return [task sendSignal:SIGTERM];
    }]
    mapReplace:NSNull.null];
}

#pragma mark NSObject

- (NSString *)description
{
  return [NSString stringWithFormat:@"Consumer output to %@", self.filePath];
}

@end

@implementation IDBProcessFileOutput_Reader

@synthesize filePath = _filePath;

#pragma mark Initializers

- (instancetype)initWithOutput:(IDBProcessOutput *)output filePath:(NSString *)filePath queue:(dispatch_queue_t)queue
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _output = output;
  _filePath = filePath;
  _queue = queue;

  return self;
}

#pragma mark IDBProcessFileOutput

- (FBFuture<NSNull *> *)startReading
{
  return [[[[[FBFuture
    onQueue:self.queue resolve:^ FBFuture<IDBProcessStreamAttachment *> * {
      if (self.writer || self.nested) {
        return [[FBControlCoreError
          describe:@"Cannot call startReading twice"]
          failFuture];
      }
      return [self.output attach];
    }]
    onQueue:self.queue map:^ id<FBDataConsumer>  (IDBProcessStreamAttachment *attachment) {
      return [FBFileWriter syncWriterWithFileDescriptor:attachment.fileDescriptor closeOnEndOfFile:attachment.closeOnEndOfFile];
    }]
    onQueue:self.queue fmap:^ FBFuture<id<IDBProcessFileOutput>> * (id<FBDataConsumer> writer) {
      self.writer = writer;
      id<IDBProcessFileOutput> consumer = [[IDBProcessFileOutput_Consumer alloc] initWithConsumer:writer filePath:self.filePath queue:self.queue];
      return [[consumer startReading] mapReplace:consumer];
    }]
    onQueue:self.queue map:^ NSNull * (id<IDBProcessFileOutput> nested) {
      self.nested = nested;
      return NSNull.null;
    }]
    nameFormat:@"Start Reading %@", self.description];
}

- (FBFuture<NSNull *> *)stopReading
{
  return [[[FBFuture
    onQueue:self.queue resolve:^ FBFuture<NSNull *> * {
      if (!self.writer || !self.nested) {
        return [[FBControlCoreError
          describeFormat:@"No active reader for fifo"]
          failFuture];
      }
      return [self.nested stopReading];
    }]
    onQueue:self.queue map:^(id _) {
      self.nested = nil;
      return NSNull.null;
    }]
    nameFormat:@"Stop Reading %@", self.description];
}

#pragma mark NSObject

- (NSString *)description
{
  return [NSString stringWithFormat:@"Output of %@ to file handle", self.filePath];
}

@end

#pragma mark - IDBProcessOutput

@interface IDBProcessOutput ()

@property (nonatomic, strong, readonly) dispatch_queue_t workQueue;

@end

@interface IDBProcessOutput_Null : IDBProcessOutput

@end

@interface IDBProcessOutput_FilePath : IDBProcessOutput

@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readwrite) int fileDescriptor;

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

@interface IDBProcessOutput_Pipe : IDBProcessOutput

@property (nonatomic, assign, readwrite) int readEnd;
@property (nonatomic, assign, readwrite) int writeEnd;

@end

@class NSInputStream_IDBProcessOutput;

@interface IDBProcessOutput_InputStream : IDBProcessOutput_Pipe

@property (nonatomic, strong, readonly) FBMutableFuture<NSNumber *> *readFuture;
@property (nonatomic, strong, readonly) NSInputStream_IDBProcessOutput *stream;

@end

@interface NSInputStream_IDBProcessOutput : NSInputStream

@property (nonatomic, strong, readonly) FBFuture<NSNumber *> *readFuture;
@property (nonatomic, assign, readwrite) int fileDescriptor;

- (instancetype)initWithReadFuture:(FBFuture<NSNumber *> *)readFuture;

@end

@interface IDBProcessOutput_Consumer : IDBProcessOutput_Pipe

@property (nonatomic, strong, readwrite) id<FBDataConsumer> consumer;
@property (nonatomic, strong, nullable, readwrite) FBFileReader *reader;
@property (nonatomic, strong, nullable, readwrite) id<FBControlCoreLogger> logger;

- (instancetype)initWithConsumer:(id<FBDataConsumer>)consumer logger:(nullable id<FBControlCoreLogger>)logger;

@end

@interface IDBProcessOutput_Logger : IDBProcessOutput_Consumer

- (instancetype)initWithLogger:(id<FBControlCoreLogger>)logger;

@end

@interface IDBProcessOutput_Data : IDBProcessOutput_Consumer

@property (nonatomic, strong, readonly) id<FBAccumulatingBuffer> dataConsumer;

- (instancetype)initWithMutableData:(NSMutableData *)mutableData;

@end

@interface IDBProcessOutput_String : IDBProcessOutput_Data

@end

@implementation IDBProcessOutput

#pragma mark Initializers

+ (dispatch_queue_t)createWorkQueue
{
  return dispatch_queue_create("com.facebook.fbcontrolcore.process_stream", DISPATCH_QUEUE_SERIAL);
}

+ (IDBProcessOutput<NSNull *> *)outputForNullDevice
{
  return [[IDBProcessOutput_Null alloc] init];
}

+ (IDBProcessOutput<NSString *> *)outputForFilePath:(NSString *)filePath
{
  return [[IDBProcessOutput_FilePath alloc] initWithFilePath:filePath];
}

+ (IDBProcessOutput<NSInputStream *> *)outputToInputStream
{
  return [[IDBProcessOutput_InputStream alloc] init];
}

+ (IDBProcessOutput<id<FBDataConsumer>> *)outputForDataConsumer:(id<FBDataConsumer>)dataConsumer logger:(id<FBControlCoreLogger>)logger
{
  return [[IDBProcessOutput_Consumer alloc] initWithConsumer:dataConsumer logger:logger];
}

+ (IDBProcessOutput<id<FBDataConsumer>> *)outputForDataConsumer:(id<FBDataConsumer>)dataConsumer
{
  return [[IDBProcessOutput_Consumer alloc] initWithConsumer:dataConsumer logger:nil];
}

+ (IDBProcessOutput<id<FBControlCoreLogger>> *)outputForLogger:(id<FBControlCoreLogger>)logger
{
  return [[IDBProcessOutput_Logger alloc] initWithLogger:logger];
}

+ (IDBProcessOutput<NSMutableData *> *)outputToMutableData:(NSMutableData *)data
{
  return [[IDBProcessOutput_Data alloc] initWithMutableData:data];
}

+ (IDBProcessOutput<NSString *> *)outputToStringBackedByMutableData:(NSMutableData *)data
{
  return [[IDBProcessOutput_String alloc] initWithMutableData:data];
}

- (instancetype)init
{
  return [self initWithWorkQueue:IDBProcessOutput.createWorkQueue];
}

- (instancetype)initWithWorkQueue:(dispatch_queue_t)workQueue
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _workQueue = workQueue;

  return self;
}

#pragma mark FBStandardStream

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

- (FBFuture<NSNull *> *)detach
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

- (id)contents
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

#pragma mark IDBProcessOutput implementation

- (FBFuture<id<IDBProcessFileOutput>> *)providedThroughFile
{
  return [[self
    makeFifoOutput]
    onQueue:self.workQueue map:^(NSString *fifoPath) {
      return [[IDBProcessFileOutput_Reader alloc] initWithOutput:self filePath:fifoPath queue:IDBProcessOutput.createWorkQueue];
    }];
}

- (FBFuture<id<FBDataConsumer>> *)providedThroughConsumer
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

#pragma mark Private

- (FBFuture<NSString *> *)makeFifoOutput
{
  NSString *fifoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  if (mkfifo(fifoPath.UTF8String, S_IWUSR | S_IRUSR) != 0) {
    return [[[FBControlCoreError
      describeFormat:@"Failed to create a named pipe for fifo %@ with error '%s'", fifoPath, strerror(errno)]
      inDomain:NSPOSIXErrorDomain]
      failFuture];
  }
  return [FBFuture futureWithResult:fifoPath];
}

@end

@implementation IDBProcessOutput_Null

#pragma mark FBStandardStream

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [FBFuture futureWithResult:[[IDBProcessStreamAttachment alloc] initWithFileDescriptor:-1 closeOnEndOfFile:NO mode:IDBProcessStreamAttachmentModeOutput]];
}

- (FBFuture<NSNull *> *)detach
{
  return FBFuture.empty;
}

- (NSNull *)contents
{
  return NSNull.null;
}

#pragma mark IDBProcessOutput Implementation

- (FBFuture<id<IDBProcessFileOutput>> *)providedThroughFile
{
  return [FBFuture futureWithResult:[[IDBProcessFileOutput_DirectToFile alloc] initWithFilePath:@"/dev/null"]];
}

- (FBFuture<id<FBDataConsumer>> *)providedThroughConsumer
{
  return [FBFuture futureWithResult:FBNullDataConsumer.new];
}

#pragma mark NSObject

- (NSString *)description
{
  return @"Null Output";
}

@end

@implementation IDBProcessOutput_Pipe

#pragma mark FBStandardStream

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [FBFuture
    onQueue:self.workQueue resolve:^{
      if (self.readEnd != 0 || self.writeEnd != 0) {
        return [[FBControlCoreError
          describeFormat:@"Cannot attach when already attached to %d:%d", self.readEnd, self.writeEnd]
          failFuture];
      }

      int fileDescriptors[2] = {0, 0};
      if (pipe(fileDescriptors) != 0) {
        return [[FBControlCoreError
          describeFormat:@"Failed to create a pipe: %s", strerror(errno)]
          failFuture];
      }
      self.readEnd = fileDescriptors[0];
      self.writeEnd = fileDescriptors[1];
      // Pass out the write end in the attachment, for the caller to write to.
      return [FBFuture futureWithResult:[[IDBProcessStreamAttachment alloc] initWithFileDescriptor:fileDescriptors[1] closeOnEndOfFile:YES mode:IDBProcessStreamAttachmentModeOutput]];
    }];
}

- (FBFuture<NSNull *> *)detach
{
  return [[self
    closeWriteEndOfPipe]
    nameFormat:@"Detach %@", self];
}

#pragma mark Private

- (FBFuture<NSNull *> *)closeWriteEndOfPipe
{
  return [[FBFuture
    onQueue:self.workQueue resolve:^ FBFuture<NSNull *> * {
      if (!self.writeEnd) {
        return [[FBControlCoreError
          describe:@"Cannot detach when not attached"]
          failFuture];
      }

      // Close the write end, but leave the read end open.
      // This is needed as there may be read operations pending on the file descriptor.
      // Any readers are themselves responsible for closing when they've read to the end of the file.
      close(self.writeEnd);
      self.writeEnd = 0;
      self.readEnd = 0;

      return FBFuture.empty;
    }]
    nameFormat:@"Detach %@", self.description];
}

@end

@implementation IDBProcessOutput_InputStream

- (instancetype)init
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _readFuture = FBMutableFuture.future;
  _stream = [[NSInputStream_IDBProcessOutput alloc] initWithReadFuture:_readFuture];

  return self;
}

#pragma mark FBStandardStream

- (NSInputStream *)contents
{
  return self.stream;
}

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [[super
    attach]
    onQueue:self.workQueue map:^(IDBProcessStreamAttachment *result) {
      [self.readFuture resolveWithResult:@(self.readEnd)];
      return result;
    }];
}

- (FBFuture<NSNull *> *)detach
{
  return [[self
    closeWriteEndOfPipe]
    nameFormat:@"Detach %@", self];
}

@end

@implementation NSInputStream_IDBProcessOutput

- (instancetype)initWithReadFuture:(FBFuture<NSNumber *> *)readFuture
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileDescriptor = 0;
  _readFuture = readFuture;

  return self;
}

#pragma mark NSInputStream

- (void)open
{
  NSNumber *fileDescriptor = [self.readFuture block:nil];
  self.fileDescriptor = fileDescriptor.intValue;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
  int fileDescriptor = self.fileDescriptor;
  if (fileDescriptor == 0) {
    return -1;
  }
  NSInteger readBytes = read(fileDescriptor, buffer, len);
  if (readBytes < 1) {
    [self close];
  }
  return readBytes;
}

- (void)close
{
  if (self.fileDescriptor) {
    close(self.fileDescriptor);
    self.fileDescriptor = 0;
  }
}

@end

@implementation IDBProcessOutput_Consumer

#pragma mark Initializers

- (instancetype)initWithConsumer:(id<FBDataConsumer>)consumer logger:(nullable id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _consumer = consumer;
  _logger = logger;

  return self;
}

#pragma mark FBStandardStream

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [[super
    attach]
    onQueue:self.workQueue fmap:^(IDBProcessStreamAttachment *attachment) {
      if (self.reader) {
        return [[FBControlCoreError
          describeFormat:@"Cannot attach to %@ twice", self]
          failFuture];
      }

      // FBFileReader consumes the read end, the write end is passed out in the attachment.
      // The super's attach creates the pipe and the detach closes the write end.
      id<FBDataConsumer> consumer = self.consumer;
      id<FBControlCoreLogger> logger = self.logger;
      if (logger) {
        consumer = [FBCompositeDataConsumer consumerWithConsumers:@[
          consumer,
          [FBLoggingDataConsumer consumerWithLogger:logger],
        ]];
      }

      // IDBProcessOuput consumes the read end, the write end is passed out in the attachment.
      self.reader = [FBFileReader readerWithFileDescriptor:self.readEnd closeOnEndOfFile:YES consumer:consumer logger:self.logger];
      return [[[self.reader
        startReading]
        mapReplace:attachment]
        nameFormat:@"Attach to pipe %@", self.description];
    }];
}

- (FBFuture<NSNull *> *)detach
{
  return [[[[super
    detach]
    onQueue:self.workQueue fmap:^ FBFuture<NSNumber *> * (id _){
      FBFileReader *reader = self.reader;
      if (!reader) {
        return [[FBControlCoreError
          describeFormat:@"Cannot detach from %@, no active reader", self]
          failFuture];
      }
      // Since detach may be called before the reader has finished reading asynchronously,
      // we should attempt to wait for this to happen naturally and then use the backoff API.
      return [reader finishedReadingWithTimeout:ProcessDetachDrainTimeout];
    }]
    onQueue:self.workQueue chain:^(FBFuture *future) {
      self.reader = nil;
      return future;
    }]
    nameFormat:@"Detach %@", self.description];
}

- (id<FBDataConsumer>)contents
{
  return self.consumer;
}

#pragma mark IDBProcessOutput Implementation

- (FBFuture<id<IDBProcessFileOutput>> *)providedThroughFile
{
  return [[[self
    makeFifoOutput]
    onQueue:self.workQueue map:^ id<IDBProcessFileOutput> (NSString *fifoPath) {
      return [[IDBProcessFileOutput_Consumer alloc] initWithConsumer:self.consumer filePath:fifoPath queue:IDBProcessOutput.createWorkQueue];
    }]
    nameFormat:@"Relay %@ to file", self.description];
}

- (FBFuture<id<FBDataConsumer>> *)providedThroughConsumer
{
  return [FBFuture futureWithResult:self.consumer];
}

#pragma mark NSObject

- (NSString *)description
{
  return @"Output to consumer";
}

@end

@implementation IDBProcessOutput_Logger

#pragma mark Initializers

- (instancetype)initWithLogger:(id<FBControlCoreLogger>)logger
{
  id<FBDataConsumer> consumer = [FBLoggingDataConsumer consumerWithLogger:logger];
  self = [super initWithConsumer:consumer logger:logger];
  if (!self) {
    return nil;
  }

  return self;
}

#pragma mark FBStandardStream

- (id<FBControlCoreLogger>)contents
{
  return self.logger;
}

#pragma mark NSObject

- (NSString *)description
{
  return @"Output to logger";
}

@end

@implementation IDBProcessOutput_FilePath

#pragma mark Initializers

- (instancetype)initWithFilePath:(NSString *)filePath
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _filePath = filePath;

  return self;
}

#pragma mark FBStandardStream

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [[FBFuture
    onQueue:self.workQueue resolve:^{
      int fileDescriptor = self.fileDescriptor;
      if (fileDescriptor) {
        return [[FBControlCoreError
          describeFormat:@"Cannot attach when already attached to file %@: %d", self.filePath, fileDescriptor]
          failFuture];
      }

      fileDescriptor = open(self.filePath.UTF8String, O_WRONLY | O_CREAT);
      if (!fileDescriptor) {
        return [[FBControlCoreError
          describeFormat:@"Cannot create file descriptor for %@: %s", self.filePath, strerror(errno)]
          failFuture];
      }
      self.fileDescriptor = fileDescriptor;
      return [FBFuture futureWithResult:[[IDBProcessStreamAttachment alloc] initWithFileDescriptor:fileDescriptor closeOnEndOfFile:YES mode:IDBProcessStreamAttachmentModeOutput]];
    }]
    nameFormat:@"Attach to %@", self.description];
}

- (FBFuture<NSNull *> *)detach
{
  return [[FBFuture
    onQueue:self.workQueue resolve:^ FBFuture<NSNull *> * {
      int fileDescriptor = self.fileDescriptor;
      if (fileDescriptor == 0) {
        return [[FBControlCoreError
          describe:@"Cannot Detach Twice"]
          failFuture];
      }
      close(fileDescriptor);
      self.fileDescriptor = 0;
      return FBFuture.empty;
    }]
    nameFormat:@"Detach from %@", self.description];
}

- (NSString *)contents
{
  return self.filePath;
}

#pragma mark IDBProcessOutput Implementation

- (FBFuture<id<IDBProcessFileOutput>> *)providedThroughFile
{
  return [FBFuture futureWithResult:[[IDBProcessFileOutput_DirectToFile alloc] initWithFilePath:self.filePath]];
}

- (FBFuture<id<FBDataConsumer>> *)providedThroughConsumer
{
  return (FBFuture<id<FBDataConsumer>> *) [FBFileWriter asyncWriterForFilePath:self.filePath];
}

#pragma mark NSObject

- (NSString *)description
{
  return [NSString stringWithFormat:@"Output to %@", self.filePath];
}

@end

@implementation IDBProcessOutput_Data

#pragma mark Initializers

- (instancetype)initWithMutableData:(NSMutableData *)mutableData
{
  id<FBAccumulatingBuffer> consumer = [FBDataBuffer accumulatingBufferForMutableData:mutableData];
  self = [super initWithConsumer:consumer logger:nil];
  if (!self) {
    return nil;
  }

  _dataConsumer = consumer;

  return self;
}

#pragma mark FBStandardStream

- (NSData *)contents
{
  return self.dataConsumer.data;
}

#pragma mark NSObject

- (NSString *)description
{
  return @"Output to Mutable Data";
}

@end

@implementation IDBProcessOutput_String

#pragma mark FBStandardStream

- (NSString *)contents
{
  NSData *data = self.dataConsumer.data;
  // Strip newline from the end of the buffer.
  if (data.length) {
    char lastByte = 0;
    NSRange range = NSMakeRange(data.length - 1, 1);
    [data getBytes:&lastByte range:range];
    if (lastByte == '\n') {
      data = [data subdataWithRange:NSMakeRange(0, data.length - 1)];
    }
  }
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

#pragma mark NSObject

- (NSString *)description
{
  return @"Output to Mutable String";
}

@end

@interface IDBProcessInput ()

@property (nonatomic, strong, readonly) dispatch_queue_t workQueue;
@property (nonatomic, assign, readwrite) int readEnd;
@property (nonatomic, assign, readwrite) int writeEnd;

@end

@interface IDBProcessInput_Consumer : IDBProcessInput <FBDataConsumer>

@property (nonatomic, strong, nullable, readwrite) id<FBDataConsumer> writer;

@end

@interface IDBProcessInput_Data : IDBProcessInput_Consumer

- (instancetype)initWithData:(NSData *)data;

@property (nonatomic, strong, readonly) NSData *data;

@end

@class NSOutputStream_IDBProcessInput;

@interface IDBProcessInput_InputStream : IDBProcessInput <FBStandardStreamTransfer>

@property (nonatomic, strong, readonly) NSOutputStream_IDBProcessInput *stream;
@property (nonatomic, strong, readonly) FBMutableFuture<NSNumber *> *writeFuture;

@end

@interface NSOutputStream_IDBProcessInput : NSOutputStream

@property (nonatomic, strong, readonly) FBFuture<NSNumber *> *writeFuture;
@property (nonatomic, assign, readwrite) int fileDescriptor;
@property (atomic, assign, readwrite) ssize_t bytesWritten;
@property (atomic, copy, nullable, readwrite) NSString *errorMessage;
@property (atomic, assign, readwrite) NSStreamStatus status;

- (instancetype)initWithWriteFuture:(FBFuture<NSNumber *> *)writeFuture;

@end

@implementation IDBProcessInput

#pragma mark Initializers

+ (IDBProcessInput<id<FBDataConsumer>> *)inputFromConsumer
{
  return [[IDBProcessInput_Consumer alloc] init];
}

+ (IDBProcessInput<NSOutputStream *> *)inputFromStream
{
  return [[IDBProcessInput_InputStream alloc] init];
}

+ (IDBProcessInput<NSData *> *)inputFromData:(NSData *)data
{
  return [[IDBProcessInput_Data alloc] initWithData:data];
}

- (instancetype)init
{
  return [self initWithWorkQueue:IDBProcessOutput.createWorkQueue];
}

- (instancetype)initWithWorkQueue:(dispatch_queue_t)workQueue
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _workQueue = workQueue;

  return self;
}

#pragma mark FBStandardStream

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [[FBFuture
    onQueue:self.workQueue resolve:^{
      if (self.readEnd || self.writeEnd) {
        return [[FBControlCoreError
          describeFormat:@"Cannot Attach Twice"]
          failFuture];
      }

      int fileDescriptors[2] = {0, 0};
      if (pipe(fileDescriptors) != 0) {
        return [[FBControlCoreError
          describeFormat:@"Failed to create a pipe: %s", strerror(errno)]
          failFuture];
      }
      self.readEnd = fileDescriptors[0];
      self.writeEnd = fileDescriptors[1];

      // Pass out the read end as input to a process.
      // Subclases will write to the write end.
      return [FBFuture futureWithResult:[[IDBProcessStreamAttachment alloc] initWithFileDescriptor:self.readEnd closeOnEndOfFile:YES mode:IDBProcessStreamAttachmentModeInput]];
    }]
    nameFormat:@"Attach %@ to pipe", self.description];
}

- (FBFuture<NSNull *> *)detach
{
  return [[FBFuture
    onQueue:self.workQueue resolve:^ FBFuture<NSNull *> * {
      int readEnd = self.readEnd;
      if (!readEnd) {
        return [[FBControlCoreError
          describeFormat:@"Nothing is attached to %@", self]
          failFuture];
      }

      // Close the read end of the descriptor since the input it no-longer consuming it
      // The writer is responsible for closing and referencing the write end.
      close(readEnd);
      self.readEnd = 0;
      self.writeEnd = 0;

      return FBFuture.empty;
    }]
    nameFormat:@"Detach %@", self.description];
}

- (id<FBDataConsumer>)contents
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

- (NSError *)streamError
{
  return nil;
}

@end

@implementation IDBProcessInput_Consumer

#pragma mark FBStandardStream

- (id<FBDataConsumer>)contents
{
  return self;
}

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [[[super
    attach]
    onQueue:self.workQueue fmap:^(IDBProcessStreamAttachment *attachment) {
      NSError *error = nil;
      // Construct a writer to write to, on eof the file descriptor is closed and the reading continues on the other side of the pipe.
      // The read end is closed in the superclassess detach.
      id<FBDataConsumer> writer = [FBFileWriter asyncWriterWithFileDescriptor:self.writeEnd closeOnEndOfFile:YES error:&error];
      if (!writer) {
        return [[FBControlCoreError
          describeFormat:@"Failed to create a writer for pipe %@", error]
          failFuture];
      }
      self.writer = writer;
      return [FBFuture futureWithResult:attachment];
    }]
    nameFormat:@"Attach %@ to pipe", self.description];
}

- (FBFuture<NSNull *> *)detach
{
  return [[[super
    detach]
    onQueue:self.workQueue notifyOfCompletion:^(id _) {
      self.writer = nil;
    }]
    nameFormat:@"Detach %@", self.description];
}

#pragma mark FBDataConsumer

- (void)consumeData:(NSData *)data
{
  [self.writer consumeData:data];
}

- (void)consumeEndOfFile
{
  [self.writer consumeEndOfFile];
}

#pragma mark NSObject

- (NSString *)description
{
  return @"Input to consumer";
}

@end

@implementation IDBProcessInput_Data

#pragma mark Initializers

- (instancetype)initWithData:(NSData *)data
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _data = data;

  return self;
}

#pragma mark FBStandardStream

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [[[super
    attach]
    onQueue:self.workQueue map:^(IDBProcessStreamAttachment *attachment) {
      [self.writer consumeData:self.data];
      [self.writer consumeEndOfFile];
      return attachment;
    }]
    nameFormat:@"Attach %@ to pipe", self.description];
}

- (NSData *)contents
{
  return self.data;
}

#pragma mark NSObject

- (NSString *)description
{
  return @"Input to Data";
}

@end

@implementation IDBProcessInput_InputStream

#pragma mark Initializers

- (instancetype)init
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _writeFuture = FBMutableFuture.future;
  _stream = [[NSOutputStream_IDBProcessInput alloc] initWithWriteFuture:_writeFuture];

  return self;
}

#pragma mark FBStandardStream

- (NSOutputStream *)contents
{
  return self.stream;
}

- (FBFuture<IDBProcessStreamAttachment *> *)attach
{
  return [[super
    attach]
    onQueue:self.workQueue map:^(IDBProcessStreamAttachment *attachment) {
      [self.writeFuture resolveWithResult:@(self.writeEnd)];
      return attachment;
    }];
}


- (NSString *)description
{
  return @"Input to NSOutputStream";
}

#pragma mark FBStandardStreamTransfer

- (ssize_t)bytesTransferred
{
  return self.stream.bytesWritten;
}

- (NSError *)streamError
{
  return self.stream.streamError;
}

@end

@implementation NSOutputStream_IDBProcessInput

#pragma mark Initializers

- (instancetype)initWithWriteFuture:(FBFuture<NSNumber *> *)writeFuture
{
  self = [super init];
  if (!self) {
    return nil;
  }

  // The pipe first has to be created, so we don't know this ahead of time.
  // Instead we block until the write descriptor becomes available.
  _writeFuture = writeFuture;
  _fileDescriptor = 0;
  _bytesWritten = 0;
  _errorMessage = nil;
  _status = NSStreamStatusNotOpen;

  return self;
}

#pragma mark NSOutputStream

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len
{
  int fileDescriptor = self.fileDescriptor;
  if (!fileDescriptor) {
    NSStreamStatus status = self.status;
    if (status == NSStreamStatusNotOpen) {
      [self resolveError:@"Pipe for writing is not open"];
    } else if (status == NSStreamStatusClosed) {
      [self resolveError:@"Pipe for writing is closed"];
    } else {
      [self resolveError:@"Pipe for writing is does not exist"];
    }
    return -1;
  }
  self.status = NSStreamStatusWriting;
  ssize_t result = write(self.fileDescriptor, buffer, len);
  self.status = NSStreamStatusOpen;
  if (result == -1) {
    [self resolveError:[[NSString alloc] initWithCString:strerror(errno) encoding:NSASCIIStringEncoding]];
    return -1;
  }
  self.bytesWritten += result;
  return result;
}

- (void)open
{
  if (self.streamStatus != NSStreamStatusNotOpen) {
    [self resolveError:[NSString stringWithFormat:@"Stream status is not NSStreamStatusNotOpen is %lu", self.streamStatus]];
    return;
  }
  self.status = NSStreamStatusOpening;
  NSNumber *fileDescriptor = [self.writeFuture block:nil];
  self.fileDescriptor = fileDescriptor.intValue;
  self.status = NSStreamStatusOpen;
}

- (void)close
{
  if (self.fileDescriptor) {
    close(self.fileDescriptor);
    self.fileDescriptor = 0;
    self.status = NSStreamStatusClosed;
  }
}

- (BOOL)hasSpaceAvailable
{
  return YES;
}

- (NSError *)streamError
{
  NSString *errorMessage = self.errorMessage;
  if (!errorMessage) {
    return nil;
  }
  return [[FBControlCoreError
    describe:errorMessage]
    build];
}

- (NSStreamStatus)streamStatus
{
  return self.status;
}

#pragma mark Private

- (void)resolveError:(NSString *)errorMessage
{
  if (self.errorMessage) {
    return;
  }
  self.errorMessage = errorMessage;
  self.status = NSStreamStatusError;
}

@end
