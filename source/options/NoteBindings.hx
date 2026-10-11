package options;

import backend.InputFormatter;
import objects.StrumNote;
import states.FreeplayState.BubbleSelector;

/** Only the Notes section of ControlsSubState; the parent keeps its normal menu. */
class NoteBindings extends FlxTypedGroup<FlxSprite>
{
	public var keys:Int = 4;
	public var lane:Int = 0;
	public var keyboard:Bool = true;
	public var cells:Array<FlxSprite> = [];
	public var labels:Array<Alphabet> = [];
	public var keyLabels = new FlxTypedGroup<Alphabet>();
	var labelY:Array<Float> = [];
	public var bubbles:BubbleSelector;
	public var y(default, set):Float = 0;
	var localY:Array<Float> = [];

	public function new()
	{
		super();
		bubbles = new BubbleSelector(KeyMode.layouts.length);
		rebuild();
	}
	function place<T:FlxSprite>(sprite:T):T
	{
		sprite.scrollFactor.set();
		localY.push(sprite.y); add(sprite); return sprite;
	}
	function label(x:Float, top:Float, text:String, size:Float, width:Float = 0, binding:Bool = false):Alphabet
	{
		var item = new Alphabet(x, top, text, false);
		// Measurement also happens before Options assigns the pause camera.
		item.scrollFactor.set();
		item.setScale(size);
		if (width > 0 && item.width > width) item.setScale(size * width / item.width);
		// Alphabet has per-glyph baseline offsets; align its visible bounds.
		var min = Math.POSITIVE_INFINITY;
		var max = Math.NEGATIVE_INFINITY;
		for (letter in item.letters) {
			var bounds = letter.getScreenBounds(); min = Math.min(min, bounds.y); max = Math.max(max, bounds.bottom); bounds.put();
		}
		if (item.letters.length > 0) item.y += top - min + (binding ? (78 - (max - min)) / 2 : 0);
		if (binding) { labelY.push(item.y); keyLabels.add(item); return item; }
		return place(item);
	}
	public function bindName(action:String, slot:Int):String
	{
		if (keyboard) {
			var binds = ClientPrefs.keyBinds.get(action);
			return InputFormatter.getKeyName(binds != null && slot < binds.length ? binds[slot] : NONE);
		}
		var binds = ClientPrefs.gamepadBinds.get(action);
		return InputFormatter.getGamepadName(binds != null && slot < binds.length ? binds[slot] : NONE);
	}
	public function rebuild():Void
	{
		forEachAlive(sprite -> sprite.destroy()); clear();
		keyLabels.forEachAlive(sprite -> sprite.destroy()); keyLabels.clear();
		localY = []; labelY = []; cells = []; labels = [];
		lane = Std.int(Math.min(lane, keys - 1));
		var title = label(FlxG.width / 2, 0, '${keys}K', 0.85); title.alignment = CENTERED;
		var total = Math.min(960, keys * 250);
		var step = total / keys;
		var left = (FlxG.width - total) / 2;
		for (i in 0...keys) {
			var arrow = new StrumNote(0, 70, i, 0, keys);
			arrow.scrollFactor.set();
			arrow.playAnim('static');
			var bounds = arrow.getScreenBounds();
			var factor = Math.min(104, step - 14) / Math.max(bounds.width, bounds.height);
			bounds.put();
			arrow.scale.x *= factor; arrow.scale.y *= factor; arrow.updateHitbox();
			bounds = arrow.getScreenBounds();
			arrow.x += left + (i + 0.5) * step - (bounds.x + bounds.width / 2);
			arrow.y += 70 + (104 - bounds.height) / 2 - bounds.y;
			bounds.put(); place(arrow);
		}
		for (row in 0...2) for (i in 0...keys) {
			var x = left + i * step;
			var top = 188 + row * 78;
			var cell = place(new FlxSprite(x, top).makeGraphic(Std.int(step - 6), 78, FlxColor.BLACK));
			cell.alpha = 0.4; cells.push(cell);
			labels.push(label(x + 10, top, bindName(KeyMode.action(keys, i), row), 0.8, step - 26, true));
		}
		place(new FlxSprite(36, 185).loadGraphic(Paths.image('charArrow')));
		var next = place(new FlxSprite(FlxG.width - 94, 185).loadGraphic(Paths.image('charArrow'))); next.flipX = true;
		var prevLabel = label(65, 275, bindName('ui_prev', 0), 0.4); prevLabel.alignment = CENTERED;
		var nextLabel = label(FlxG.width - 65, 275, bindName('ui_next', 0), 0.4); nextLabel.alignment = CENTERED;
		bubbles.changeSelection(keys - 1); bubbles.x = (FlxG.width - bubbles.width) / 2;
		this.y = y;
	}
	function set_y(value:Float):Float
	{
		for (i => sprite in members) sprite.y = localY[i] + value;
		for (i => sprite in labels) sprite.y = labelY[i] + value;
		bubbles.y = 350 + value;
		return y = value;
	}
	public function select(row:Int):Void
	{
		for (i => item in labels) item.alpha = i == row * keys + lane ? 1 : 0.6;
	}
}
