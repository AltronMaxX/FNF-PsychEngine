package debug;

import flixel.FlxG;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;

/**
    The FPS class provides an easy-to-use monitor to display
    the current frame rate of an OpenFL project
**/
class FPSCounter extends Sprite
{
    /**
        The current frame rate, expressed using frames-per-second
    **/
    public var currentFPS(default, null):Int;

    /**
        The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
    **/
    public var memoryMegas(get, never):Float;
    private var maxGCMemory:Float = 0;

    public var taskMemory(get, never):Float;
    private var maxTaskMemory:Float = 0;

    @:noCompletion private var times:Array<Float>;

    private var textField:TextField;

    public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
    {
        super();

        this.x = x;
        this.y = y;

        currentFPS = 0;
        
        textField = new TextField();
        textField.x = 4;
        textField.y = 2;
        textField.selectable = false;
        textField.mouseEnabled = false;
        textField.defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font("mono.ttf")).fontName, 14, color);
        textField.autoSize = LEFT;
        textField.multiline = true;
        textField.text = "FPS: ";
        
        addChild(textField);

        times = [];
    }

    var deltaTimeout:Float = 0.0;

    // Event Handlers
    private override function __enterFrame(deltaTime:Float):Void
    {
        final now:Float = haxe.Timer.stamp() * 1000;
        times.push(now);
        while (times[0] < now - 1000) times.shift();
        // prevents the overlay from updating every frame, why would you need to anyways @crowplexus
        if (deltaTimeout < 50) {
            deltaTimeout += deltaTime;
            return;
        }

        currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate; 
        maxGCMemory = Math.max(maxGCMemory, memoryMegas);   
        maxTaskMemory = Math.max(maxTaskMemory, taskMemory);
        updateText();
        deltaTimeout = 0.0;
    }

    public dynamic function updateText():Void { // so people can override it in hscript
        textField.text = 'FPS: ${currentFPS}'
        + '\nGC MEM: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)} / ${flixel.util.FlxStringUtil.formatBytes(maxGCMemory)}'
        /*+ '\nTASK MEM: ${flixel.util.FlxStringUtil.formatBytes(taskMemory)} / ${flixel.util.FlxStringUtil.formatBytes(maxTaskMemory)}'*/; // TODO Seems like this realization is equal to gc

        textField.textColor = 0xFFFFFFFF;
        if (currentFPS < FlxG.drawFramerate * 0.5)
            textField.textColor = 0xFFFF0000;

        drawBackground();
    }

    private function drawBackground():Void
    {
        graphics.clear();

        graphics.lineStyle(2, 0xFF323232, 0.4);
        graphics.beginFill(0xFF323232, 0.8);

        var padX:Float = 12;
        var padY:Float = 4;
        graphics.drawRect(0, 0, textField.textWidth + padX, textField.textHeight + padY);
        
        graphics.endFill();
    }

    inline function get_memoryMegas():Float
        return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);

    inline function get_taskMemory():Float {
        return System.totalMemory;
    }
}