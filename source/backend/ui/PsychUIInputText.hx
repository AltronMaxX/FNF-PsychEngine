package backend.ui;

import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import openfl.events.TextEvent;
import lime.system.Clipboard;

enum abstract FilterMode(Int) from Int from UInt to Int to UInt
{
	var NO_FILTER:Int = 0;
	var ONLY_ALPHA:Int = 1;
	var ONLY_NUMERIC:Int = 2;
	var ONLY_ALPHANUMERIC:Int = 3;
	var ONLY_HEXADECIMAL:Int = 4;
	var CUSTOM_FILTER:Int = 5;
}

enum abstract CaseMode(Int) from Int from UInt to Int to UInt
{
	var ALL_CASES:Int = 0;
	var UPPER_CASE:Int = 1;
	var LOWER_CASE:Int = 2;
}

class PsychUIInputText extends FlxSpriteGroup
{
	public static final CHANGE_EVENT = "inputtext_change";

	static var previousTextInputEnabled:Bool;

	public static var focusOn(default, set):PsychUIInputText = null;

	public var name:String;
	public var bg:FlxSprite;
	public var behindText:FlxSprite;
	public var selection:FlxSprite;
	public var textObj:FlxText;
	public var caret:FlxSprite;
	var originalLineHeight:Float;
	public var onChange:String->String->Void;

	public var fieldWidth(default, set):Int = 0;
	public var maxLength(default, set):Int = 0;
	public var passwordMask(default, set):Bool = false;
	public var text(default, set):String = '';
	// OpenFL uses code point indices for text selection and glyph bounds.
	var characters(get, never):UnicodeString;
	inline function get_characters():UnicodeString return text;

	public var forceCase(default, set):CaseMode = ALL_CASES;
	public var filterMode(default, set):FilterMode = NO_FILTER;
	public var customFilterPattern(default, set):EReg;

	public var selectedFormat:FlxTextFormat = new FlxTextFormat(FlxColor.WHITE);

	public function new(x:Float = 0, y:Float = 0, wid:Int = 100, ?text:String = '', size:Int = 8)
	{
		super(x, y);
		this.bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		this.behindText = new FlxSprite(1, 1).makeGraphic(1, 1, FlxColor.WHITE);
		this.selection = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		this.textObj = new PsychUIText(1, 1, Math.max(1, wid - 2), '', size);
		originalLineHeight = this.textObj.textField.textHeight;
		this.caret = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		add(this.bg);
		add(this.behindText);
		add(this.selection);
		add(this.textObj);
		add(this.caret);

		this.textObj.color = FlxColor.BLACK;
		this.textObj.textField.selectable = false;
		this.textObj.textField.wordWrap = false;
		this.textObj.textField.multiline = false;
		this.selection.color = FlxColor.BLUE;

		@:bypassAccessor fieldWidth = wid;
		setGraphicSize(wid + 2, this.textObj.height + 2);
		updateHitbox();
		this.text = text;
	}

	public var selectIndex:Int = -1;
	public var caretIndex(default, set):Int = 0;
	public var inInsertMode:Bool = false;
	public var broadcastInputTextEvent:Bool = true;
	var _caretTime:Float = 0;
	var dragAnchor:Int = -1;

	inline function selectionStart():Int
		return selectIndex < 0 || caretIndex < selectIndex ? caretIndex : selectIndex;

	inline function selectionEnd():Int
		return selectIndex > caretIndex ? selectIndex : caretIndex;

	function onTextInput(e:TextEvent)
	{
		// Keyboard shortcuts and Enter are handled separately from layout/IME text.
		var value = e.text;
		// Browser TEXT_INPUT also carries clipboard text, including line breaks.
		#if !html5
		value = ~/[\x00-\x1f\x7f]/g.replace(value, '');
		#end
		insertText(value, inInsertMode);
	}

