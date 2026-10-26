package com.vitalyart.aulaf75maxdriver

import android.graphics.Bitmap
import android.graphics.Canvas as NativeCanvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.LinearGradient
import android.graphics.RadialGradient
import android.graphics.Shader
import android.provider.Settings
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import kotlinx.coroutines.delay
import kotlin.math.*

private fun PreviewRGB.argb() = android.graphics.Color.rgb((r*255).toInt(),(g*255).toInt(),(b*255).toInt())
private fun grey(v: Float) = android.graphics.Color.rgb((v*255).toInt(),(v*255).toInt(),(v*255).toInt())

@Composable
fun StagePanel(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(
        Brush.radialGradient(listOf(Color(0xff292929),Color(0xff0d0d0d)),radius=900f)
    ).padding(12.dp), verticalArrangement=Arrangement.spacedBy(12.dp),content=content)
}

/** Cache the expensive cap legends and gradients independently of the RGB frames. */
private class KeyboardArtwork(val width: Int, val height: Int) {
    val unit = width / 17.1f
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    fun rect(x: Float,y: Float,w: Float,h: Float) = RectF((x+0.55f)*unit,(y+0.5f)*unit,(x+w+0.55f)*unit,(y+h+0.5f)*unit)
    val caps = Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888).also { bitmap ->
        val c=NativeCanvas(bitmap)
        KeyboardLayout.keys.forEach { key ->
            val r=rect(key.x,key.y,key.width,1f).apply { inset(unit*0.075f,unit*0.075f) }
            val lift=if(key.row==3)0.08f else 0f
            fun fill(top: Int,bottom: Int,box: RectF,radius: Float) {
                paint.shader=LinearGradient(0f,box.top,0f,box.bottom,top,bottom,Shader.TileMode.CLAMP)
                c.drawRoundRect(box,radius,radius,paint);paint.shader=null
            }
            fill(if(key.light)KeycapPalette.skirtTop.toArgb() else grey(0.13f+lift),if(key.light)KeycapPalette.skirtBottom.toArgb() else grey(0.07f+lift),r,unit*0.13f)
            val face=RectF(r.left+unit*0.09f,r.top+unit*0.05f,r.right-unit*0.09f,r.bottom-unit*0.15f)
            fill(if(key.light)KeycapPalette.faceTop.toArgb() else grey(0.24f+lift),if(key.light)KeycapPalette.faceBottom.toArgb() else grey(0.17f+lift),face,unit*0.1f)
            if(unit>=14f) {paint.color=grey(if(key.light)0.25f else 0.68f);paint.textSize=unit*0.2f
                c.drawText(key.label,face.left+unit*0.08f,face.bottom-unit*0.06f,paint)}
        }
        val knob=rect(15.13f,0.08f,0.84f,0.84f)
        paint.shader=RadialGradient(knob.centerX()-unit*0.12f,knob.centerY()-unit*0.12f,unit*0.6f,intArrayOf(grey(0.42f),grey(0.12f)),null,Shader.TileMode.CLAMP)
        c.drawOval(knob,paint);paint.shader=null
        paint.color=grey(0.09f);paint.strokeWidth=max(0.5f,unit*0.015f)
        for(i in 0..35) {val a=i*2*PI/36
            c.drawLine(knob.centerX()+cos(a).toFloat()*unit*0.35f,knob.centerY()+sin(a).toFloat()*unit*0.35f,
                knob.centerX()+cos(a).toFloat()*unit*0.405f,knob.centerY()+sin(a).toFloat()*unit*0.405f,paint)}
    }
    // A soft white mask, tinted per key; no live blur during animation.
    val glows = KeyboardLayout.keys.map { it.width }.distinct().associateWith { w ->
        val u=48f;val bitmap=Bitmap.createBitmap(((w+0.9f)*u).toInt(),(1.9f*u).toInt(),Bitmap.Config.ARGB_8888)
        val p=Paint(Paint.ANTI_ALIAS_FLAG).apply {color=android.graphics.Color.WHITE;maskFilter=android.graphics.BlurMaskFilter(0.22f*u,android.graphics.BlurMaskFilter.Blur.NORMAL)}
        NativeCanvas(bitmap).drawRoundRect(RectF(0.45f*u,0.45f*u,(w+0.45f)*u,1.45f*u),u*0.18f,u*0.18f,p)
        bitmap
    }
}

