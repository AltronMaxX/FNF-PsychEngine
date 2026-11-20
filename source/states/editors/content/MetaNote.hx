package states.editors.content;

import backend.NoteTypesConfig;
import objects.Note;
import shaders.RGBPalette;
import flixel.util.FlxDestroyUtil;

class MetaNote extends Note
{
	public static var noteTypeTexts:Map<Int, FlxText> = [];
	public var isEvent:Bool = false;
	public var songData:Array<Dynamic>;
	public var sustainSprite:FlxSprite;
	public var chartY:Float = 0;
	public var chartNoteData:Int = 0;
	public var selectionBrightness:Float = 1;
	public var gridAlpha:Float = 1;
	var lanePalette:RGBPalette;
	var typeUsesRGB:Bool;

	public function new(time:Float, data:Int, songData:Array<Dynamic>)
	{
		super(time, data, null, false, true);
		this.songData = songData;
		this.strumTime = time;
		this.chartNoteData = data;
	}

	public function applyChartNoteType(type:String):Void
	{
		lanePalette = rgbShader.parent;
		rgbShader.enabled = true;
		noteType = type;
		// Remember the type's request even if the song currently disables RGB.
		typeUsesRGB = rgbShader.enabled;
		if (usesDefaultColorsImage && rgbShader.parent != lanePalette) reloadChartSkin();
		if (usesDefaultColorsImage) rgbShader.textureAllowsRGB = false;
		updateRGB();
	}

	public function updateRGB():Void
		rgbShader.enabled = typeUsesRGB && PlayState.SONG.disableNoteRGB != true;

	function reloadChartSkin():Void
	{
		var allowNew = rgbShader.allowNew;
		rgbShader.allowNew = allowNew && rgbShader.parent == lanePalette;
		antialiasing = ClientPrefs.data.antialiasing;
		reloadNote(texture);
		rgbShader.allowNew = allowNew;
	}

	public function changeNoteData(v:Int)
	{
		this.chartNoteData = v; //despite being so arbitrary its sadly needed to fix a bug on moving notes
		this.songData[1] = v;
		this.noteData = v % ChartingState.GRID_COLUMNS_PER_PLAYER;
		this.mustPress = (v < ChartingState.GRID_COLUMNS_PER_PLAYER);
		refreshAppearance(true);
	}

	public function refreshAppearance(laneChanged:Bool = false):Void
	{
		var palette = Note.initializeGlobalRGBShader(noteStyle);
		if (lanePalette != palette)
		{
			var previous = rgbShader;
			var usedLaneColors = previous.allowNew && previous.parent == lanePalette;
			lanePalette = palette;
			rgbShader = new RGBShaderReference(this, palette);
			if (noteType == 'Hurt Note')
			{
				rgbShader.r = previous.parent.r;
				rgbShader.g = previous.parent.g;
				rgbShader.b = previous.parent.b;
			}
			if (noteType != null && noteType.length > 1)
				NoteTypesConfig.applyNoteTypeData(this, noteType, true);

			var typeAllowsRGB = rgbShader.textureAllowsRGB;
			if (!laneChanged || usedLaneColors != (rgbShader.allowNew && rgbShader.parent == lanePalette))
				reloadChartSkin();
			else if (PlayState.isPixelStage) loadPixelNoteAnims();
			else loadNoteAnims();

			rgbShader.textureAllowsRGB = typeAllowsRGB && !usesDefaultColorsImage;
			animation.play(animColor + 'Scroll');
			fitToGrid();
			y = chartY + (ChartingState.GRID_SIZE - height) / 2;
		}
		updateRGB();
	}

	public function fitToGrid():Void
	{
		updateHitbox();
		if(width > height)
			setGraphicSize(ChartingState.GRID_SIZE);
		else
			setGraphicSize(0, ChartingState.GRID_SIZE);

		updateHitbox();
	}

	public function setStrumTime(v:Float)
	{
		this.songData[0] = v;
		this.strumTime = v;
	}

	var _lastZoom:Float = -1;
	public function setSustainLength(v:Float, stepCrochet:Float, zoom:Float = 1)
	{
		_lastZoom = zoom;
		v = Math.round(v / (stepCrochet / 2)) * (stepCrochet / 2);
		songData[2] = sustainLength = Math.max(Math.min(v, stepCrochet * 128), 0);

		if(sustainLength > 0)
		{
			if(sustainSprite == null)
			{
				sustainSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
				sustainSprite.scrollFactor.x = 0;
			}
			sustainSprite.setGraphicSize(8, Math.max(ChartingState.GRID_SIZE/4, (Math.round((v * ChartingState.GRID_SIZE + ChartingState.GRID_SIZE) / stepCrochet) * zoom) - ChartingState.GRID_SIZE/2));
			sustainSprite.updateHitbox();
		}
	}

	public var hasSustain(get, never):Bool;
	function get_hasSustain() return (!isEvent && sustainLength > 0);