	function onKeyDown(e:KeyboardEvent)
	{
		var key:FlxKey = cast e.keyCode;
		var shortcut = e.ctrlKey && !e.altKey;
		#if lime_cffi
		// SDL may send a non-Latin layout character for a physical shortcut key.
		if(shortcut && e.keyCode > 0xff)
		{
			switch(lime.ui.ScanCode.fromKeyCode(cast e.keyCode))
			{
				case A: key = A;
				case C: key = C;
				case X: key = X;
				case V: key = V;
				default:
			}
		}
		#end

		var start = selectionStart();
		var end = selectionEnd();
		switch(key)
		{
			case A if(shortcut):
				selectIndex = 0;
				caretIndex = characters.length;

			case X, C if(shortcut):
				if(start < end)
				{
					Clipboard.text = characters.substring(start, end);
					if(key == X) replaceRange(start, end, '');
				}

			case V if(shortcut):
				// Lime delivers browser pastes through TEXT_INPUT.
				#if !html5
				insertText(Clipboard.text);
				#end

			case LEFT, RIGHT, HOME, END:
				if(!e.shiftKey) selectIndex = -1;
				else if(selectIndex < 0) selectIndex = caretIndex;
				caretIndex = switch(key)
				{
					case HOME: 0;
					case END: characters.length;
					case LEFT: shortcut ? wordBoundary(false) : caretIndex - 1;
					default: shortcut ? wordBoundary(true) : caretIndex + 1;
				};

			case BACKSPACE, DELETE:
				if(start == end)
				{
					if(key == BACKSPACE) start = shortcut ? wordBoundary(false) : Std.int(Math.max(0, start - 1));
					else end = shortcut ? wordBoundary(true) : Std.int(Math.min(characters.length, end + 1));
				}
				if(start < end) replaceRange(start, end, '');

			case INSERT: inInsertMode = !inInsertMode;
			case ESCAPE: focusOn = null;
			case ENTER: onPressEnter(e);
			default:
		}
	}

	function wordBoundary(right:Bool):Int
	{
		var pos = caretIndex;
		var chars = characters;
		if(right)
		{
			var length = chars.length;
			while(pos < length && chars.charAt(pos) == ' ') pos++;
			while(pos < length && chars.charAt(pos) != ' ') pos++;
		}
		else
		{
			while(pos > 0 && chars.charAt(pos - 1) == ' ') pos--;
			while(pos > 0 && chars.charAt(pos - 1) != ' ') pos--;
		}
		return pos;
	}

	function insertText(value:String, overwrite:Bool = false)
	{
		if(value == null || value.length == 0) return;
		var inserted:UnicodeString = filter(value);
		var count = inserted.length;
		if(count == 0) return;

		var start = selectionStart();
		var end = selectionEnd();
		var length = characters.length;
		if(overwrite && start == end) end = Std.int(Math.min(length, start + count));
		if(maxLength > 0)
		{
			var available = maxLength - (length - (end - start));
			if(available <= 0) return;
			if(count > available) inserted = inserted.substr(0, available);
		}
		replaceRange(start, end, inserted);
	}

	function replaceRange(start:Int, end:Int, value:UnicodeString)
	{
		var old = text;
		var chars = characters;
		selectIndex = -1;
		text = chars.substring(0, start) + value + chars.substring(end);
		caretIndex = start + value.length;
		if(text != old)
		{
			if(onChange != null) onChange(old, text);
			if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
		}
	}

	public dynamic function onPressEnter(e:KeyboardEvent)
		focusOn = null;

