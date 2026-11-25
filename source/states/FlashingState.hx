package states;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	static inline var REVEAL_INTERVAL:Float = 0.25;
	static inline var REVEAL_DURATION:Float = 0.35;

	var selectedOption:Int = -1;
	var content:FlxSpriteGroup;
	var revealItems:Array<FlxSprite> = [];
	var optionBorders:Array<FlxSprite> = [];
	var optionCursors:Array<FlxText> = [];
	var optionColors:Array<FlxColor> = [0xFFFFC66D, 0xFF83DDEB];
	var inputHint:FlxText;
	var revealElapsed:Float = 0;
	var introFinished:Bool = false;
	var acceptReady:Bool = false;
	var mouseIdleTime:Float = 0;

	override function create()
	{
		super.create();
		leftState = false;
		FlxG.mouse.visible = false;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK));
		content = new FlxSpriteGroup();
		add(content);

		final top:Float = (FlxG.height - 720) / 2;
		addRevealItem(makeText(top + 42, 'Warning!', 76, 0xFFFF4545));
		addRevealItem(makeText(top + 132, 'Flashing Lights', 56, FlxColor.WHITE));
		addRevealItem(makeText(top + 224,
			'This mod contains flashing lights and rapid visual effects.\n'
			+ 'These may trigger seizures in people with photosensitive epilepsy.', 22, 0xFFE0E0E6));
		addRevealItem(makeText(top + 304, 'Choose how you want to play:', 22, FlxColor.WHITE));

		addOption(top + 346, 'Keep flashing lights', 'Play with flashing effects enabled.', optionColors[0]);
		addOption(top + 456, 'Disable flashing lights', 'Reduce flashing effects during play.', optionColors[1]);

		addRevealItem(makeText(top + 586,
			'You can change this later in Options > Visuals > Flashing Lights.', 18, 0xFFB8B8C4));

		inputHint = makeText(top + 650, '', 20, 0xFFE0E0E6);
		content.add(inputHint);
		updateOptions();
		updateHint();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (leftState) return;

		final accept:Bool = controls.ACCEPT || FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER;
		final click:Bool = FlxG.mouse.justPressed;
		final mouseMoved:Bool = FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0;
		if (mouseMoved || click)
		{
			mouseIdleTime = 0;
			FlxG.mouse.visible = true;
		}
		else if (FlxG.mouse.visible)
		{
			mouseIdleTime += elapsed;
			if (mouseIdleTime > 2) FlxG.mouse.visible = false;
		}

		// Require the skip/entry button to be released before accepting a choice.
		if (!introFinished || !acceptReady)
			acceptReady = !controls.pressed('accept') && !FlxG.keys.pressed.SPACE && !FlxG.keys.pressed.ENTER && !FlxG.mouse.pressed;

		if (!introFinished)
		{
			revealElapsed += elapsed;
			for (i in 0...revealItems.length)
				revealItems[i].alpha = FlxMath.bound((revealElapsed - i * REVEAL_INTERVAL) / REVEAL_DURATION, 0, 1);

			if (accept || click || revealElapsed >= (revealItems.length - 1) * REVEAL_INTERVAL + REVEAL_DURATION)
			{
				introFinished = true;
				for (item in revealItems) item.alpha = 1;
			}
			updateHint();
			// Skipping the reveal must never also select or confirm an option.
			return;
		}

		final up:Bool = controls.UI_UP_P || FlxG.keys.justPressed.UP;
		final down:Bool = controls.UI_DOWN_P || FlxG.keys.justPressed.DOWN;
		if (up != down)
		{
			if (selectedOption < 0)
				selectOption(down ? 1 : 0);
			else
				selectOption((selectedOption + (down ? 1 : -1) + optionBorders.length) % optionBorders.length);
			updateHint();
			return;
		}

		var clickedOption:Bool = false;
		if (click || (mouseMoved && !accept))
		{
			for (i in 0...optionBorders.length)
			{
				if (!FlxG.mouse.overlaps(optionBorders[i])) continue;
				selectOption(i);
				clickedOption = click;
				break;
			}
		}

		updateHint();
		if ((accept || clickedOption) && acceptReady && selectedOption >= 0)
		{
			leftState = true;
			FlxG.mouse.visible = false;
			ClientPrefs.data.flashing = selectedOption == 0;
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('confirmMenu'));
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxTween.tween(content, {alpha: 0}, 0.35, {
				onComplete: (_) -> MusicBeatState.switchState(new TitleState())
			});
		}
	}

	function makeText(y:Float, value:String, size:Int, color:FlxColor):FlxText
	{
		final text = new FlxText(40, y, FlxG.width - 80, value);
		text.setFormat(Paths.font('vcr.ttf'), size, color, CENTER);
		return text;
	}

	function addRevealItem(item:FlxSprite):Void
	{
		content.add(item);
		item.alpha = 0;
		revealItems.push(item);
	}

	function addOption(y:Float, title:String, description:String, color:FlxColor):Void
	{
		final width:Int = Std.int(Math.min(860, FlxG.width - 80));
		final option = new FlxSpriteGroup((FlxG.width - width) / 2, y);
		final border = new FlxSprite().makeGraphic(width, 96, FlxColor.WHITE);
		option.add(border);
		optionBorders.push(border);
		option.add(new FlxSprite(2, 2).makeGraphic(width - 4, 92, 0xFF14141C));
		option.add(new FlxSprite(2, 2).makeGraphic(5, 92, color));

		final cursor = new FlxText(24, 23, 32, '>');
		cursor.setFormat(Paths.font('vcr.ttf'), 32, color, CENTER);
		option.add(cursor);
		optionCursors.push(cursor);

		final label = new FlxText(60, 10, width - 120, title);
		label.setFormat(Paths.font('vcr.ttf'), 32, color, CENTER);
		option.add(label);
		final detail = new FlxText(60, 55, width - 120, description);
		detail.setFormat(Paths.font('vcr.ttf'), 20, 0xFFE0E0E6, CENTER);
		option.add(detail);
		addRevealItem(option);
	}

	function selectOption(index:Int):Void
	{
		if (selectedOption == index) return;
		selectedOption = index;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
		updateOptions();
	}

	function updateOptions():Void
	{
		for (i in 0...optionBorders.length)
		{
			optionBorders[i].color = selectedOption == i ? optionColors[i] : 0xFF41414D;
			optionCursors[i].visible = selectedOption == i;
		}
	}

	function updateHint():Void
	{
		final confirm:String = controls.controllerMode ? 'A / START' : 'SPACE / ENTER';
		if (!introFinished)
			inputHint.text = confirm + ' or click - Show all';
		else if (selectedOption < 0)
			inputHint.text = 'UP / DOWN or hover - Choose an option first';
		else
			inputHint.text = 'UP / DOWN or hover - Choose    |    ' + confirm + ' or click - Confirm';
	}
}