	public function updateSustainToZoom(stepCrochet:Float, zoom:Float = 1)
	{
		if(_lastZoom == zoom) return;
		setSustainLength(sustainLength, stepCrochet, zoom);
	}

	public function updateSustainToStepCrochet(stepCrochet:Float)
	{
		if(_lastZoom < 0) return;
		setSustainLength(sustainLength, stepCrochet, _lastZoom);
	}
	
	var _noteTypeText:FlxText;
	public function findNoteTypeText(num:Int)
	{
		var txt:FlxText = null;
		if(num != 0)
		{
			if(!noteTypeTexts.exists(num))
			{
				txt = new FlxText(0, 0, ChartingState.GRID_SIZE, (num > 0) ? Std.string(num) : '?', 16);
				txt.autoSize = false;
				txt.alignment = CENTER;
				txt.borderStyle = SHADOW;
				txt.shadowOffset.set(2, 2);
				txt.borderColor = FlxColor.BLACK;
				txt.scrollFactor.x = 0;
				noteTypeTexts.set(num, txt);
			}
			else txt = noteTypeTexts.get(num);
		}
		return (_noteTypeText = txt);
	}

	override function draw()
	{
		if(sustainSprite != null && sustainSprite.exists && sustainSprite.visible && sustainLength > 0)
		{
			sustainSprite.x = this.x + this.width/2 - sustainSprite.width/2;
			sustainSprite.y = this.y + this.height/2;
			sustainSprite.alpha = alpha * gridAlpha;
			sustainSprite.draw();
		}
		if (selectionBrightness == 1 && gridAlpha == 1) super.draw();
		else
		{
			var tint = colorTransform;
			var red = tint.redMultiplier;
			var green = tint.greenMultiplier;
			var blue = tint.blueMultiplier;
			var opacity = tint.alphaMultiplier;
			tint.redMultiplier *= selectionBrightness;
			tint.greenMultiplier *= selectionBrightness;
			tint.blueMultiplier *= selectionBrightness;
			tint.alphaMultiplier *= gridAlpha;
			super.draw();
			tint.redMultiplier = red;
			tint.greenMultiplier = green;
			tint.blueMultiplier = blue;
			tint.alphaMultiplier = opacity;
		}

		if(_noteTypeText != null && _noteTypeText.exists && _noteTypeText.visible)
		{
			_noteTypeText.x = this.x + this.width/2 - _noteTypeText.width/2;
			_noteTypeText.y = this.y + this.height/2 - _noteTypeText.height/2;
			_noteTypeText.alpha = alpha * gridAlpha;
			_noteTypeText.draw();
		}
	}

	override function destroy()
	{
		sustainSprite = FlxDestroyUtil.destroy(sustainSprite);
		super.destroy();
	}
}

class EventMetaNote extends MetaNote
{
	public var eventText:PsychUIText;
	public function new(time:Float, eventData:Dynamic)
	{
		super(time, -1, eventData);
		this.isEvent = true;
		events = eventData[1];
		//trace('events: $events');
		
		loadGraphic(Paths.image('editors/eventIcon'));
		setGraphicSize(ChartingState.GRID_SIZE);
		updateHitbox();

		eventText = new PsychUIText(0, 0, 400, '', 12, Paths.font('vcr.ttf'));
		eventText.alignment = RIGHT;
		eventText.scrollFactor.x = 0;
		updateEventText();
	}
	
	override function draw()
	{
		if(eventText != null && eventText.exists && eventText.visible)
		{
			eventText.y = this.y + this.height/2 - eventText.height/2;
			eventText.alpha = this.alpha;
			eventText.draw();
		}
		super.draw();
	}

	override function setSustainLength(v:Float, stepCrochet:Float, zoom:Float = 1) {}

	public var events:Array<Array<String>>;
	public function setLabelWidth(width:Float):Void
	{
		width = Math.max(1, Math.floor(width));
		if(eventText.fieldWidth == width) return;
		eventText.fieldWidth = width;
		updateEventText();
	}

	public function updateEventText()
	{
		eventText.wordWrap = false;
		var width = Math.max(0, eventText.fieldWidth - 4);
		function measure(value:String):Float
		{
			eventText.textField.text = value;
			return eventText.textField.textWidth;
		}
		eventText.useFontFor('');
		var label = ChartingEventText.compact(events, width, measure);
		if(eventText.useFontFor(label))
		{
			label = ChartingEventText.compact(events, width, measure);
			// The wider face can push the only missing glyph past the ellipsis.
			if(eventText.useFontFor(label))
				label = [for(line in label.split('\n')) ChartingEventText.ellipsize(line, width, measure)].join('\n');
		}
		eventText.text = label;
		eventText.calcFrame(true);
	}

	override function destroy()
	{
		eventText = FlxDestroyUtil.destroy(eventText);
		super.destroy();
	}
}
