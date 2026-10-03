package objects;

import backend.NoteSkinData;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxRect;
import openfl.geom.ColorTransform;

/** Applies skin transforms only to rendering. Lua, tweens and hitboxes keep their usual values. */
class NoteSkinSprite extends FlxSprite
{
	public var skinData(default, null):NoteSkinData = new NoteSkinData();
	var skinColorTransform:ColorTransform = new ColorTransform();

	public function loadSkinData(image:String, kind:String):Void
		skinData = NoteSkinData.load(image, kind);

	override public function isSimpleRender(?camera:FlxCamera):Bool
	{
		return skinData.offsetX == 0 && skinData.offsetY == 0 && skinData.scaleX == 1 && skinData.scaleY == 1
			&& skinData.alpha == 1 && skinData.angle == 0 && super.isSimpleRender(camera);
	}

	// Mirrors FlxSprite's transform order without assigning its public properties, even during draw().
	override function drawComplex(camera:FlxCamera):Void
	{
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x * skinData.scaleX, scale.y * skinData.scaleY);
		var renderAngle = (bakedRotationAngle <= 0 ? angle : 0) + skinData.angle;
		if (renderAngle != 0)
		{
			var radians = renderAngle * Math.PI / 180;
			_matrix.rotateWithTrig(Math.cos(radians), Math.sin(radians));
		}
		getScreenPosition(_point, camera).subtractPoint(offset);
		_point.add(origin.x - skinData.offsetX, origin.y - skinData.offsetY);
		_matrix.translate(_point.x, _point.y);
		if (isPixelPerfectRender(camera))
		{
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}

		var transform = colorTransform;
		if (skinData.alpha != 1)
		{
			skinColorTransform.redMultiplier = colorTransform.redMultiplier;
			skinColorTransform.greenMultiplier = colorTransform.greenMultiplier;
			skinColorTransform.blueMultiplier = colorTransform.blueMultiplier;
			skinColorTransform.alphaMultiplier = colorTransform.alphaMultiplier * skinData.alpha;
			skinColorTransform.redOffset = colorTransform.redOffset;
			skinColorTransform.greenOffset = colorTransform.greenOffset;
			skinColorTransform.blueOffset = colorTransform.blueOffset;
			skinColorTransform.alphaOffset = colorTransform.alphaOffset * skinData.alpha;
			transform = skinColorTransform;
		}
		camera.drawPixels(_frame, framePixels, _matrix, transform, blend, antialiasing, shader);
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		if (newRect == null) newRect = FlxRect.get();
		if (camera == null) camera = FlxG.camera;
		var renderScaleX = scale.x * skinData.scaleX;
		var renderScaleY = scale.y * skinData.scaleY;
		newRect.setPosition(x, y);
		if (pixelPerfectPosition) newRect.floor();
		_scaledOrigin.set(origin.x * renderScaleX, origin.y * renderScaleY);
		newRect.x += -Std.int(camera.scroll.x * scrollFactor.x) - offset.x - skinData.offsetX + origin.x - _scaledOrigin.x;
		newRect.y += -Std.int(camera.scroll.y * scrollFactor.y) - offset.y - skinData.offsetY + origin.y - _scaledOrigin.y;
		if (isPixelPerfectRender(camera)) newRect.floor();
		newRect.setSize(frameWidth * Math.abs(renderScaleX), frameHeight * Math.abs(renderScaleY));
		return newRect.getRotatedBounds(angle + skinData.angle, _scaledOrigin, newRect);
	}
}
