package backend.ui;

import flixel.text.FlxText;
#if lime_cffi
import openfl.text.Font;
import openfl.text._internal.TextEngine;
#end

/** Keeps the original face and size whenever they can display the text. */
class PsychUIText extends FlxText
{
	var preferredFont:String;
	var preferredSize:Int;

	#if lime_cffi
	static final coverage:Map<Font, Map<String, Bool>> = [];
	static final printable = ~/[^\t\r\n]/u;
	var face:Font;
	var glyphs:Map<String, Bool>;
	#else
	// Lime exposes no glyph indices on the web. These are the Unicode cmaps of
	// the bundled nokiafc22.ttf and vcr.ttf, plus the three layout characters.
	static final missingNokia = ~/[^\t\r\n\x20-\x7E\xA0-¡£-§º¿-ÏÑ-ÖØ-Ýß-ïñ-öø-ýÿĞğšŸˆ’€]/;
	static final missingVcr = ~/[^\t\r\n\x00\x1D\x20-\x7E\xA0-£¥¦¨-«\xAD®°²-´¹-ÖØ-öø-ÿ;‘’“”•…‹›⁄₣₤₧€™←-↔∕▲►▼◄]/;
	var missingGlyph:EReg;
	#end

	public function new(x:Float, y:Float, width:Float, value:String = '', size:Int = 8, ?originalFont:String)
	{
		super(x, y, width, value, size);
		if(originalFont != null) font = originalFont;
		preferredFont = font;
		preferredSize = size;
		#if lime_cffi
		// Resolve exactly the face OpenFL renders, including a mod's replacement.
		face = TextEngine.getFontInstance(textField.defaultTextFormat);
		if(face != null)
		{
			glyphs = coverage.get(face);
			if(glyphs == null)
			{
				glyphs = [];
				coverage.set(face, glyphs);
			}
		}
		#else
		missingGlyph = originalFont == null ? missingNokia : missingVcr;
		#end
		useFontFor(value);
	}

	function needsFallback(value:String):Bool
	{
		if(value == null || value.length == 0) return false;
		#if lime_cffi
		var pos = 0;
		while(printable.matchSub(value, pos))
		{
			if(face == null) return true;
			var character = printable.matched(0);
			var supported = glyphs.get(character);
			if(supported == null)
			{
				var index:Int = face.getGlyph(character);
				supported = index > 0;
				glyphs.set(character, supported);
			}
			if(!supported) return true;
			var match = printable.matchedPos();
			pos = match.pos + match.len;
		}
		return false;
		#else
		return missingGlyph.match(value);
		#end
	}

	/** Also used before measuring chart labels. Returns true when the metrics changed. */
	public function useFontFor(value:String):Bool
	{
		var useOriginal = !needsFallback(value);
		if(embedded == useOriginal) return false;
		if(useOriginal)
		{
			font = preferredFont;
			size = preferredSize;
		}
		else
		{
			systemFont = '_sans';
			size = Std.int(Math.max(12, preferredSize));
		}
		return true;
	}

	override function set_text(value:String):String
	{
		// FlxText assigns text once before it creates its TextField.
		if(preferredFont != null) useFontFor(value);
		return super.set_text(value);
	}
}
