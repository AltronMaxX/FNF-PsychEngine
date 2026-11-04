package shaders;

import flixel.system.FlxAssets.FlxShader;

class DiamondTransitionShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform float progress;
		uniform vec2 screenSize;
		uniform float diamondPixelSize;
		uniform bool reveal;
		uniform float tileDurationRatio;

		void main()
		{
			vec2 uv = openfl_TextureCoordv;
			vec2 grid = uv * screenSize / diamondPixelSize;
			vec2 cell = abs(fract(grid) - 0.5);
			vec2 cellIndex = floor(grid);
			vec2 lastCell = ceil(screenSize / diamondPixelSize) - 1.0;
			float stagger = (cellIndex.x + cellIndex.y) / max(lastCell.x + lastCell.y, 1.0);
			float localProgress = clamp((progress - stagger * (1.0 - tileDurationRatio)) / tileDurationRatio, 0.0, 1.0);
			float radius = reveal ? 1.0 - localProgress : localProgress;
			float coverage = step(cell.x + cell.y, radius) * step(0.000001, radius);
			gl_FragColor = vec4(0.0, 0.0, 0.0, coverage);
		}')
	public function new(width:Int, height:Int, isTransIn:Bool, tileDuration:Float)
	{
		super();
		progress.value = [0.0];
		screenSize.value = [width, height];
		diamondPixelSize.value = [32.0];
		reveal.value = [isTransIn];
		tileDurationRatio.value = [tileDuration];
	}
}
