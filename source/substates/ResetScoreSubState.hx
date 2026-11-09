package substates;

import backend.WeekData;
import backend.Highscore;

import flixel.FlxSubState;
import objects.HealthIcon;

class ResetScoreSubState extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var alphabetArray:Array<Alphabet> = [];
	var icon:HealthIcon;
	var onYes:Bool = false;
	var yesText:Alphabet;
	var noText:Alphabet;

	var song:String;
	var difficulty:Int;
	var week:Int;

	// Week -1 = Freeplay
	public function new(song:String, difficulty:Int, character:String, week:Int = -1)
	{
		this.song = song;
		this.difficulty = difficulty;
		this.week = week;

		super();

		var name:String = song;
		if(week > -1) {
			name = WeekData.weeksLoaded.get(WeekData.weeksList[week]).weekName;
		}
		var difficultyName:String = '(' + Difficulty.getDisplayString(difficulty) + ')?';

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var text:Alphabet = new Alphabet(0, 180, Language.getPhrase('reset_score', 'Reset the score of'), true);
		text.screenCenter(X);
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		var text:Alphabet = new Alphabet(0, text.y + 90, name + ' ' + difficultyName, true);
		var iconSpace:Float = 0;
		if(week == -1) {
			icon = new HealthIcon(character);
			iconSpace = icon.width + 10;
		}
		var maxTextWidth:Float = FlxG.width - 80 - iconSpace;
		wrapText(text, name, difficultyName, maxTextWidth);

		yesText = new Alphabet(0, 0, Language.getPhrase('Yes'), true);
		noText = new Alphabet(0, 0, Language.getPhrase('No'), true);
		var maxTextHeight:Float = FlxG.height - text.y - Math.max(yesText.height, noText.height) - 100;
		// Only shrink an overlong word or a block too tall to leave room for the buttons.
		var textScale:Float = Math.min(1, Math.min(maxTextWidth / text.width, maxTextHeight / text.height));
		text.setScale(textScale);
		text.alignment = CENTERED;
		text.x = FlxG.width / 2;
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);
		if(week == -1) {
			icon.setGraphicSize(Std.int(icon.width * textScale));
			icon.updateHitbox();
			iconSpace = icon.width + 10 * textScale;
			var rowLeft:Float = (FlxG.width - text.width - iconSpace) / 2;
			text.x += iconSpace / 2;
			icon.setPosition(rowLeft, text.y + (text.height - icon.height) / 2);
			icon.alpha = 0;
			add(icon);
		}

		yesText.y = noText.y = text.y + Math.max(150, text.height + 60);
		yesText.screenCenter(X);
		yesText.x -= 200;
		add(yesText);
		noText.screenCenter(X);
		noText.x += 200;
		add(noText);
		centerContentVertically();
		
		for(letter in yesText.letters) letter.color = FlxColor.RED;
		updateOptions();
	}

	function wrapText(text:Alphabet, name:String, difficultyName:String, maxWidth:Float):Void
	{
		var lines:Array<String> = [];
		var paragraphs:Array<String> = name.split('\n');
		for(i in 0...paragraphs.length) {
			var words:Array<String> = paragraphs[i].split(' ');
			// Keep the difficulty label together on the final line.
			if(i == paragraphs.length - 1) words.push(difficultyName);
			var line:String = '';
			for(word in words) {
				var candidate:String = line.length > 0 ? line + ' ' + word : word;
				text.text = candidate;
				if(text.width > maxWidth && line.length > 0) {
					lines.push(line);
					line = word;
				} else {
					line = candidate;
				}
			}
			lines.push(line);
		}
		text.text = lines.join('\n');
	}

	function centerContentVertically():Void
	{
		var content:Array<FlxSprite> = [yesText, noText];
		for(text in alphabetArray) content.push(text);
		if(icon != null) content.push(icon);

		var top:Float = content[0].y;
		var bottom:Float = top + content[0].height;
		for(item in content) {
			top = Math.min(top, item.y);
			bottom = Math.max(bottom, item.y + item.height);
		}
		var offset:Float = (FlxG.height - (bottom - top)) / 2 - top;
		for(item in content) item.y += offset;
	}

	override function update(elapsed:Float)
	{
		bg.alpha += elapsed * 1.5;
		if(bg.alpha > 0.6) bg.alpha = 0.6;

		for (i in 0...alphabetArray.length) {
			var spr = alphabetArray[i];
			spr.alpha += elapsed * 2.5;
		}
		if(week == -1) icon.alpha += elapsed * 2.5;

		if(controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			FlxG.sound.play(Paths.sound('scrollMenu'), 1);
			onYes = !onYes;
			updateOptions();
		}
		if(controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		} else if(controls.ACCEPT) {
			if(onYes) {
				if(week == -1) {
					Highscore.resetSong(song, difficulty);
				} else {
					Highscore.resetWeek(WeekData.weeksList[week], difficulty);
				}
			}
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		}
		super.update(elapsed);
	}

	function updateOptions() {
		var scales:Array<Float> = [0.75, 1];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		if(week == -1) icon.animation.curAnim.curFrame = confirmInt;
	}
}