	public var unfocus:Void->Void;
	public static function set_focusOn(v:PsychUIInputText)
	{
		if(focusOn == v) return v;
		var stage = FlxG.stage;
		var previous = focusOn;
		focusOn = v;
		if(previous != null)
		{
			stage.removeEventListener(KeyboardEvent.KEY_DOWN, previous.onKeyDown);
			stage.removeEventListener(TextEvent.TEXT_INPUT, previous.onTextInput);
		}
		#if !flash
		if(previous == null)
		{
			previousTextInputEnabled = stage.window.textInputEnabled;
			stage.window.textInputEnabled = true;
		}
		else if(v == null) stage.window.textInputEnabled = previousTextInputEnabled;
		#end
		if(v != null)
		{
			stage.addEventListener(KeyboardEvent.KEY_DOWN, v.onKeyDown);
			stage.addEventListener(TextEvent.TEXT_INPUT, v.onTextInput);
		}
		if(previous != null && previous.exists)
		{
			if(previous.unfocus != null) previous.unfocus();
			if(previous.exists && focusOn != previous) previous.resetCaret();
		}
		return focusOn;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(FlxG.mouse.justPressed)
		{
			if(FlxG.mouse.overlaps(behindText, camera))
			{
				if(!FlxG.keys.pressed.SHIFT) selectIndex = -1;
				else if(selectIndex < 0) selectIndex = caretIndex;
				focusOn = this;
				caretIndex = caretAtMouse();
				dragAnchor = selectIndex < 0 ? caretIndex : selectIndex;
			}
			else if(focusOn == this) focusOn = null;
		}
		else if(focusOn == this && dragAnchor >= 0 && FlxG.mouse.pressed && FlxG.mouse.justMoved)
		{
			selectIndex = dragAnchor;
			caretIndex = caretAtMouse();
		}
		if(!FlxG.mouse.pressed) dragAnchor = -1;

		if(focusOn == this)
		{
			_caretTime = (_caretTime + elapsed) % 1;
			if(textObj != null && textObj.exists)
			{
				var drewSelection:Bool = false;
				if(selection != null && selection.exists)
				{
					if(selectIndex != -1 && selectIndex != caretIndex)
					{
						selection.visible = true;
						drewSelection = true;
					}
					else selection.visible = false;
				}

				if(caret != null && caret.exists)
				{
					if(!drewSelection && _caretTime < 0.5 && caret.x >= textObj.x)
					{
						caret.visible = true;
						caret.color = textObj.color;
					}
					else caret.visible = false;
				}
			}
		}
		else
		{
			_caretTime = 0;
			inInsertMode = false;
			if(selection != null && selection.exists) selection.visible = false;
			if(caret != null && caret.exists) caret.visible = false;
		}
	}

	function caretAtMouse():Int
	{
		var field = textObj.textField;
		var mouse = FlxG.mouse.getScreenPosition(camera);
		var pos = textObj.getScreenPosition(camera);
		var x = mouse.x - pos.x + field.scrollH;
		mouse.put();
		pos.put();
		var low = 0;
		var high = field.length;
		while(low < high)
		{
			var mid = (low + high) >> 1;
			var bounds = field.getCharBoundaries(mid);
			if(bounds != null && x >= bounds.x + bounds.width / 2) low = mid + 1;
			else high = mid;
		}
		return low;
	}

	public function resetCaret()
	{
		dragAnchor = selectIndex = -1;
		caretIndex = 0;
	}

	function caretX(index:Int):Float
	{
		var field = textObj.textField;
		var bounds = field.getCharBoundaries(index);
		var x = bounds != null ? bounds.x : 2 + field.textWidth;
		return textObj.x + x - field.scrollH;
	}

	public function updateCaret()
	{
		if(textObj == null || !textObj.exists) return;
		var field = textObj.textField;
		field.setSelection(caretIndex, caretIndex);
		_caretTime = 0;
		caret.setPosition(caretX(caretIndex), textObj.y + 2);
		textObj.removeFormat(selectedFormat);
		if(selectIndex >= 0 && selectIndex != caretIndex)
		{
			var start = selectionStart();
			var end = selectionEnd();
			var left = FlxMath.bound(caretX(start), textObj.x, textObj.x + field.width);
			var right = FlxMath.bound(caretX(end), textObj.x, textObj.x + field.width);
			selection.setPosition(left, textObj.y + 2);
			selection.scale.set(Math.max(0, right - left), field.textHeight);
			selection.updateHitbox();
			textObj.addFormat(selectedFormat, start, end);
		}
	}

