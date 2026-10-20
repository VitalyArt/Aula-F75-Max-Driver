package com.vitalyart.aulaf75maxdriver

import kotlin.math.*

/** One value shared by the preview, local profiles and USB commands. */
data class LightingSettings(val mode: Int = 11, val brightness: Int = 5, val speed: Int = 3,
    val direction: Int = 0, val colorful: Boolean = true, val color: Int = 0x3366ff)
data class LightingProfile(val id: String, val name: String, val settings: LightingSettings)
data class PreviewRGB(val r: Double, val g: Double, val b: Double) {
    fun scaled(f: Double) = PreviewRGB((r*f).coerceIn(0.0,1.0), (g*f).coerceIn(0.0,1.0), (b*f).coerceIn(0.0,1.0))
}

/** Port of AulaCore's deterministic firmware-effect approximation. */
object LightingEffectRenderer {
    private fun fract(v: Double) = v - floor(v)
    private fun hash(a: Double,b: Double,c: Double) = fract(sin(a*12.9898+b*78.233+c*37.719)*43758.5453)
    private fun ring(v: Double) = (0.5+0.5*cos(fract(v)*2*PI)).pow(3)
    private fun distance(x: Double,y: Double) = sqrt((x-0.5).pow(2)+((y-0.5)*0.4).pow(2))
    private fun base(s: LightingSettings,h: Double): PreviewRGB {
        if (!s.colorful) return PreviewRGB(((s.color shr 16) and 255)/255.0, ((s.color shr 8) and 255)/255.0, (s.color and 255)/255.0)
        val sector=fract(h)*6; val f=sector-floor(sector)
        return when(floor(sector).toInt()%6) {
            0 -> PreviewRGB(1.0,f,0.0); 1 -> PreviewRGB(1-f,1.0,0.0)
            2 -> PreviewRGB(0.0,1.0,f); 3 -> PreviewRGB(0.0,1-f,1.0)
            4 -> PreviewRGB(f,0.0,1.0); else -> PreviewRGB(1.0,0.0,1-f)
        }
    }
    fun color(s: LightingSettings,x: Double,y: Double,time: Double): PreviewRGB {
        val rate=0.15+s.speed.coerceIn(1,5)*0.15; val phase=time*rate
        val along=when(s.direction) {1->y;2->1-x;3->1-y;else->x}
        fun flash(): Double { val cycle=time*rate*1.5+hash(x,y,7.0)*8; return if(hash(x,y,floor(cycle))>0.82) (1-fract(cycle)).pow(2) else 0.0 }
        val c=when(s.mode) {
            0 -> PreviewRGB(0.0,0.0,0.0)
            1 -> base(s,x*0.85)
            2 -> base(s,x).scaled(flash())
            3 -> base(s,x).scaled(1-flash())
            4 -> {val cycle=time*rate*3+hash(x,y,3.0)*5; base(s,hash(x,y,floor(time*rate*6))).scaled(if(hash(x,y,floor(cycle))>0.55) 1-fract(cycle)*0.7 else 0.08)}
            5 -> base(s,x).scaled(fract(y-phase*1.5+hash(floor(x*16),0.0,0.0)).pow(4))
            6 -> base(s,x)
            7 -> base(s,floor(phase*0.5)*0.17).scaled(0.5-0.5*cos(phase*PI))
            8 -> base(s,phase*0.25)
            9 -> base(s,distance(x,y)-phase).scaled(ring(distance(x,y)*2-phase*2))
            10 -> base(s,along-phase).scaled(ring(along*1.5-phase*1.5))
            11 -> base(s,along-phase)
            12 -> base(s,atan2(y-0.5,x-0.5)/(2*PI)+phase*0.5)
            13 -> {val burst=fract(phase*0.5); base(s,burst).scaled(max(0.0,1-abs(distance(x,y)-burst*0.9)*8)*(1-burst*0.6))}
            14 -> base(s,x).scaled(fract(1-y-phase*1.5+hash(floor(x*16),1.0,0.0)).pow(4))
            15 -> {var intensity=0.0;var hue=0.0
                for(drop in 0..2) {val cycle=phase*0.6+drop/3.0;val index=floor(cycle)
                    val dx=x-hash(index,drop.toDouble(),11.0);val dy=(y-hash(index,drop.toDouble(),13.0))*0.4
                    val strength=max(0.0,1-abs(sqrt(dx*dx+dy*dy)-fract(cycle)*0.6)*14)*(1-fract(cycle))
                    if(strength>intensity) {intensity=strength;hue=hash(index,drop.toDouble(),17.0)}}
                base(s,hue).scaled(intensity)}
            16 -> base(s,(along+(if(s.direction%2==0)y else x)*0.5)*0.7-phase)
            17 -> base(s,floor(phase)*0.23).scaled((1-fract(phase)).pow(2))
            18 -> base(s,along*0.6+y*sin(phase*PI)*0.5)
            19 -> {val position=0.5-0.5*cos(phase*PI);base(s,position).scaled(max(0.0,1-abs(along-position)*6))}
            else -> base(s,x-time*0.1)
        }
        return c.scaled(s.brightness.coerceIn(1,5)/5.0)
    }
}

data class KeyboardKey(val id: String,val label: String,val x: Float,val y: Float,val width: Float,val row: Int,val light: Boolean)
object KeyboardLayout {
    const val width=16f
    const val height=6.4f
    val keys: List<KeyboardKey> = buildList {
        var x=0f;var y=0f;var row=0
        fun start(r: Int, top: Float) {row=r;y=top;x=0f}
        fun addKey(label: String,w: Float=1f,id: String=label,light: Boolean=row<=2) {add(KeyboardKey(id,label,x,y,w,row,light));x+=w}
        start(0,0f);addKey("Esc");x+=0.25f
        for(n in 1..12) {addKey("F$n");if(n==4||n==8)x+=0.25f}
        start(1,1.25f); listOf("`","1","2","3","4","5","6","7","8","9","0","-","=").forEach {addKey(it)};addKey("Backspace",2f);addKey("Del")
        start(2,2.25f);addKey("Tab",1.5f);listOf("Q","W","E","R","T","Y","U","I","O","P","[","]").forEach {addKey(it)};addKey("\\",1.5f);addKey("PgUp")
        start(3,3.25f);addKey("Caps",1.75f);listOf("A","S","D","F","G","H","J","K","L",";","'").forEach {addKey(it)};addKey("Enter",2.25f,light=true);addKey("PgDn")
        start(4,4.25f);addKey("Shift",2.25f,"LShift");listOf("Z","X","C","V","B","N","M",",",".","/").forEach {addKey(it)};addKey("Shift",1.75f,"RShift");addKey("↑",id="Up");addKey("End")
        start(5,5.25f);addKey("Ctrl",1.25f);addKey("Win",1.25f);addKey("Alt",1.25f,"LAlt");addKey("",6.25f,"Space");addKey("Alt",id="RAlt");addKey("Fn");x+=1;y+=0.12f;addKey("←",id="Left");addKey("↓",id="Down");addKey("→",id="Right")
    }
}
