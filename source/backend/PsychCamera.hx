package backend;

import openfl.display.Sprite;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import openfl.geom.Matrix;

// PsychCamera handles followLerp based on elapsed
// and stops camera from snapping at higher framerates

class PsychCamera extends FlxCamera
{
	@:keep
	public static function prepareShaderFilters():Void
	{
		if (FlxG.cameras == null || !FlxG.renderTile) return;
		for (camera in FlxG.cameras.list)
		{
			if (camera == null || camera.flashSprite == null) continue;
			@:privateAccess var target = camera._scrollRect;
			if (target == null || target.scrollRect == null) continue;
			target.filters = null;
			if (!camera.filtersEnabled || camera.filters == null || camera.filters.length == 0)
			{
				if (target.cacheAsBitmapMatrix != null) target.cacheAsBitmapMatrix = null;
				camera.flashSprite.filters = null;
				continue;
			}

			var filters:Array<BitmapFilter> = [];
			for (filter in camera.filters)
			{
				if (!(filter is ShaderFilter)) break;
				var shaderFilter:ShaderFilter = cast filter;
				if (shaderFilter.leftExtension != 0 || shaderFilter.topExtension != 0
					|| shaderFilter.rightExtension != 0 || shaderFilter.bottomExtension != 0) break;
				var copy:ShaderFilter = cast shaderFilter.clone();
				copy.rightExtension = -1;
				copy.bottomExtension = -1;
				filters.push(copy);
			}
			if (filters.length != camera.filters.length)
			{
				if (target.cacheAsBitmapMatrix != null) target.cacheAsBitmapMatrix = null;
				camera.flashSprite.filters = camera.filters;
				continue;
			}

			var rect = target.scrollRect;
			if (target.cacheAsBitmapMatrix == null) target.cacheAsBitmapMatrix = new Matrix();
			var pixelRatio = #if (openfl_disable_hdpi || openfl_disable_hdpi_cacheasbitmap) 1 #else FlxG.stage.window.scale #end;
			var width = Math.ceil(rect.width * pixelRatio);
			var height = Math.ceil(rect.height * pixelRatio);
			@:privateAccess var bitmap = target.__cacheBitmapData;
			if (bitmap != null && (bitmap.width != width || bitmap.height != height)) resetShaderCache(target);

			camera.flashSprite.filters = null;
			target.filters = filters;
		}
	}

	public static function resetShaderCache(sprite:Sprite):Void
	{
		@:privateAccess
		{
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
			sprite.__cacheBitmapData2 = null;
			sprite.__cacheBitmapData3 = null;
			sprite.__cacheBitmapRenderer = null;
		}
	}

	override public function update(elapsed:Float):Void
	{
		// follow the target, if there is one
		if (target != null)
		{
			updateFollowDelta(elapsed);
		}

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		flashSprite.filters = filtersEnabled ? filters : null;

		updateFlashSpritePosition();
		updateShake(elapsed);
	}

	public function updateFollowDelta(?elapsed:Float = 0):Void
	{
		// Either follow the object closely,
		// or double check our deadzone and update accordingly.
		if (deadzone == null)
		{
			target.getMidpoint(_point);
			_point.addPoint(targetOffset);
			_scrollTarget.set(_point.x - width * 0.5, _point.y - height * 0.5);
		}
		else
		{
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN)
			{
				if (targetX >= viewRight)
				{
					_scrollTarget.x += viewWidth;
				}
				else if (targetX + target.width < viewLeft)
				{
					_scrollTarget.x -= viewWidth;
				}

				if (targetY >= viewBottom)
				{
					_scrollTarget.y += viewHeight;
				}
				else if (targetY + target.height < viewTop)
				{
					_scrollTarget.y -= viewHeight;
				}
				
				// without this we see weird behavior when switching to SCREEN_BY_SCREEN at arbitrary scroll positions
				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge)
				{
					_scrollTarget.x = edge;
				}
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge)
				{
					_scrollTarget.x = edge;
				}

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge)
				{
					_scrollTarget.y = edge;
				}
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge)
				{
					_scrollTarget.y = edge;
				}
			}

			if ((target is FlxSprite))
			{
				if (_lastTargetPosition == null)
				{
					_lastTargetPosition = FlxPoint.get(target.x, target.y); // Creates this point.
				}
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;

				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}

		var mult:Float = 1 - Math.exp(-elapsed * followLerp / (1/60));
		scroll.x += (_scrollTarget.x - scroll.x) * mult;
		scroll.y += (_scrollTarget.y - scroll.y) * mult;
		//trace('lerp on this frame: $mult');
	}
}