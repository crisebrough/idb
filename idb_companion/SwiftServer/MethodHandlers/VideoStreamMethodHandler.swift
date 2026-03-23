/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import CompanionLib
import FBSimulatorControl
import GRPC
import IDBCompanionUtilities
import IDBGRPCSwift
import OSLog

private let logger = Logger(subsystem: "com.facebook.idb", category: "VideoStream")

struct VideoStreamMethodHandler {

  let target: FBiOSTarget
  let targetLogger: FBControlCoreLogger
  let commandExecutor: FBIDBCommandExecutor

  func handle(requestStream: GRPCAsyncRequestStream<Idb_VideoStreamRequest>, responseStream: GRPCAsyncResponseStreamWriter<Idb_VideoStreamResponse>, context: GRPCAsyncServerCallContext) async throws {
    logger.info("Video stream request received")
    @Atomic var finished = false

    // Create a single iterator for the entire request stream lifecycle
    var requestIterator = requestStream.makeAsyncIterator()
    logger.debug("Request stream iterator created")

    // Read the first message using the iterator
    guard let firstRequest = try await requestIterator.next(),
          case let .start(start) = firstRequest.control
    else {
      logger.error("Failed to read first request from stream or invalid control")
      throw GRPCStatus(code: .failedPrecondition, message: "Expected start control as first message")
    }

    logger.info("Starting video stream with format: \(String(describing: start.format)), fps: \(start.fps)")

    let videoStream = try await startVideoStream(
      request: start,
      responseStream: responseStream,
      finished: _finished)

    // Use separate tasks for monitoring, but DON'T create new iterators
    let observeClientCancelStreaming = Task<Void, Error> {
      // Continue using the same iterator
      while let request = try await requestIterator.next() {
        switch request.control {
        case .start:
          throw GRPCStatus(code: .failedPrecondition, message: "Video streaming already started")
        case .stop:
          return
        case .none:
          throw GRPCStatus(code: .invalidArgument, message: "Client should not close request stream explicitly, send `stop` frame first")
        }
      }
      // Stream ended normally
      return
    }

    let observeVideoStreamStop = Task<Void, Error> {
      try await BridgeFuture.await(videoStream.completed)
    }

    try await Task.select(observeClientCancelStreaming, observeVideoStreamStop).value

    observeClientCancelStreaming.cancel()
    observeVideoStreamStop.cancel()
    _finished.set(true)

    try await BridgeFuture.await(videoStream.stopStreaming())
    targetLogger.log("The video stream is terminated")
  }

  private func startVideoStream(request start: Idb_VideoStreamRequest.Start, responseStream: GRPCAsyncResponseStreamWriter<Idb_VideoStreamResponse>, finished: Atomic<Bool>) async throws -> FBVideoStream {
    let consumer: FBDataConsumer

    if start.filePath.isEmpty {
      // BYPASSING FIFOStreamWriter for video streaming - it has a sequential bottleneck
      // Using direct async writes instead for parallel processing
      consumer = FBBlockDataConsumer.asynchronousDataConsumer { data in
        guard !finished.wrappedValue else { return }
        let response = Idb_VideoStreamResponse.with {
          $0.payload.data = data
        }

        // Fire and forget - create a new Task for each frame
        // This allows frames to be sent in parallel without blocking capture
        Task {
          do {
            try await responseStream.send(response)
          } catch {
            // Set finished flag to stop further processing
            finished.set(true)
          }
        }
      }
    } else {
      consumer = try FBFileWriter.syncWriter(forFilePath: start.filePath)
    }

    let framesPerSecond = start.fps > 0 ? NSNumber(value: start.fps) : nil
    let format = streamFormat(from: start.format)

    let rateControl: FBVideoStreamRateControl?
    if start.avgBitrate > 0 {
      rateControl = .bitrate(NSNumber(value: start.avgBitrate))
    } else if start.compressionQuality > 0 {
      rateControl = .quality(NSNumber(value: start.compressionQuality))
    } else {
      rateControl = nil
    }

    let config = FBVideoStreamConfiguration(
      format: format,
      framesPerSecond: framesPerSecond,
      rateControl: rateControl,
      scaleFactor: .init(value: start.scaleFactor),
      keyFrameRate: .init(value: start.keyFrameRate))

    let videoStream = try await BridgeFuture.value(target.createStream(with: config))

    try await BridgeFuture.await(videoStream.startStreaming(consumer))

    return videoStream
  }

  private func streamFormat(from requestFormat: Idb_VideoStreamRequest.Format) -> FBVideoStreamFormat {
    switch requestFormat {
    case .h264:
      return .compressedVideo(withCodec: .H264, transport: .annexB)
    case .rbga:
      return .bgra()
    case .mjpeg:
      return .mjpeg()
    case .minicap:
      return .minicap()
    case .i420, .UNRECOGNIZED:
      return .compressedVideo(withCodec: .H264, transport: .annexB)
    }
  }
}

