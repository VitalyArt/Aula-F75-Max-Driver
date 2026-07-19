package com.vitalyart.aulaf75maxdriver

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Movie
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import java.nio.ByteBuffer
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

object DisplayEncoder {
    fun encodeImage(context: Context, uri: Uri, fitMode: ScreenFitMode): EncodedDisplayStream {
        val bytes = context.contentResolver.openInputStream(uri)?.use { input ->
            input.readBytes()
        } ?: throw AulaError.ImageLoadFailed(uri.lastPathSegment ?: "selected file")

        val frames = decodeFrames(context, uri, bytes)
        val frameCount = min(frames.size, AulaConstants.maxFrames)
        val payloadLength = AulaConstants.headerLength + frameCount * AulaConstants.frameBytes
        val chunkCount = ceil(payloadLength.toDouble() / AulaConstants.chunkLength.toDouble()).toInt()
        val stream = ByteArray(chunkCount * AulaConstants.chunkLength)

        stream[0] = frameCount.toByte()
        for (index in 0 until frameCount) {
            stream[1 + index] = delayByte(frames[index].delayMillis)
        }

        for (frameIndex in 0 until frameCount) {
            val frame = frames[frameIndex]
            val rendered = renderFrame(frame.bitmap, fitMode)
            val offset = AulaConstants.headerLength + frameIndex * AulaConstants.frameBytes
            encodeRgb565(rendered, stream, offset)
            rendered.recycle()
        }

        return EncodedDisplayStream(stream, frameCount, chunkCount)
    }

    private fun decodeFrames(context: Context, uri: Uri, bytes: ByteArray): List<FrameData> {
        val mimeType = context.contentResolver.getType(uri).orEmpty().lowercase()
        val isGif = mimeType.contains("gif") || isGif(bytes)
        return if (isGif) {
            decodeGifFrames(bytes)
        } else {
            listOf(FrameData(decodeBitmap(bytes), 100))
        }
    }

    private fun decodeBitmap(bytes: ByteArray): Bitmap {
        val source = ImageDecoder.createSource(ByteBuffer.wrap(bytes))
        val bitmap = ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
            decoder.isMutableRequired = false
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
        return bitmap.copy(Bitmap.Config.ARGB_8888, false)
    }

    private fun decodeGifFrames(bytes: ByteArray): List<FrameData> {
        val movie = Movie.decodeByteArray(bytes, 0, bytes.size)
            ?: return listOf(FrameData(decodeBitmap(bytes), 100))

        val duration = max(movie.duration(), 100)
        val frameStep = 100
        val frameCount = min(AulaConstants.maxFrames, max(1, (duration + frameStep - 1) / frameStep))
        val width = max(movie.width(), 1)
        val height = max(movie.height(), 1)

        return (0 until frameCount).map { index ->
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            movie.setTime(index * frameStep)
            movie.draw(canvas, 0f, 0f)
            FrameData(bitmap, frameStep)
        }
    }

    private fun renderFrame(bitmap: Bitmap, fitMode: ScreenFitMode): Bitmap {
        val target = Bitmap.createBitmap(
            AulaConstants.displayWidth,
            AulaConstants.displayHeight,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(target)
        canvas.drawColor(android.graphics.Color.BLACK)

        val sourceRect = Rect(0, 0, bitmap.width, bitmap.height)
        val destRect: RectF = when (fitMode) {
            ScreenFitMode.STRETCH -> RectF(0f, 0f, AulaConstants.displayWidth.toFloat(), AulaConstants.displayHeight.toFloat())
            ScreenFitMode.CONTAIN, ScreenFitMode.COVER -> {
                val scaleX = AulaConstants.displayWidth.toFloat() / bitmap.width.toFloat()
                val scaleY = AulaConstants.displayHeight.toFloat() / bitmap.height.toFloat()
                val scale = if (fitMode == ScreenFitMode.CONTAIN) min(scaleX, scaleY) else max(scaleX, scaleY)
                val width = bitmap.width * scale
                val height = bitmap.height * scale
                val left = (AulaConstants.displayWidth - width) / 2.0f
                val top = (AulaConstants.displayHeight - height) / 2.0f
                RectF(left, top, left + width, top + height)
            }
        }

        val paint = Paint(Paint.FILTER_BITMAP_FLAG).apply {
            isFilterBitmap = true
        }
        canvas.drawBitmap(bitmap, sourceRect, destRect, paint)
        return target
    }

    private fun encodeRgb565(bitmap: Bitmap, stream: ByteArray, offset: Int) {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        for (index in pixels.indices) {
            val color = pixels[index]
            val red = (color shr 16) and 0xff
            val green = (color shr 8) and 0xff
            val blue = color and 0xff
            val pixel = ((red shr 3) shl 11) or ((green shr 2) shl 5) or (blue shr 3)
            stream[offset + index * 2] = (pixel and 0xff).toByte()
            stream[offset + index * 2 + 1] = ((pixel shr 8) and 0xff).toByte()
        }
    }

    private fun delayByte(delayMillis: Int): Byte {
        val normalized = if (delayMillis <= 0) 10 else delayMillis
        val value = ((normalized / 1000.0) * 500.0).toInt().coerceIn(1, 255)
        return value.toByte()
    }

    private fun isGif(bytes: ByteArray): Boolean {
        return bytes.size >= 6 &&
            bytes[0] == 'G'.code.toByte() &&
            bytes[1] == 'I'.code.toByte() &&
            bytes[2] == 'F'.code.toByte()
    }

    private data class FrameData(
        val bitmap: Bitmap,
        val delayMillis: Int
    )
}