@Composable
fun KeyboardStage(settings: LightingSettings, screen: Bitmap? = null, modifier: Modifier = Modifier) {
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val context=LocalContext.current
    val view=LocalView.current
    var visible by remember { mutableStateOf(false) }
    var time by remember { mutableDoubleStateOf(1.7) }
    var animationScale by remember { mutableFloatStateOf(1f) }
    DisposableEffect(context, lifecycle) {
        fun updateScale() { animationScale = Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) }
        val observer = object : android.database.ContentObserver(android.os.Handler(android.os.Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) = updateScale()
        }
        updateScale()
        context.contentResolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)
        onDispose { context.contentResolver.unregisterContentObserver(observer) }
    }
    LaunchedEffect(lifecycle,visible,animationScale,settings.mode) {
        if(lifecycle.isAtLeast(Lifecycle.State.RESUMED)&&visible&&animationScale>0&&settings.mode !in listOf(0,1,6)) {
            val start=System.nanoTime()
            while(true) {time=1.7+(System.nanoTime()-start)/1e9;delay(50)}
        }
    }
    var dimensions by remember { mutableStateOf(0 to 0) }
    val artwork=remember(dimensions) { if(dimensions.first>0&&dimensions.second>0) KeyboardArtwork(dimensions.first,dimensions.second) else null }
    DisposableEffect(artwork) {onDispose {artwork?.caps?.recycle();artwork?.glows?.values?.forEach {it.recycle()}}}
    val description=stringResource(R.string.keyboard_preview)
    Canvas(modifier.fillMaxWidth().aspectRatio(17.1f/7.4f).semantics {contentDescription=description}
        .onGloballyPositioned { coordinates ->
            dimensions=coordinates.size.width to coordinates.size.height
            visible=coordinates.boundsInWindow().overlaps(Rect(0f,0f,view.width.toFloat(),view.height.toFloat()))
        }) {
        val a=artwork ?: return@Canvas
        val c=drawContext.canvas.nativeCanvas;val p=a.paint;val u=a.unit
        p.shader=LinearGradient(0f,0f,0f,size.height,grey(0.16f),grey(0.07f),Shader.TileMode.CLAMP)
        c.drawRoundRect(RectF(0f,0f,size.width,size.height),u*0.45f,u*0.45f,p);p.shader=null
        p.color=grey(0.035f);c.drawRoundRect(RectF(u*0.22f,u*0.22f,size.width-u*0.22f,size.height-u*0.22f),u*0.28f,u*0.28f,p)
        KeyboardLayout.keys.forEach {key ->
            val color=LightingEffectRenderer.color(settings,(key.x+key.width/2)/16.0,(key.y+0.5)/6.4,time).argb()
            p.colorFilter=android.graphics.PorterDuffColorFilter(color,android.graphics.PorterDuff.Mode.SRC_IN)
            val r=a.rect(key.x-0.45f,key.y-0.45f,key.width+0.9f,1.9f)
            c.drawBitmap(a.glows.getValue(key.width),null,r,p)
        }
        p.colorFilter=null;c.drawBitmap(a.caps,0f,0f,p)
        KeyboardLayout.keys.forEach {key ->
            p.color=LightingEffectRenderer.color(settings,(key.x+key.width/2)/16.0,(key.y+0.5)/6.4,time).argb()
            p.alpha=115;p.style=Paint.Style.STROKE;p.strokeWidth=max(0.5f,u*0.03f)
            c.drawRoundRect(a.rect(key.x,key.y,key.width,1f).apply {inset(u*0.075f,u*0.075f)},u*0.13f,u*0.13f,p)
            p.style=Paint.Style.FILL;p.alpha=255
            if(key.id=="Space")c.drawRoundRect(a.rect(key.x+key.width/2-0.45f,key.y+0.76f,0.9f,0.05f),u*0.025f,u*0.025f,p)
            if(key.id=="Caps")c.drawCircle((key.x+0.25f)*u,(key.y+1f)*u,u*0.06f,p)
        }
        val display=a.rect(13.95f,0.05f,1.1f,0.9f)
        p.color=grey(0.01f);c.drawRoundRect(display,u*0.08f,u*0.08f,p)
        display.inset(u*0.06f,u*0.06f)
        if(screen!=null)c.drawBitmap(screen,null,display,p)
        else {p.color=android.graphics.Color.rgb(12,18,34);c.drawRect(display,p)
            if(u>=14) {p.color=grey(0.9f);p.textSize=u*0.24f;p.textAlign=Paint.Align.CENTER
                c.drawText(java.text.SimpleDateFormat("HH:mm",java.util.Locale.getDefault()).format(java.util.Date()),display.centerX(),display.centerY()+u*0.08f,p);p.textAlign=Paint.Align.LEFT}}
    }
}

@Composable
fun EffectSwatch(settings: LightingSettings, modifier: Modifier = Modifier) {
    Canvas(modifier.clip(RoundedCornerShape(7.dp))) {
        for(column in 0..23) {
            var r=0.0;var g=0.0;var b=0.0
            for(row in 0..2) {val rgb=LightingEffectRenderer.color(settings,(column+0.5)/24,0.25+row*0.25,1.7);r=max(r,rgb.r);g=max(g,rgb.g);b=max(b,rgb.b)}
            drawRect(Color(r.toFloat(),g.toFloat(),b.toFloat()),topLeft=androidx.compose.ui.geometry.Offset(column*size.width/24,0f),size=androidx.compose.ui.geometry.Size(size.width/24+0.5f,size.height))
        }
    }
}
