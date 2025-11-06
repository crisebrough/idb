/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

public protocol AsyncStreamWriter {
  associatedtype Value: Sendable

  func send(_ value: Value) async throws
}

/// Wraps any async stream writer and bridges it to synchronous world
/// preserving FIFO order of elements.
public final class FIFOStreamWriter<StreamWriter: AsyncStreamWriter>: @unchecked Sendable {

  private let stream: StreamWriter

  // Single processing task to handle all writes sequentially
  private let processingTask: Task<Void, Never>

  // Channel for sending values to the processing task
  private let channel: AsyncChannel<StreamWriter.Value>

  // Track if we've been shut down
  private var isShutdown = false
  private let shutdownLock = NSLock()

  public init(stream: StreamWriter) {
    self.stream = stream
    let channel = AsyncChannel<StreamWriter.Value>()
    self.channel = channel

    // Start single long-running task to process all writes
    // Capture the stream iterator directly to avoid multiple iterator creation
    let capturedStream = stream
      var iterator = channel.makeIterator()
    self.processingTask = Task {
      while !Task.isCancelled {
        if let value = await iterator.next() {
          do {
            try await capturedStream.send(value)
          } catch {
            // Log error but continue processing
            // In production, you might want better error handling
            print("FIFOStreamWriter: Error sending value: \(error)")
          }
        } else {
          break // Stream finished
        }
      }
    }
  }

  deinit {
    // Ensure cleanup happens
    shutdown()
  }

  /// This method should be called from GCD
  /// Never ever call that from swift concurrency cooperative pool thread, because it is unsafe
  /// and you will violate swift concurrency contract. Doing that may cause deadlock of whole concurrency runtime.
  public func send(_ value: StreamWriter.Value) throws {
    shutdownLock.lock()
    defer { shutdownLock.unlock() }

    guard !isShutdown else {
      throw FIFOStreamWriterError.streamShutdown
    }

    // Direct synchronous yield - safe from GCD thread
    channel.yieldSynchronously(value)
  }

  public func shutdown() {
    shutdownLock.lock()
    defer { shutdownLock.unlock() }

    guard !isShutdown else { return }
    isShutdown = true

    channel.finish()
    processingTask.cancel()
  }
}

enum FIFOStreamWriterError: Error {
  case streamShutdown
}

/// A simple async channel for passing values between tasks
private final class AsyncChannel<Element: Sendable>: @unchecked Sendable {
  private let stream: AsyncStream<Element>
  private let continuation: AsyncStream<Element>.Continuation
  private var _iterator: AsyncStream<Element>.AsyncIterator?
  private let iteratorLock = NSLock()

  init() {
    (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
  }

  func send(_ value: Element) async {
    continuation.yield(value)
  }

  func finish() {
    continuation.finish()
  }

  /// Synchronously yield a value to the stream
  /// This is safe to call from any thread, including GCD threads
  func yieldSynchronously(_ value: Element) {
    continuation.yield(value)
  }

  /// Get the single iterator for this channel
  /// Only call this once - multiple iterators are not supported
  func makeIterator() -> AsyncStream<Element>.AsyncIterator {
    iteratorLock.lock()
    defer { iteratorLock.unlock() }

    if let iterator = _iterator {
      return iterator
    }

    let iterator = stream.makeAsyncIterator()
    _iterator = iterator
    return iterator
  }
}