	override public function destroy()
	{
		if(focusOn == this) focusOn = null;
		super.destroy();
	}

	function set_caretIndex(v:Int)
	{
		caretIndex = Std.int(FlxMath.bound(v, 0, characters.length));
		updateCaret();
		return caretIndex;
	}

	override public function setGraphicSize(width:Float = 0, height:Float = 0)
	{
		super.setGraphicSize(width, height);
		bg.setGraphicSize(width, height);
		behindText.setGraphicSize(width - 2, height - 2);
		if(textObj != null && textObj.exists)
		{
			textObj.scale.x = 1;
			textObj.scale.y = 1;
			if(caret != null && caret.exists) caret.setGraphicSize(1, textObj.height - 4);
		}
	}

	override public function updateHitbox()
	{
		super.updateHitbox();
		bg.updateHitbox();
		behindText.updateHitbox();
		if(textObj != null && textObj.exists)
		{
			textObj.updateHitbox();
			if(caret != null && caret.exists) caret.updateHitbox();
		}
	}

	function set_fieldWidth(v:Int)
	{
		textObj.fieldWidth = Math.max(1, v - 2);
		textObj.textField.selectable = false;
		textObj.textField.wordWrap = false;
		textObj.textField.multiline = false;
		return (fieldWidth = v);
	}

	function set_maxLength(v:Int)
	{
		var lastText = text;
		v = Std.int(Math.max(0, v));
		if(v > 0 && characters.length > v) text = characters.substr(0, v);
		if(onChange != null) onChange(lastText, text);
		if(broadcastInputTextEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
		return (maxLength = v);
	}

	function set_passwordMask(v:Bool)
	{
		passwordMask = v;
		text = text;
		return passwordMask;
	}

	function set_text(v:String)
	{
		text = filter(v == null ? '' : v);
		var length = characters.length;
		var wasEmbedded = textObj.embedded;
		textObj.text = passwordMask ? ''.lpad('*', length) : text.replace('\r', ' ').replace('\n', ' ');
		if(textObj.embedded != wasEmbedded)
		{
			var lineHeight = textObj.embedded ? originalLineHeight : textObj.textField.textHeight;
			textObj.y = behindText.y + Math.floor((behindText.height - lineHeight) / 2) - 2;
			caret.setGraphicSize(1, lineHeight);
			caret.updateHitbox();
		}
		selectIndex = Std.int(Math.min(selectIndex, length));
		@:bypassAccessor caretIndex = Std.int(FlxMath.bound(caretIndex, 0, length));
		updateCaret();
		return text;
	}

	// from FlxInputText
	function set_forceCase(v:CaseMode)
	{
		forceCase = v;
		text = filter(text);
		return forceCase;
	}

	function set_filterMode(v:FilterMode)
	{
		filterMode = v;
		text = filter(text);
		return filterMode;
	}

	function set_customFilterPattern(cfp:EReg)
	{
		customFilterPattern = cfp;
		filterMode = CUSTOM_FILTER;
		return customFilterPattern;
	}

	private function filter(text:String):String
	{
		switch(forceCase)
		{
			case UPPER_CASE:
				text = text.toUpperCase();
			case LOWER_CASE:
				text = text.toLowerCase();
			default:
		}

		if (filterMode != NO_FILTER)
		{
			var pattern:EReg;
			switch (filterMode)
			{
				case ONLY_ALPHA:
					pattern = ~/[^a-zA-Z]*/g;
				case ONLY_NUMERIC:
					pattern = ~/[^0-9]*/g;
				case ONLY_ALPHANUMERIC:
					pattern = ~/[^a-zA-Z0-9]*/g;
				case ONLY_HEXADECIMAL:
					pattern = ~/[^a-fA-F0-9]*/g;
				case CUSTOM_FILTER:
					pattern = customFilterPattern;
				default:
					throw new flash.errors.Error("FlxInputText: Unknown filterMode (" + filterMode + ")");
			}
			text = pattern.replace(text, "");
		}
		return text;
	}
}
