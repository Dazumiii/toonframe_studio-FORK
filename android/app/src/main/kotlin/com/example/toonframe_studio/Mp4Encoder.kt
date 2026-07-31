package com.example.toonframe_studio
// IMPORTANT: change the line above to match YOUR app's actual package
// name (the same one already at the top of your generated
// MainActivity.kt) - it must match, or Kotlin won't compile.

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

/**
 * Encodes a directory of numbered PNG frames (frame_0001.png,
 * frame_0002.png, ...) into an H.264 MP4 using the device's own
 * MediaCodec encoder and MediaMuxer - no ffmpeg, no third-party native
 * library. This is standard Android SDK API, available since API 18,
 * so there's no external dependency to go stale.
 *
 * Runs entirely synchronously - the caller (MainActivity) is
 * responsible for calling this off the main thread.
 */
class Mp4Encoder {

    private val timeoutUs = 10_000L
    private var muxerTrackIndex = -1
    private var muxerStarted = false

    fun encode(
        framesDir: String,
        frameCount: Int,
        fps: Int,
        width: Int,
        height: Int,
        outputPath: String
    ) {
        val mimeType = "video/avc" // H.264

        val codecInfo = selectEncoder(mimeType)
            ?: throw RuntimeException("No H.264 encoder available on this device")
        val colorFormat = selectColorFormat(codecInfo, mimeType)
            ?: throw RuntimeException(
                "This device's H.264 encoder doesn't support a YUV420 color format " +
                    "this app knows how to feed it (planar or semi-planar)."
            )

        // Rough bitrate heuristic - plenty for flat-color line art at
        // typical canvas resolutions; bump this up if output looks
        // blocky at higher resolutions.
        val bitRate = (width * height * fps * 0.1).toInt().coerceAtLeast(1_000_000)

        val format = MediaFormat.createVideoFormat(mimeType, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val codec = MediaCodec.createByCodecName(codecInfo.name)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val bufferInfo = MediaCodec.BufferInfo()
        val frameDurationUs = 1_000_000L / fps
        var presentationTimeUs = 0L
        muxerTrackIndex = -1
        muxerStarted = false

        try {
            for (i in 1..frameCount) {
                val fileName = "frame_" + i.toString().padStart(4, '0') + ".png"
                val file = File(framesDir, fileName)
                if (!file.exists()) continue

                val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: continue
                val yuv = bitmapToYuv(bitmap, colorFormat)
                bitmap.recycle()

                var inputIndex = -1
                while (inputIndex < 0) {
                    inputIndex = codec.dequeueInputBuffer(timeoutUs)
                }
                val inputBuffer = codec.getInputBuffer(inputIndex)!!
                inputBuffer.clear()
                inputBuffer.put(yuv)
                codec.queueInputBuffer(inputIndex, 0, yuv.size, presentationTimeUs, 0)
                presentationTimeUs += frameDurationUs

                drainEncoder(codec, muxer, bufferInfo, waitForEos = false)
            }

            // Signal end of stream and drain whatever's left.
            var eosInputIndex = -1
            while (eosInputIndex < 0) {
                eosInputIndex = codec.dequeueInputBuffer(timeoutUs)
            }
            codec.queueInputBuffer(eosInputIndex, 0, 0, presentationTimeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            drainEncoder(codec, muxer, bufferInfo, waitForEos = true)
        } finally {
            codec.stop()
            codec.release()
            if (muxerStarted) {
                muxer.stop()
            }
            muxer.release()
        }
    }

    /**
     * Pulls encoded output off [codec] and feeds it to [muxer].
     * With [waitForEos] = false, stops as soon as there's nothing more
     * available right now (called after queuing each input frame, so
     * we don't let the encoder's internal buffers back up). With
     * [waitForEos] = true, blocks until the end-of-stream buffer comes
     * through, for the final flush.
     */
    private fun drainEncoder(
        codec: MediaCodec,
        muxer: MediaMuxer,
        bufferInfo: MediaCodec.BufferInfo,
        waitForEos: Boolean
    ) {
        var done = false
        while (!done) {
            val outputIndex = codec.dequeueOutputBuffer(bufferInfo, if (waitForEos) timeoutUs else 0)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!waitForEos) done = true
                }
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (muxerStarted) throw RuntimeException("Encoder output format changed twice - unexpected")
                    muxerTrackIndex = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                outputIndex >= 0 -> {
                    val outputBuffer = codec.getOutputBuffer(outputIndex)!!
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }
                    if (bufferInfo.size > 0 && muxerStarted) {
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(muxerTrackIndex, outputBuffer, bufferInfo)
                    }
                    val isEos = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                    codec.releaseOutputBuffer(outputIndex, false)
                    if (isEos) done = true
                }
            }
        }
    }

    private fun selectEncoder(mimeType: String): MediaCodecInfo? {
        val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        for (info in list.codecInfos) {
            if (!info.isEncoder) continue
            if (info.supportedTypes.any { it.equals(mimeType, ignoreCase = true) }) {
                return info
            }
        }
        return null
    }

    private fun selectColorFormat(codecInfo: MediaCodecInfo, mimeType: String): Int? {
        val capabilities = codecInfo.getCapabilitiesForType(mimeType)
        // Prefer planar (I420); fall back to semi-planar (NV12), which
        // is what most Qualcomm/Samsung/MediaTek hardware encoders
        // actually advertise in practice.
        val preferred = intArrayOf(
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        )
        for (fmt in preferred) {
            if (capabilities.colorFormats.contains(fmt)) return fmt
        }
        return null
    }

    /**
     * Converts an ARGB [bitmap] into either I420 (planar) or NV12
     * (semi-planar) bytes, matching [colorFormat]. Standard BT.601
     * RGB->YUV coefficients (video range, 16-235/16-240).
     */
    private fun bitmapToYuv(bitmap: Bitmap, colorFormat: Int): ByteArray {
        val width = bitmap.width
        val height = bitmap.height
        val argb = IntArray(width * height)
        bitmap.getPixels(argb, 0, width, 0, 0, width, height)

        val frameSize = width * height
        val chromaSize = frameSize / 4
        val yuv = ByteArray(frameSize + chromaSize * 2)
        val isPlanar = colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar

        var yIndex = 0
        var uIndex = frameSize
        var vIndex = frameSize + chromaSize // only used when isPlanar

        var index = 0
        for (j in 0 until height) {
            for (i in 0 until width) {
                val pixel = argb[index]
                val r = (pixel shr 16) and 0xff
                val g = (pixel shr 8) and 0xff
                val b = pixel and 0xff

                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yuv[yIndex++] = y.coerceIn(0, 255).toByte()

                if (j % 2 == 0 && i % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    val uByte = u.coerceIn(0, 255).toByte()
                    val vByte = v.coerceIn(0, 255).toByte()

                    if (isPlanar) {
                        yuv[uIndex++] = uByte
                        yuv[vIndex++] = vByte
                    } else {
                        // NV12: interleaved U/V pairs after the Y plane.
                        val uvIndex = frameSize + ((j / 2) * width) + ((i / 2) * 2)
                        yuv[uvIndex] = uByte
                        yuv[uvIndex + 1] = vByte
                    }
                }
                index++
            }
        }
        return yuv
    }
}
