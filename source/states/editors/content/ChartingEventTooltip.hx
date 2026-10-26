package states.editors.content;

import flixel.math.FlxRect;
import states.editors.content.MetaNote.EventMetaNote;

/** A screen-space card. Only its own contents scroll; the chart stays still. */
class ChartingEventTooltip extends FlxSpriteGroup
{
	static inline var PADDING:Int = 12;
	var border:FlxSprite;
	var background:FlxSprite;
	var scrollbar:FlxSprite;
	var rows:Array<{sprite:FlxSprite, top:Float}> = [];
	var signature:String = '';
	var contentHeight:Float = 0;
	var viewHeight:Float = 0;
	var cardWidth:Float = 346;
	var scroll:Float = 0;
	public var leaveTime:Float = 0;

	public function new()
	{
		super();
		scrollFactor.set();
		active = false;
		border = new FlxSprite().makeGraphic(1, 1, 0xFFA9A9A9);
		background = new FlxSprite().makeGraphic(1, 1, 0xFF181818);
		scrollbar = new FlxSprite().makeGraphic(1, 1, 0xFFAAAAAA);
		add(border);
		add(background);
		add(scrollbar);
		visible = false;
	}

	public function containsMouse():Bool
	{
		if(!visible) return false;
		var mouse = FlxG.mouse.getPositionInCameraView(camera);
		var inside = mouse.x >= x && mouse.x < x + cardWidth && mouse.y >= y && mouse.y < y + viewHeight + PADDING * 2;
		mouse.put();
		return inside;
	}

	public function hide():Void
	{
		visible = false;
		leaveTime = 0;
		signature = '';
	}

	public function showEvents(events:Array<EventMetaNote>, anchorX:Float, anchorY:Float):Void
	{
		var data:Array<Array<Dynamic>> = [for(e in events) [e.strumTime, e.events]];
		var newSignature = haxe.Json.stringify(data);
		if(newSignature == signature && visible) { leaveTime = 0; return; }
		signature = newSignature;
		for(row in rows) { remove(row.sprite, true); row.sprite.destroy(); }
		rows = [];
		contentHeight = scroll = leaveTime = 0;
		cardWidth = Math.min(346, FlxG.width - 24);
		var index = 0;
		while(index < events.length)
		{
			var time = events[index].strumTime;
			var entries:Array<Array<String>> = [];
			while(index < events.length && events[index].strumTime == time)
			{
				for(entry in events[index].events) entries.push(entry);
				index++;
			}
			addText(Std.string(time) + ' ms' + (entries.length > 1 ? '   (' + entries.length + ' Events)' : ''), 12, 0xFFCCCCCC);
			addSeparator();
			for(i => entry in entries)
			{
				addText((entries.length > 1 ? (i + 1) + '. ' : '') + entry[0], 14, FlxColor.WHITE);
				addText('Value 1: ' + (entry[1] == null ? '' : entry[1]) + '\nValue 2: ' + (entry[2] == null ? '' : entry[2]), 12, 0xFFCCCCCC);
				if(i < entries.length - 1) addSeparator();
			}
			if(index < events.length) { contentHeight += 8; addSeparator(); }
		}
		viewHeight = Math.min(contentHeight, FlxG.height - 48);
		setPosition(FlxMath.bound(anchorX + 10, 12, FlxG.width - cardWidth - 12),
			FlxMath.bound(anchorY + 10, 12, FlxG.height - viewHeight - PADDING * 2 - 12));
		visible = true;
		layout();
	}

	function addText(value:String, size:Int, color:FlxColor):Void
	{
		var text = new FlxText(0, 0, cardWidth - PADDING * 2 - 8, value, size);
		text.setFormat(Paths.font('vcr.ttf'), size, color, LEFT);
		text.scrollFactor.set();
		text.active = false;
		text.cameras = cameras;
		text.calcFrame(true);
		add(text);
		rows.push({sprite: text, top: contentHeight});
		contentHeight += text.height + 3;
	}

	function addSeparator():Void
	{
		contentHeight += 4;
		var separator = new FlxSprite().makeGraphic(Std.int(cardWidth - PADDING * 2 - 8), 1, 0xFF454545);
		separator.scrollFactor.set();
		separator.cameras = cameras;
		add(separator);
		rows.push({sprite: separator, top: contentHeight});
		contentHeight += 8;
	}

	public function scrollBy(wheel:Int):Void
	{
		scroll = FlxMath.bound(scroll - wheel * 36, 0, Math.max(0, contentHeight - viewHeight));
		layout();
	}

	function layout():Void
	{
		border.setPosition(x, y);
		border.setGraphicSize(Std.int(cardWidth), Std.int(viewHeight + PADDING * 2)); border.updateHitbox();
		background.setPosition(x + 1, y + 1);
		background.setGraphicSize(Std.int(cardWidth - 2), Std.int(viewHeight + PADDING * 2 - 2)); background.updateHitbox();
		for(row in rows)
		{
			var sprite = row.sprite;
			var top = row.top - scroll;
			sprite.setPosition(x + PADDING, y + PADDING + top);
			var start = Math.max(0, -top);
			var end = Math.min(sprite.height, viewHeight - top);
			sprite.visible = end > start;
			if(sprite.visible)
				sprite.clipRect = (sprite.clipRect != null ? sprite.clipRect : FlxRect.get()).set(0, start, sprite.width, end - start);
		}
		scrollbar.visible = contentHeight > viewHeight;
		if(scrollbar.visible)
		{
			var thumbHeight = Math.max(16, viewHeight * viewHeight / contentHeight);
			scrollbar.setGraphicSize(3, Std.int(thumbHeight)); scrollbar.updateHitbox();
			scrollbar.setPosition(x + cardWidth - 7, y + PADDING + (viewHeight - thumbHeight) * scroll / (contentHeight - viewHeight));
		}
	}
}
