package;

import flixel.graphics.FlxGraphic;
#if desktop
import Discord.DiscordClient;
#end
import Section.SwagSection;
import Song.SwagSong;
import WiggleEffect.WiggleEffectType;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxCollision;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.utils.Assets;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.display.Shader;
import openfl.display.StageQuality;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import openfl.utils.Assets as OpenFlAssets;
import editors.ChartingState;
import editors.CharacterEditorState;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import Achievements;
import StageData;
import FunkinLua;
import DialogueBoxPsych;
import Shaders;

#if sys
import sys.FileSystem;
#end

using StringTools;

class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];
	
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var interlopeIntroTweens:Map<String, FlxTween> = new Map<String, FlxTween>(); //Added in v2.2 so that the custom arrow intro works if intro skip.
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	//event variables
	private var isCameraOnForcedPos:Bool = false;
	#if (haxe >= "4.0.0")
	public var boyfriendMap:Map<String, Boyfriend> = new Map();
	public var dadMap:Map<String, Character> = new Map();
	public var gfMap:Map<String, Character> = new Map();
	#else
	public var boyfriendMap:Map<String, Boyfriend> = new Map<String, Boyfriend>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;
	
	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public var shaderUpdates:Array<Float->Void> = [];
	public static var curStage:String = '';
	public static var isPixelStage:Bool = false;
	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var vocals:FlxSound;

	public var dad:Character;
	public var gf:Character;
	public var boyfriend:Boyfriend;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<Dynamic> = [];

	private var strumLine:FlxSprite;

	//Handles the new epic mega sexy cam code that i've done
	private var camFollow:FlxPoint;
	private var camFollowPos:FlxObject;
	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var camZooming:Bool = false;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health:Float = 1;
	public var maxHealth:Float = 0; //Totally not stolen from Lullaby lol
	public var combo:Int = 0;

	private var healthBarBG:AttachedSprite;
	public var healthBar:FlxBar;
	var songPercent:Float = 0;

	private var timeBarBG:AttachedSprite;
	public var timeBar:FlxBar;
	
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;
	
	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	private var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	var dialogue:Array<String> = ['blah blah blah', 'coolswag'];
	var dialogueJson:DialogueFile = null;

	var halloweenBG:BGSprite;
	var halloweenWhite:BGSprite;

	var phillyCityLights:FlxTypedGroup<BGSprite>;
	var phillyTrain:BGSprite;
	var blammedLightsBlack:ModchartSprite;
	var blammedLightsBlackTween:FlxTween;
	var phillyCityLightsEvent:FlxTypedGroup<BGSprite>;
	var phillyCityLightsEventTween:FlxTween;
	var trainSound:FlxSound;

	var limoKillingState:Int = 0;
	var limo:BGSprite;
	var limoMetalPole:BGSprite;
	var limoLight:BGSprite;
	var limoCorpse:BGSprite;
	var limoCorpseTwo:BGSprite;
	var bgLimo:BGSprite;
	var grpLimoParticles:FlxTypedGroup<BGSprite>;
	var grpLimoDancers:FlxTypedGroup<BackgroundDancer>;
	var fastCar:BGSprite;

	var upperBoppers:BGSprite;
	var bottomBoppers:BGSprite;
	var santa:BGSprite;
	var heyTimer:Float;

	var bgGirls:BackgroundGirls;
	var wiggleShit:WiggleEffect = new WiggleEffect();
	var bgGhouls:BGSprite;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	#if desktop
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	// Lua shit
	public static var instance:PlayState;
	public var luaArray:Array<FunkinLua> = [];
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	public var introSoundsSuffix:String = '';

	// Debug buttons
	private var debugKeysChart:Array<FlxKey>;
	private var debugKeysCharacter:Array<FlxKey>;
	
	// Less laggy controls
	private var keysArray:Array<Dynamic>;

	//Achievement shit
	var keysPressed:Array<Bool> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;
	var sawbladeHits:Int = 0;
	var tauntCounter:Int = 0;
	var cessationTrollDone:Bool = false;

	//HAZARD SHIT
	var godMode:Bool = false; //For testing shit.

	private var dodgeKey:Array<FlxKey>;
	private var tauntKey:Array<FlxKey>;

	var healthLossMultiplier:Float = 1; 
	var healthGainMultiplier:Float = 1; //To make Termination health gain more... fair?
	var dadDrainHealth:Float = 0; //Because I like how the opponent takes health away when hitting notes in other mods, even if it isn't that much.
	var dadDrainHealthSustain:Bool = false; //Used in Censory-Overload Harder difficulty. Allows for sustain notes to drain health (at a massively reduced rate)

	//Ew. Don't talk about this please. This variable doesn't exist.
	public static var THISISFUCKINGDISGUSTINGPLEASESAVEME:Bool = true;

	var endingCutsceneDone:Bool = false; //To ensure that the ending dialogue doesn't repeat itself. Doing this because achievements kept restarting the dialogue.

	//Ported from Inhuman LMAO
	private var fogShitDEBUG:FogThing;
	private var fogShitGroup:FlxTypedGroup<FogThing>;
	var skippedIntro:Bool = false;
	var introSkip:Int = 0;
	var introSkipSprite:BGSprite;
	var discordDifficultyOverrideShouldUse:Bool = false;
	var discordDifficultyOverride:String = "???";
	var inhumanSong:Bool = false;
	var disableDefaultCamZooming:Bool = false;
	var disableArrowIntro:Bool = false;
	var forceMiddleScroll:Bool = false;
	var controlsPlayer2:Bool = false; //Set to true if you are doing modchart shit. Stops middle scroll from disabling player2's notes and the player can hit them as if they were player 1 notes (if that makes sense?)
	var causeOfDeath:String = 'health';
	//'health' / null 	= death by health
	//'hurt' 			= death by hurt note
	//'sawblade' 		= death by sawblade
	
	//QT Week port
	var streetBG:FlxSprite;
	var qt_tv01:FlxSprite;
	var cessationTroll:FlxSprite;
	var streetBGerror:FlxSprite;
	var streetFrontError:FlxSprite;
	var bfDodging:Bool = false;
	var bfCanDodge:Bool = false;
	var bfDodgeTiming:Float = 0.222; //0.22625 for single sawblades (most forgiving), 0.222 for double sawblade variation
	var bfDodgeCooldown:Float = 0.102; //0.1135 for single sawblades (most forgiving), 0.102 for double sawblade variation
	var canSkipEndScreen:Bool = false; //This is set to true at the "thanks for playing" screen. Once true, in update, if enter is pressed it'll skip to the main menu.
	var kb_attack_alert:FlxSprite;
	var kb_attack_saw:FlxSprite;
	public var pincer1:FlxSprite;
	public var pincer2:FlxSprite;
	public var pincer3:FlxSprite;
	public var pincer4:FlxSprite;
	var pincers:Array<FlxSprite> = []; // a array of the pincers for otmizing the code. -Luis
	var qt_gas01:FlxSprite;
	var qt_gas02:FlxSprite;
	var hazardRandom:Int = 1; //This integer is randomised upon song start between 1-5.

	var qtSawbladeAdded:Bool = false;
	var qtAlertAdded:Bool = false;
	var freezeNotes:Bool = false; //Used for Terminate's ending
	var gfScared:Bool = false;
	var qtTVstate:Int = 0; 
	/*
	0 = static
	1 = alert
	2 = instructions part 1
	3 = instructions part 2
	9 = drop
	4 = watch out
	5 = brutality labs moment
	6 = glitch
	7 = bluescreen
	8 = heart
	69 or 420 = sus
	*/

	//More Inhuman-Port Shit
	var noteSpeen:Int = 0; //Used for interlope
	var opponentNoteColourChange:Bool = false; //Set to true to set the opponent notes red.
	var hazardModChartEffectWave:Int = 0; //notes move up and down in a wave-like motion. 1=y motion only, 2=y and x motion. 0 = off
	var hazardModChartEffect:Int = 0;
	//0 = no effect
	//1 = scrolling to the side 			- 	Variable1 = speed
	//2 = KB screen shake					
	//3 = Interlope main effect				
	//4 = Interlope scrolling effect		-	Variable1 = Lerp% (0 = no effect, 1 = full effect)
	//5 = Interlope main effect + fake
	//6 = ScrollSpeed Pulse effect
	//7 = 'her' Spin Effect (oooooo I wonder what this is forrrr oooooooOOOOOOOOoooo~)
	var hazardModChartVariable1:Float = 0;
	var hazardModChartDefaultStrumX:Array<Float> = [0,0,0,0,0,0,0,0];
	var hazardModChartDefaultStrumY:Array<Float> = [0,0,0,0,0,0,0,0];

	var wiggleShitShowCAMERA:WiggleEffect = null;
	var wiggleShitShow:WiggleEffect = null;
	var interlopeChroma:ChromaticAberrationEffect = null;
	var interlopeChromaIntensity:Float = 0;
	var interlopeFadeinShader:TiltshiftEffect = null;
	var interlopeFadeinShaderIntensity:Float = 4;
	var interlopeFadeinShaderFading:Bool = false;

	var hazardBG:BGSprite;
	var hazardBGkb:FlxSprite; //Used for KB and Cinder's song
	var hazardBGvoid:BGSprite; //Void is behind camera!
	var hazardBlack:BGSprite; //Black is ontop of camera!
	var hazardInterlopeLaugh:FlxSprite; //Used by Amelia in Interlope when taunting player
	var hazardOverlayShit:BGSprite;
	var hazardNoise:FlxSprite;
	var hazardBGpulsing:Bool = false; //Set to true to pulse the background in some sections.
	var interlopeIntroTween:FlxTween;
	var interlopeIntroTweenHUD:FlxTween;

	var hazardAlarmLeft:BGSprite;
	var hazardAlarmRight:BGSprite;

	override public function create()
	{
		Paths.clearStoredMemory();

		// for lua
		instance = this;

		debugKeysChart = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));
		debugKeysCharacter = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_2'));

		dodgeKey = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('qt_dodge'));
		tauntKey = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('qt_taunt'));

		Achievements.loadAchievements();

		keysArray = [
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_left')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_down')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_up')),
			ClientPrefs.copyKey(ClientPrefs.keyBinds.get('note_right'))
		];

		// For the "Just the Two of Us" achievement
		for (i in 0...keysArray.length)
		{
			keysPressed.push(false);
		}

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);

		// var gameCam:FlxCamera = FlxG.camera;
		FlxG.cameras.reset(camGame = new FlxCamera());
		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		FlxG.cameras.add(camHUD = new FlxCamera());
		FlxG.cameras.setDefaultDrawTarget(camHUD, false);
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camOther = new FlxCamera());
		FlxG.cameras.setDefaultDrawTarget(camOther, false);
		camOther.bgColor.alpha = 0;
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

		CustomFadeTransition.nextCamera = camOther;
		//FlxG.cameras.setDefaultDrawTarget(camGame, true);

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('tutorial');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		#if desktop
		storyDifficultyText = CoolUtil.difficulties[storyDifficulty];

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
		{
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		}
		else
		{
			detailsText = "Freeplay";
		}

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		BrutalityGameOverSubstate.resetVariables();
		causeOfDeath='health';
		THISISFUCKINGDISGUSTINGPLEASESAVEME = true;
		endingCutsceneDone=false;
		var songName:String = Paths.formatToSongPath(SONG.song);

		forceMiddleScroll = ClientPrefs.middleScroll;

		curStage = PlayState.SONG.stage;
		//trace('stage is: ' + curStage);
		if(PlayState.SONG.stage == null || PlayState.SONG.stage.length < 1) {
			switch (songName)
			{
				case 'carefree':
					curStage = 'street-cute';
				case 'careless':
					curStage = 'street-real';
				case 'cessation':
					curStage = 'street-cessation';
				case 'censory-overload' | 'terminate':
					curStage = 'street-kb';
				case 'termination':
					curStage = 'street-termination';
				default:
					curStage = 'stage';
			}
		}

		var stageData:StageFile = StageData.getStageFile(curStage);
		if(stageData == null) { //Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = {
				directory: "",
				defaultZoom: 0.9,
				isPixelStage: false,
			
				boyfriend: [770, 100],
				girlfriend: [400, 130],
				opponent: [100, 100]
			};
		}

		defaultCamZoom = stageData.defaultZoom;
		isPixelStage = stageData.isPixelStage;
		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage)
		{
			case 'stage': //Week 1
				var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
				add(bg);

				var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				add(stageFront);

				if(!ClientPrefs.lowQuality) {
					var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					add(stageLight);
					var stageLight:BGSprite = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					stageLight.flipX = true;
					add(stageLight);

					var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
					stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
					stageCurtains.updateHitbox();
					add(stageCurtains);
				}
			
			//QT port
			case 'street-cessation':
				dadDrainHealth=0.0116;
				healthLossMultiplier=1.125;
				discordDifficultyOverrideShouldUse = true;
				discordDifficultyOverride = "Future";

				hazardBG = new BGSprite('hazard/qt-port/stage/streetBackCute', -750, -145, 0.95, 0.95);
				add(hazardBG);

				var streetFront:BGSprite = new BGSprite('hazard/qt-port/stage/streetFrontCute', -820, 710, 0.95, 0.95);
				streetFront.setGraphicSize(Std.int(streetFront.width * 1.15));
				streetFront.updateHitbox();
				add(streetFront);

				qt_tv01 = new FlxSprite();
				qt_tv01.frames = Paths.getSparrowAtlas('hazard/qt-port/stage/TV_V5');
				qt_tv01.animation.addByPrefix('idle', 'TV_Idle', 24, true);	
				qt_tv01.animation.addByPrefix('alert', 'TV_Attention', 28, false);		
				qt_tv01.animation.addByPrefix('sus', 'TV_sus', 24, true);
				qt_tv01.animation.addByPrefix('heart', 'TV_End', 24, false);
				qt_tv01.animation.addByPrefix('eye', 'TV_brutality', 24, true); //Replaced the hex eye with the brutality symbols for more accurate lore.
				qt_tv01.animation.addByPrefix('error', 'TV_Error', 24, true);	
				qt_tv01.animation.addByPrefix('404', 'TV_Bluescreen', 24, true);		
				qt_tv01.animation.addByPrefix('watch', 'TV_Watchout', 24, true);
				qt_tv01.animation.addByPrefix('drop', 'TV_Drop', 24, true);
				qt_tv01.animation.addByPrefix('instructions', 'TV_Instructions-Normal', 24, true);
				qt_tv01.animation.addByPrefix('gl', 'TV_GoodLuck', 24, true);
				qt_tv01.animation.addByPrefix('heart', 'TV_End', 24, false);
				qt_tv01.animation.addByPrefix('eyeRight', 'TV_eyeRight', 24, false);
				qt_tv01.animation.addByPrefix('eyeLeft', 'TV_eyeLeft', 24, false);
				qt_tv01.setPosition(-62, 540);
				qt_tv01.setGraphicSize(Std.int(qt_tv01.width * 1.2));
				qt_tv01.updateHitbox();
				qt_tv01.antialiasing = ClientPrefs.globalAntialiasing;
				qt_tv01.scrollFactor.set(0.9, 0.9);
				add(qt_tv01);
				qt_tv01.animation.play('heart');
				qtTVstate=8;

				cessationTroll = new FlxSprite(-62, 540).loadGraphic(Paths.image('hazard/qt-port/justkidding'));
				cessationTroll.setGraphicSize(Std.int(cessationTroll.width * 0.9));
				cessationTroll.cameras = [camHUD];
				cessationTroll.x = FlxG.width - 950;
				cessationTroll.y = 205;

			case 'street-cute':
				dadDrainHealth=0.011;
				healthLossMultiplier=1.1;

				hazardBG = new BGSprite('hazard/qt-port/stage/streetBackCute', -750, -145, 0.95, 0.95);
				add(hazardBG);

				var streetFront:BGSprite = new BGSprite('hazard/qt-port/stage/streetFrontCute', -820, 710, 0.95, 0.95);
				streetFront.setGraphicSize(Std.int(streetFront.width * 1.15));
				streetFront.updateHitbox();
				add(streetFront);

				qt_tv01 = new FlxSprite(-62, 540).loadGraphic(Paths.image('hazard/qt-port/stage/TV_V2_off'));
				qt_tv01.setGraphicSize(Std.int(qt_tv01.width * 1.2));
				qt_tv01.updateHitbox();
				qt_tv01.antialiasing = true;
				qt_tv01.scrollFactor.set(0.9, 0.9);
				qt_tv01.active = false;
				add(qt_tv01);

			case 'street-real':
				dadDrainHealth=0.0115;
				healthLossMultiplier=1.125;

				hazardBG = new BGSprite('hazard/qt-port/stage/streetBack', -750, -145, 0.95, 0.95);
				add(hazardBG);

				var streetFront:FlxSprite = new FlxSprite(-820, 710).loadGraphic(Paths.image('hazard/qt-port/stage/streetFront'));
				streetFront.setGraphicSize(Std.int(streetFront.width * 1.15));
				streetFront.updateHitbox();
				streetFront.antialiasing = ClientPrefs.globalAntialiasing;
				streetFront.scrollFactor.set(0.95, 0.95);
				streetFront.active = false;
				add(streetFront);

				qt_tv01 = new FlxSprite();
				qt_tv01.frames = Paths.getSparrowAtlas('hazard/qt-port/stage/TV_V5');
				qt_tv01.animation.addByPrefix('idle', 'TV_Idle', 24, true);
				qt_tv01.animation.addByPrefix('alert', 'TV_Attention', 26, false);
				//qt_tv01.animation.addByPrefix('eye', 'TV_eyes', 24, true);	
				qt_tv01.animation.addByPrefix('eye', 'TV_brutality', 24, true); //Replaced the hex eye with the brutality symbols for more accurate lore.
				qt_tv01.animation.addByPrefix('eyeLeft', 'TV_eyeLeft', 24, false);
				qt_tv01.animation.addByPrefix('eyeRight', 'TV_eyeRight', 24, false);
				qt_tv01.animation.addByPrefix('error', 'TV_Error', 24, true);	
				qt_tv01.animation.addByPrefix('404', 'TV_Bluescreen', 24, true);		
				qt_tv01.animation.addByPrefix('watch', 'TV_Watchout', 24, true);
				qt_tv01.animation.addByPrefix('drop', 'TV_Drop', 24, true);
				qt_tv01.animation.addByPrefix('sus', 'TV_sus', 24, true);
				qt_tv01.animation.addByPrefix('instructions', 'TV_Instructions-Normal', 24, true);
				qt_tv01.animation.addByPrefix('gl', 'TV_GoodLuck', 24, true);
				qt_tv01.animation.addByPrefix('heart', 'TV_End', 24, false);

				qt_tv01.setPosition(-62, 540);
				qt_tv01.setGraphicSize(Std.int(qt_tv01.width * 1.2));
				qt_tv01.updateHitbox();
				qt_tv01.antialiasing = ClientPrefs.globalAntialiasing;
				qt_tv01.scrollFactor.set(0.9, 0.9);
				add(qt_tv01);
				qt_tv01.animation.play('idle');

			case 'street-kb':
				dadDrainHealth=0.01185;
				healthLossMultiplier=1.075;

				if(!ClientPrefs.lowQuality){
					//Far Back Layer - Error (blue screen)
					var errorBG:BGSprite = new BGSprite('hazard/qt-port/stage/streetError', -750, -145, 0.95, 0.95);
					add(errorBG);

					//Back Layer - Error (glitched version of normal Back)
					streetBGerror = new FlxSprite(-750, -145).loadGraphic(Paths.image('hazard/qt-port/stage/streetBackError'));
					streetBGerror.antialiasing = ClientPrefs.globalAntialiasing;
					streetBGerror.scrollFactor.set(0.95, 0.95);
					add(streetBGerror);
				}

				//Back Layer - Normal
				streetBG = new FlxSprite(-750, -145).loadGraphic(Paths.image('hazard/qt-port/stage/streetBack'));
				streetBG.antialiasing = true;
				streetBG.scrollFactor.set(0.95, 0.95);
				add(streetBG);

				//Front Layer - Normal
				var streetFront:BGSprite = new BGSprite('hazard/qt-port/stage/streetFront', -820, 710, 0.95, 0.95);
				streetFront.setGraphicSize(Std.int(streetFront.width * 1.15));
				streetFront.updateHitbox();
				add(streetFront);

				if(!ClientPrefs.lowQuality){
					//Front Layer - Error (changes to have a glow)
					streetFrontError = new FlxSprite(-820, 710).loadGraphic(Paths.image('hazard/qt-port/stage/streetFrontError'));
					streetFrontError.setGraphicSize(Std.int(streetFrontError.width * 1.15));
					streetFrontError.updateHitbox();
					streetFrontError.antialiasing = ClientPrefs.globalAntialiasing;
					streetFrontError.scrollFactor.set(0.95, 0.95);
					streetFrontError.active = false;
					add(streetFrontError);
					streetFrontError.visible = false;
				}

				qt_tv01 = new FlxSprite();
				qt_tv01.frames = Paths.getSparrowAtlas('hazard/qt-port/stage/TV_V5');
				qt_tv01.animation.addByPrefix('idle', 'TV_Idle', 24, true);
				qt_tv01.animation.addByPrefix('eye', 'TV_brutality', 24, true); //Replaced the hex eye with the brutality symbols for more accurate lore.
				qt_tv01.animation.addByPrefix('error', 'TV_Error', 24, true);	
				qt_tv01.animation.addByPrefix('404', 'TV_Bluescreen', 24, true);		
				qt_tv01.animation.addByPrefix('alert', 'TV_Attention', 32, false);		
				qt_tv01.animation.addByPrefix('watch', 'TV_Watchout', 24, true);
				qt_tv01.animation.addByPrefix('drop', 'TV_Drop', 24, true);
				qt_tv01.animation.addByPrefix('sus', 'TV_sus', 24, true);
				qt_tv01.animation.addByPrefix('instructions', 'TV_Instructions-Normal', 24, true);
				qt_tv01.animation.addByPrefix('gl', 'TV_GoodLuck', 24, true);
				qt_tv01.animation.addByPrefix('heart', 'TV_End', 24, false);
				qt_tv01.animation.addByPrefix('eyeRight', 'TV_eyeRight', 24, false);
				qt_tv01.animation.addByPrefix('eyeLeft', 'TV_eyeLeft', 24, false);
				qt_tv01.animation.addByPrefix('heart', 'TV_End', 24, false);
				qt_tv01.setPosition(-62, 540);
				qt_tv01.setGraphicSize(Std.int(qt_tv01.width * 1.2));
				qt_tv01.updateHitbox();
				qt_tv01.antialiasing = ClientPrefs.globalAntialiasing;
				qt_tv01.scrollFactor.set(0.9, 0.9);
				add(qt_tv01);
				qt_tv01.animation.play('idle');

			case 'street-termination':
				disableArrowIntro = true;
				discordDifficultyOverrideShouldUse = true;
				if(storyDifficulty==2){
					discordDifficultyOverride = "Classic";
					healthLossMultiplier=2.175; //That's alotta damage!
					healthGainMultiplier=1.085;
					dadDrainHealth=0; //No health drain on classic because... well the original didn't have it. This version is already brutal with health loss on miss anyway.
				}else{
					discordDifficultyOverride = "Very Hard";
					healthLossMultiplier=1.288;
					healthGainMultiplier=1.051;
					dadDrainHealth=0.014625;
				}

				if(!ClientPrefs.lowQuality){
					//Far Back Layer - Error (blue screen)
					var errorBG:FlxSprite = new FlxSprite(-600, -150).loadGraphic(Paths.image('hazard/qt-port/stage/streetError'));
					errorBG.antialiasing = ClientPrefs.globalAntialiasing;
					errorBG.scrollFactor.set(0.95, 0.95);
					errorBG.active = false;
					add(errorBG);

					//Back Layer - Error (glitched version of normal Back)
					streetBGerror = new FlxSprite(-750, -145).loadGraphic(Paths.image('hazard/qt-port/stage/streetBackError'));
					streetBGerror.antialiasing = ClientPrefs.globalAntialiasing;
					streetBGerror.scrollFactor.set(0.95, 0.95);
					add(streetBGerror);
				}

				//Back Layer - Normal
				streetBG = new FlxSprite(-750, -145).loadGraphic(Paths.image('hazard/qt-port/stage/streetBack'));
				streetBG.antialiasing = ClientPrefs.globalAntialiasing;
				streetBG.scrollFactor.set(0.95, 0.95);
				add(streetBG);


				//Front Layer - Normal
				var streetFront:FlxSprite = new FlxSprite(-820, 710).loadGraphic(Paths.image('hazard/qt-port/stage/streetFront'));
				streetFront.setGraphicSize(Std.int(streetFront.width * 1.15));
				streetFront.updateHitbox();
				streetFront.antialiasing = ClientPrefs.globalAntialiasing;
				streetFront.scrollFactor.set(0.95, 0.95);
				streetFront.active = false;
				add(streetFront);

				if(!ClientPrefs.lowQuality){
					//Front Layer - Error (changes to have a glow)
					streetFrontError = new FlxSprite(-820, 710).loadGraphic(Paths.image('hazard/qt-port/stage/streetFrontError'));
					streetFrontError.setGraphicSize(Std.int(streetFrontError.width * 1.15));
					streetFrontError.updateHitbox();
					streetFrontError.antialiasing = ClientPrefs.globalAntialiasing;
					streetFrontError.scrollFactor.set(0.95, 0.95);
					streetFrontError.active = false;
					add(streetFrontError);
					streetFrontError.visible = false;
				}

				qt_tv01 = new FlxSprite();
				qt_tv01.frames = Paths.getSparrowAtlas('hazard/qt-port/stage/TV_V5');
				qt_tv01.animation.addByPrefix('idle', 'TV_Idle', 24, true);
				qt_tv01.animation.addByPrefix('eye', 'TV_brutality', 24, true); //Replaced the hex eye with the brutality symbols for more accurate lore.
				qt_tv01.animation.addByPrefix('error', 'TV_Error', 24, true);	
				qt_tv01.animation.addByPrefix('404', 'TV_Bluescreen', 24, true);		
				qt_tv01.animation.addByPrefix('alert', 'TV_Attention', 36, false);		
				qt_tv01.animation.addByPrefix('drop', 'TV_Drop', 24, true);
				qt_tv01.animation.addByPrefix('sus', 'TV_sus', 24, true);
				qt_tv01.animation.addByPrefix('instructions', 'TV_Instructions-Normal', 24, true);
				qt_tv01.animation.addByPrefix('gl', 'TV_GoodLuck', 24, true);
				qt_tv01.animation.addByPrefix('heart', 'TV_End', 24, false);
				qt_tv01.animation.addByPrefix('watch', 'TV_Watchout', 24, true);
				qt_tv01.animation.addByPrefix('eyeRight', 'TV_eyeRight', 24, false);
				qt_tv01.animation.addByPrefix('eyeLeft', 'TV_eyeLeft', 24, false);
				qt_tv01.animation.addByPrefix('heart', 'TV_End', 24, false);
				qt_tv01.setPosition(-62, 540);
				qt_tv01.setGraphicSize(Std.int(qt_tv01.width * 1.2));
				qt_tv01.updateHitbox();
				qt_tv01.antialiasing = ClientPrefs.globalAntialiasing;
				qt_tv01.scrollFactor.set(0.9, 0.9);
				add(qt_tv01);
				qt_tv01.animation.play('idle');

			//Inhuman / Brutality Labs
			case 'depths': // yes
				
				forceMiddleScroll = true;
				disableDefaultCamZooming = true;
				discordDifficultyOverrideShouldUse = true;
				discordDifficultyOverride = "Trespasing";
				defaultCamZoom = 0.5;
				inhumanSong=true;
				introSkip = 48; //in seconds
				camHUD.visible=false;
				skipCountdown=true;
				disableArrowIntro = true;

				hazardBGkb = new FlxSprite();
				hazardBGkb.frames = Paths.getSparrowAtlas('hazard/inhuman-port/backPulsing'); //Before you start asking questions, yes, KB has a pulsing background in the Inhuman mod. I'm just reusing shit because I'm lazy lmao -Haz.
				hazardBGkb.animation.addByPrefix('pulse', 'kbBACK-pulse', 24, false);	
				hazardBGkb.x = -590;
				hazardBGkb.y = -250;
				hazardBGkb.antialiasing = ClientPrefs.globalAntialiasing;
				hazardBGkb.scrollFactor.set(1,1);
				hazardBGkb.setGraphicSize(Std.int(hazardBGkb.width * 1.1));
				hazardBGkb.updateHitbox();
				//hazardBGkb.alpha=0;
				hazardBGkb.animation.play('pulse');
				add(hazardBGkb);

				if(!ClientPrefs.lowQuality){
					wiggleShitShow = new WiggleEffect();
					wiggleShitShow.effectType = WiggleEffectType.DREAMY;
					wiggleShitShow.waveAmplitude = 0.013;
					wiggleShitShow.waveFrequency  = 4.4;
					wiggleShitShow.waveSpeed = 1;
					hazardBGkb.shader = wiggleShitShow.shader;
					//FlxG.camera.setFilters([new ShaderFilter(cast wiggleShitShow.shader)]);
					
					fogShitGroup = new FlxTypedGroup<FogThing>();
					//upper layer
					for (i in 0...20)
					{
						var fogShit:FogThing = new FogThing();
						fogShit.setPosition((i*204)-1250, FlxG.random.float(-6,18));
						fogShit.alpha = 0.3;
						fogShit.isUpperLayer = true;
						fogShit.updateHitbox();
						fogShitGroup.add(fogShit);
					}
					//lower layer
					for (i in 0...20)
					{
						var fogShit:FogThing = new FogThing();
						fogShit.setPosition((i*204)-1250, 50 + FlxG.random.float(-24,24));
						fogShit.alpha = 0.49;
						fogShit.isUpperLayer = false;
						fogShit.updateHitbox();
						fogShitGroup.add(fogShit);
					}
					/*
					fogShitDEBUG = new FogThing(-1250,250);
					fogShitDEBUG.updateHitbox();
					add(fogShitDEBUG);
					fogShitGroup.add(fogShitDEBUG);
					*/
					add(fogShitGroup);

					hazardInterlopeLaugh = new FlxSprite();
					hazardInterlopeLaugh.frames = Paths.getSparrowAtlas('hazard/inhuman-port/ameliaTaunt');
					hazardInterlopeLaugh.animation.addByPrefix('laugh1', 'Amelia_Chuckle', 24, true);	
					hazardInterlopeLaugh.animation.addByPrefix('laugh2', 'Amelia_Laugh', 30, true);	
					hazardInterlopeLaugh.antialiasing = ClientPrefs.globalAntialiasing;
					hazardInterlopeLaugh.setGraphicSize(Std.int(hazardInterlopeLaugh.width * 1.3));				
					hazardInterlopeLaugh.screenCenter();
					hazardInterlopeLaugh.x += 272;
					hazardInterlopeLaugh.y += 260;
					hazardInterlopeLaugh.animation.play("laugh1");
					hazardInterlopeLaugh.alpha=0;
					add(hazardInterlopeLaugh);
				}

				hazardBlack = new BGSprite(null, -FlxG.width, -FlxG.height, 0, 0);
				hazardBlack.makeGraphic(Std.int(FlxG.width * 3), Std.int(FlxG.height * 3), FlxColor.BLACK);
				hazardBlack.alpha = 1;
				hazardBlack.cameras = [camOther];
				add(hazardBlack);

				camHUD.visible=true;
				camHUD.alpha = 0;

				/*
				if(!ClientPrefs.lowQuality){
					wiggleShitShow = new WiggleEffect();
					wiggleShitShow.effectType = WiggleEffectType.WAVY;
					wiggleShitShow.waveAmplitude = 0.015;
					wiggleShitShow.waveFrequency  = 4.5;
					wiggleShitShow.waveSpeed = 1;
					hazardBG.shader = wiggleShitShow.shader;

					wiggleShitShowCAMERA = new WiggleEffect();
					wiggleShitShowCAMERA.effectType = WiggleEffectType.DREAMY;
					wiggleShitShowCAMERA.waveAmplitude = 0.015;
					wiggleShitShowCAMERA.waveFrequency  = 4.5;
					wiggleShitShowCAMERA.waveSpeed = 1;
					camHUD.setFilters([new ShaderFilter(cast wiggleShitShowCAMERA.shader)]);
				}		
				*/	
		}

		//Moved gas effect to be useable across all songs!
		if(!ClientPrefs.lowQuality){
			//Probably a better way of doing this... too bad! -Haz
			qt_gas01 = new FlxSprite();
			//Old gas sprites.
			//qt_gas01.frames = Paths.getSparrowAtlas('stage/gas_test');
			//qt_gas01.animation.addByPrefix('burst', 'ezgif.com-gif-makernew_gif instance ', 30, false);	

			//Left gas
			qt_gas01.frames = Paths.getSparrowAtlas('hazard/qt-port/stage/Gas_Release');
			qt_gas01.animation.addByPrefix('burst', 'Gas_Release', 38, false);	
			qt_gas01.animation.addByPrefix('burstALT', 'Gas_Release', 49, false);
			qt_gas01.animation.addByPrefix('burstFAST', 'Gas_Release', 76, false);	
			qt_gas01.setGraphicSize(Std.int(qt_gas01.width * 2.5));	
			qt_gas01.antialiasing = true;
			qt_gas01.scrollFactor.set();
			qt_gas01.alpha = 0.72;
			qt_gas01.setPosition(-880,-100);
			qt_gas01.angle = -31;				

			//Right gas
			qt_gas02 = new FlxSprite();
			//qt_gas02.frames = Paths.getSparrowAtlas('stage/gas_test');
			//qt_gas02.animation.addByPrefix('burst', 'ezgif.com-gif-makernew_gif instance ', 30, false);

			qt_gas02.frames = Paths.getSparrowAtlas('hazard/qt-port/stage/Gas_Release');
			qt_gas02.animation.addByPrefix('burst', 'Gas_Release', 38, false);	
			qt_gas02.animation.addByPrefix('burstALT', 'Gas_Release', 49, false);
			qt_gas02.animation.addByPrefix('burstFAST', 'Gas_Release', 76, false);	
			qt_gas02.setGraphicSize(Std.int(qt_gas02.width * 2.5));
			qt_gas02.antialiasing = true;
			qt_gas02.scrollFactor.set();
			qt_gas02.alpha = 0.72;
			qt_gas02.setPosition(920,-100);
			qt_gas02.angle = 31;
		}

		//Made Terminate have the same intro as Termination to freak even more people out LMAO.
		if(SONG.song.toLowerCase()=="terminate")
			disableArrowIntro = true;

		//Adding sawblades and pincers to every song so all songs can use them!
		if(ClientPrefs.flashing){
			hazardOverlayShit = new BGSprite('hazard/inhuman-port/alert-vignette');
			hazardOverlayShit.setGraphicSize(FlxG.width, FlxG.height);
			hazardOverlayShit.screenCenter();
			hazardOverlayShit.x += (FlxG.width/2) - 60; //Mmmmmm scuffed positioning, my favourite!
			hazardOverlayShit.y += (FlxG.height/2) - 20;
			hazardOverlayShit.updateHitbox();
			hazardOverlayShit.alpha=0;
			hazardOverlayShit.cameras = [camOther];
			add(hazardOverlayShit);
		}

		//Alert!
		kb_attack_alert = new FlxSprite();
		kb_attack_alert.frames = Paths.getSparrowAtlas('hazard/qt-port/attack_alert_NEW');
		kb_attack_alert.animation.addByPrefix('alert', 'kb_attack_animation_alert-single', 24, false);	
		kb_attack_alert.animation.addByPrefix('alertDOUBLE', 'kb_attack_animation_alert-double', 24, false);	
		kb_attack_alert.animation.addByPrefix('alertTRIPLE', 'kb_attack_animation_alert-triple', 24, false);	
		kb_attack_alert.animation.addByPrefix('alertQUAD', 'kb_attack_animation_alert-quad', 24, false);	
		kb_attack_alert.antialiasing = ClientPrefs.globalAntialiasing;
		kb_attack_alert.setGraphicSize(Std.int(kb_attack_alert.width * 1.5));
		kb_attack_alert.cameras = [camHUD];
		kb_attack_alert.x = FlxG.width - 700;
		kb_attack_alert.y = 205;
		//kb_attack_alert.animation.play("alert"); //Placeholder, change this to start already hidden or whatever.

		//Saw that one coming!
		kb_attack_saw = new FlxSprite();
		kb_attack_saw.frames = Paths.getSparrowAtlas('hazard/qt-port/attackv6');
		kb_attack_saw.animation.addByPrefix('fire', 'kb_attack_animation_fire', 24, false);	
		kb_attack_saw.animation.addByPrefix('prepare', 'kb_attack_animation_prepare', 24, false);	
		kb_attack_saw.setGraphicSize(Std.int(kb_attack_saw.width * 1.15));
		kb_attack_saw.antialiasing = ClientPrefs.globalAntialiasing;
		kb_attack_saw.setPosition(-860,630);

		sawbladeHits = 0;
		tauntCounter = 0;

		pincer1 = new FlxSprite(0, 0).loadGraphic(Paths.image('hazard/qt-port/pincer-close'));
		pincer2 = new FlxSprite(0, 0).loadGraphic(Paths.image('hazard/qt-port/pincer-close'));
		pincer3 = new FlxSprite(0, 0).loadGraphic(Paths.image('hazard/qt-port/pincer-close'));
		pincer4 = new FlxSprite(0, 0).loadGraphic(Paths.image('hazard/qt-port/pincer-close'));

		for (sprite in pincers = [pincer1, pincer2, pincer3, pincer4])
		{
			sprite.antialiasing = ClientPrefs.globalAntialiasing;
			sprite.scrollFactor.set();
			if (ClientPrefs.downScroll)
			{
				sprite.angle = 270;
				sprite.offset.set(192, -75);
			}
			else
			{
				sprite.angle = 90;
				sprite.offset.set(218, 240);
			}
		}

		//For the 'alarm' effect. Only added if flashling lights is allowed and low quality is off.
		// For the 'alarm' effect. Only added if flashling lights is allowed and low quality is off.
		if (ClientPrefs.flashing && !ClientPrefs.lowQuality)
		{
			hazardAlarmLeft = new BGSprite('hazard/inhuman-port/back-Gradient', -600, -480, 0.5, 0.5);
			hazardAlarmRight = new BGSprite('hazard/inhuman-port/back-Gradient', -600, -480, 0.5, 0.5);
			for (sprite in [hazardAlarmLeft, hazardAlarmRight])
			{
				sprite.setGraphicSize(Std.int(sprite.width * 1.1));
				sprite.updateHitbox();
				sprite.alpha = 0;
				sprite.cameras = [camOther];
				sprite.x -= 85;
			}
			hazardAlarmRight.flipX = true;
			add(hazardAlarmLeft);
			add(hazardAlarmRight);
		}

		if(curStage != 'depths'){
			add(gfGroup);

			// Shitty layering but whatev it works LOL
			if (curStage == 'limo')
				add(limo);

			add(dadGroup);
			add(boyfriendGroup);

			if(curStage == 'spooky') {
				add(halloweenWhite);
			}
		}

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end


		// "GLOBAL" SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('scripts/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/scripts/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end
		

		// STAGE SCRIPTS
		#if (MODS_ALLOWED && LUA_ALLOWED)
		var doPush:Bool = false;
		var luaFile:String = 'stages/' + curStage + '.lua';
		if(FileSystem.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaFile)) {
				doPush = true;
			}
		}

		if(doPush) 
			luaArray.push(new FunkinLua(luaFile));
		#end

		if(!modchartSprites.exists('blammedLightsBlack')) { //Creates blammed light black fade in case you didn't make your own
			blammedLightsBlack = new ModchartSprite(FlxG.width * -0.5, FlxG.height * -0.5);
			blammedLightsBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
			var position:Int = members.indexOf(gfGroup);
			if(members.indexOf(boyfriendGroup) < position) {
				position = members.indexOf(boyfriendGroup);
			} else if(members.indexOf(dadGroup) < position) {
				position = members.indexOf(dadGroup);
			}
			insert(position, blammedLightsBlack);

			blammedLightsBlack.wasAdded = true;
			modchartSprites.set('blammedLightsBlack', blammedLightsBlack);
		}
		if(curStage == 'philly') insert(members.indexOf(blammedLightsBlack) + 1, phillyCityLightsEvent);
		blammedLightsBlack = modchartSprites.get('blammedLightsBlack');
		blammedLightsBlack.alpha = 0.0;

		var gfVersion:String = SONG.gfVersion;
		if(gfVersion == null || gfVersion.length < 1) {
			gfVersion = 'gf';
			SONG.gfVersion = gfVersion; //Fix for the Chart Editor
		}

		gf = new Character(0, 0, gfVersion);
		startCharacterPos(gf);
		gf.scrollFactor.set(0.95, 0.95);
		gfGroup.add(gf);
		startCharacterLua(gf.curCharacter);

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterLua(dad.curCharacter);
		
		boyfriend = new Boyfriend(0, 0, SONG.player1);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterLua(boyfriend.curCharacter);
		
		var camPos:FlxPoint = new FlxPoint(gf.getGraphicMidpoint().x, gf.getGraphicMidpoint().y);
		camPos.x += gf.cameraPosition[0];
		camPos.y += gf.cameraPosition[1];

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			gf.visible = false;
		}

		var file:String = Paths.json(songName + '/dialogue'); //Checks for json/Psych Engine dialogue
		if (OpenFlAssets.exists(file)) {
			dialogueJson = DialogueBoxPsych.parseDialogue(file);
		}

		var file:String = Paths.txt(songName + '/' + songName + 'Dialogue'); //Checks for vanilla/Senpai dialogue
		if (OpenFlAssets.exists(file)) {
			dialogue = CoolUtil.coolTextFile(file);
		}
		var doof:DialogueBox = new DialogueBox(false, dialogue);
		// doof.x += 70;
		// doof.y = FlxG.height * 0.5;
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = startNextDialogue;
		doof.skipDialogueThing = skipDialogue;

		Conductor.songPosition = -5000;

		strumLine = new FlxSprite(forceMiddleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if(ClientPrefs.downScroll) strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();

		var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = showTime;
		if(ClientPrefs.downScroll) timeTxt.y = FlxG.height - 44;

		if(ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.text = SONG.song;
		}
		updateTime = showTime;

		timeBarBG = new AttachedSprite('timeBar');
		timeBarBG.x = timeTxt.x;
		timeBarBG.y = timeTxt.y + (timeTxt.height / 4);
		timeBarBG.scrollFactor.set();
		timeBarBG.alpha = 0;
		timeBarBG.visible = showTime;
		timeBarBG.color = FlxColor.BLACK;
		timeBarBG.xAdd = -4;
		timeBarBG.yAdd = -4;
		add(timeBarBG);

		timeBar = new FlxBar(timeBarBG.x + 4, timeBarBG.y + 4, LEFT_TO_RIGHT, Std.int(timeBarBG.width - 8), Std.int(timeBarBG.height - 8), this,
			'songPercent', 0, 1);
		timeBar.scrollFactor.set();
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF);
		timeBar.numDivisions = 800; //How much lag this causes?? Should i tone it down to idk, 400 or 200?
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		add(timeTxt);
		timeBarBG.sprTracker = timeBar;

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);
		add(grpNoteSplashes);

		if(ClientPrefs.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		// startCountdown();

		generateSong(SONG.song);
		#if LUA_ALLOWED
		for (notetype in noteTypeMap.keys())
		{
			var luaToLoad:String = Paths.modFolders('custom_notetypes/' + notetype + '.lua');
			if(FileSystem.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('custom_notetypes/' + notetype + '.lua');
				if(FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
		}
		for (event in eventPushedMap.keys())
		{
			var luaToLoad:String = Paths.modFolders('custom_events/' + event + '.lua');
			if(FileSystem.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('custom_events/' + event + '.lua');
				if(FileSystem.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
		}
		#end
		noteTypeMap.clear();
		noteTypeMap = null;
		eventPushedMap.clear();
		eventPushedMap = null;

		// After all characters being loaded, it makes then invisible 0.01s later so that the player won't freeze when you change characters
		// add(strumLine);

		camFollow = new FlxPoint();
		camFollowPos = new FlxObject(0, 0, 1, 1);

		snapCamFollowToPos(camPos.x, camPos.y);
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		if (prevCamFollowPos != null)
		{
			camFollowPos = prevCamFollowPos;
			prevCamFollowPos = null;
		}
		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		// FlxG.camera.setScrollBounds(0, FlxG.width, 0, FlxG.height);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		FlxG.fixedTimestep = false;
		moveCameraSection(0);

		healthBarBG = new AttachedSprite('healthBar');
		healthBarBG.y = FlxG.height * 0.89;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.visible = !ClientPrefs.hideHud;
		healthBarBG.xAdd = -4;
		healthBarBG.yAdd = -4;
		add(healthBarBG);
		if(ClientPrefs.downScroll) healthBarBG.y = 0.11 * FlxG.height;

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 2);
		healthBar.scrollFactor.set();
		// healthBar
		healthBar.visible = !ClientPrefs.hideHud;
		healthBar.alpha = ClientPrefs.healthBarAlpha;
		add(healthBar);
		healthBarBG.sprTracker = healthBar;

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.hideHud;
		iconP1.alpha = ClientPrefs.healthBarAlpha;
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.hideHud;
		iconP2.alpha = ClientPrefs.healthBarAlpha;
		add(iconP2);
		reloadHealthBarColors();

		scoreTxt = new FlxText(0, healthBarBG.y + 36, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud;
		add(scoreTxt);

		botplayTxt = new FlxText(400, timeBarBG.y + 55, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		add(botplayTxt);
		if(ClientPrefs.downScroll) {
			botplayTxt.y = timeBarBG.y - 78;
		}

		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		notes.cameras = [camHUD];
		healthBar.cameras = [camHUD];
		healthBarBG.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];
		botplayTxt.cameras = [camHUD];
		timeBar.cameras = [camHUD];
		timeBarBG.cameras = [camHUD];
		timeTxt.cameras = [camHUD];
		doof.cameras = [camHUD];

		// if (SONG.song == 'South')
		// FlxG.camera.alpha = 0.7;
		// UI_camera.zoom = 1;

		// cameras = [FlxG.cameras.list[1]];
		startingSong = true;

		// SONG SPECIFIC SCRIPTS
		#if LUA_ALLOWED
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/' + Paths.formatToSongPath(SONG.song) + '/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('data/' + Paths.formatToSongPath(SONG.song) + '/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/data/' + Paths.formatToSongPath(SONG.song) + '/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
		#end
		
		var daSong:String = Paths.formatToSongPath(curSong);
		if (isStoryMode && !seenCutscene)
		{
			switch (daSong)
			{
				case "monster":
					var whiteScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
					add(whiteScreen);
					whiteScreen.scrollFactor.set();
					whiteScreen.blend = ADD;
					camHUD.visible = false;
					snapCamFollowToPos(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
					inCutscene = true;

					FlxTween.tween(whiteScreen, {alpha: 0}, 1, {
						startDelay: 0.1,
						ease: FlxEase.linear,
						onComplete: function(twn:FlxTween)
						{
							camHUD.visible = true;
							remove(whiteScreen);
							startCountdown();
						}
					});
					FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));
					gf.playAnim('scared', true);
					boyfriend.playAnim('scared', true);

				case "winter-horrorland":
					var blackScreen:FlxSprite = new FlxSprite().makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
					add(blackScreen);
					blackScreen.scrollFactor.set();
					camHUD.visible = false;
					inCutscene = true;

					FlxTween.tween(blackScreen, {alpha: 0}, 0.7, {
						ease: FlxEase.linear,
						onComplete: function(twn:FlxTween) {
							remove(blackScreen);
						}
					});
					FlxG.sound.play(Paths.sound('Lights_Turn_On'));
					snapCamFollowToPos(400, -2050);
					FlxG.camera.focusOn(camFollow);
					FlxG.camera.zoom = 1.5;

					new FlxTimer().start(0.8, function(tmr:FlxTimer)
					{
						camHUD.visible = true;
						remove(blackScreen);
						FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 2.5, {
							ease: FlxEase.quadInOut,
							onComplete: function(twn:FlxTween)
							{
								startCountdown();
							}
						});
					});
				case 'senpai' | 'roses' | 'thorns':
					if(daSong == 'roses') FlxG.sound.play(Paths.sound('ANGRY'));
					schoolIntro(doof);

				case 'carefree':
					FlxG.sound.playMusic(Paths.music('carefree-dialogue-loop'), 0);
					FlxG.sound.music.fadeIn(1, 0, 0.75);
					startDialogue(dialogueJson);

				case 'careless' | 'terminate':
					startDialogue(dialogueJson);
				
				//Careless, Cessation, and Terminate all have ending dialogue.

				case 'censory-overload':
					kbWakesUp();

				default:
					startCountdown();
			}
			seenCutscene = true;
		} else {
			startCountdown();
			epicStuff();
		}
		RecalculateRating();

		//PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		//BRUH DON'T WORRY, I HAVE NO FUCKING IDEA HOW HAXE WORKS EITHER -Haz
		CoolUtil.precacheSound('missnote1');
		CoolUtil.precacheSound('missnote2');
		CoolUtil.precacheSound('missnote3');

		introSkipSprite = new BGSprite('hazard/inhuman-port/skip-hint', -600, -480, 0.5, 0.5);
		introSkipSprite.setGraphicSize(Std.int(introSkipSprite.width * 2));
		introSkipSprite.updateHitbox();
		introSkipSprite.cameras = [camOther]; //Moved from HUD to OTHER so that the HUD shaders don't fuck over the text. Also so that it can appear without fading in at the start
		introSkipSprite.screenCenter();	

		#if desktop
		// Updating Discord Rich Presence.
		if(discordDifficultyOverrideShouldUse){
			DiscordClient.changePresence(detailsText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter());
		}else{
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
		#end

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}

		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000;
		callOnLuas('onCreatePost', []);
		
		super.create();

		Paths.clearUnusedMemory();
		CustomFadeTransition.nextCamera = camOther;
	}

	function kbWakesUp():Void
	{
		FlxG.sound.playMusic(Paths.music('spooky_ambience'), 0);
		FlxG.sound.music.fadeIn(1, 0, 0.75);
		if(ClientPrefs.qtSkipCutscene){
			startDialogue(dialogueJson);
		}else{
			//Lazily copy and pastes code from schoolIntro but in a cute way~ -Haz
			var black:FlxSprite = new FlxSprite(-300, -100).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			black.scrollFactor.set();
			var senpaiEvil:FlxSprite = new FlxSprite();
			var horrorStage:FlxSprite = new FlxSprite();
			camHUD.visible = false;
			//BG
			horrorStage.frames = Paths.getSparrowAtlas('hazard/qt-port/stage/horrorbg');
			horrorStage.animation.addByPrefix('idle', 'Symbol 10 instance ', 24, false);
			horrorStage.antialiasing = ClientPrefs.globalAntialiasing;
			horrorStage.scrollFactor.set();
			horrorStage.screenCenter();
			//QT sprite
			senpaiEvil.frames = Paths.getSparrowAtlas('hazard/qt-port/cutscenev3');
			senpaiEvil.animation.addByPrefix('idle', 'final_edited', 24, false);
			senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 0.875));
			senpaiEvil.scrollFactor.set();
			senpaiEvil.updateHitbox();
			senpaiEvil.screenCenter();
			senpaiEvil.x -= 140;
			senpaiEvil.y -= 55;
			add(horrorStage);
			inCutscene = true;

			new FlxTimer().start(0.3, function(tmr:FlxTimer)
			{
				black.alpha -= 0.125;
				if (black.alpha > 0)
				{
					tmr.reset(0.3);
				}
				else
				{
					add(senpaiEvil);
					senpaiEvil.alpha = 0;
					new FlxTimer().start(0.3, function(swagTimer:FlxTimer)
					{
						senpaiEvil.alpha += 0.15;
						if (senpaiEvil.alpha < 1)
						{
							swagTimer.reset();
						}
						else
						{
							senpaiEvil.animation.play('idle');
							horrorStage.animation.play('idle');
							FlxG.sound.play(Paths.sound('hazard/music-box-horror'), 0.9, false, null, true, function()
							{
								remove(senpaiEvil);
								remove(horrorStage);
								camHUD.visible = true;
								FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
								{
									startDialogue(dialogueJson);
								}, true);
							});
							new FlxTimer().start(13, function(deadTime:FlxTimer)
							{
								FlxG.camera.fade(FlxColor.WHITE, 3, false);
							});
						}
					});
					remove(black);
				}
			});
		}
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			for (note in notes)
			{
				if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
				{
					note.scale.y *= ratio;
					note.updateHitbox();
				}
			}
			for (note in unspawnNotes)
			{
				if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
				{
					note.scale.y *= ratio;
					note.updateHitbox();
				}
			}
		}
		songSpeed = value;
		noteKillOffset = 350 / songSpeed;
		return value;
	}

	public function addTextToDebug(text:String) {
		#if LUA_ALLOWED
		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup));
		#end
	}

	public function reloadHealthBarColors() {
		healthBar.createFilledBar(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
			
		healthBar.updateBar();
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Boyfriend = new Boyfriend(0, 0, newCharacter);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterLua(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterLua(newDad.curCharacter);
				}

			case 2:
				if(!gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterLua(newGf.curCharacter);
				}
		}
	}

	function startCharacterLua(name:String)
	{
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/' + name + '.lua';
		if(FileSystem.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaFile)) {
				doPush = true;
			}
		}
		
		if(doPush)
		{
			for (lua in luaArray)
			{
				if(lua.scriptName == luaFile) return;
			}
			luaArray.push(new FunkinLua(luaFile));
		}
		#end
	}

	
	
  public function addShaderToCamera(cam:String,effect:ShaderEffect){//STOLE FROM ANDROMEDA
		//Update v2.2 hotfix: Shaders now only work if the user enables them to avoid crashes.
		if(!ClientPrefs.noShaders){
			switch(cam.toLowerCase()) {
				case 'camhud' | 'hud':
						camHUD.filters.push(new ShaderFilter(effect.shader));
				case 'camother' | 'other':
						camOther.filters.push(new ShaderFilter(effect.shader));
				case 'camgame' | 'game':
						camGame.filters.push(new ShaderFilter(effect.shader));
				default:
					if(modchartSprites.exists(cam)) {
						Reflect.setProperty(modchartSprites.get(cam),"shader",effect.shader);
					} else if(modchartTexts.exists(cam)) {
						Reflect.setProperty(modchartTexts.get(cam),"shader",effect.shader);
					} else {
						var OBJ = Reflect.getProperty(PlayState.instance,cam);
						Reflect.setProperty(OBJ,"shader", effect.shader);
					}
				
				
					
					
			}	  
		}
  }

  public function removeShaderFromCamera(cam:String,effect:ShaderEffect){
	if(!ClientPrefs.noShaders){
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				if(camHUD.filters != null) {
					camHUD.filters.remove(camHUD.filters.filter(function(filter) return Std.isOfType(filter, ShaderFilter) && cast(filter, ShaderFilter).shader == effect.shader)[0]);
				}
			case 'camother' | 'other': 
				if(camOther.filters != null) {
					camOther.filters.remove(camOther.filters.filter(function(filter) return Std.isOfType(filter, ShaderFilter) && cast(filter, ShaderFilter).shader == effect.shader)[0]);
				}
			default:
				if(camGame.filters != null) {
					camGame.filters.remove(camGame.filters.filter(function(filter) return Std.isOfType(filter, ShaderFilter) && cast(filter, ShaderFilter).shader == effect.shader)[0]);
				}
		}
	}
  }
	
  //When testing with shaders, some seemed to flip the camera? This is here to hopefully counter it.
  public function flippyTime(cam:String){
	switch(cam.toLowerCase()) {
		case 'camhud' | 'hud': 
			camHUD.setScale(camHUD.scaleX * -1, camHUD.scaleY);
		case 'camother' | 'other': 
			camOther.setScale(camOther.scaleX * -1, camOther.scaleY);
		default: 
			camGame.setScale(camGame.scaleX * -1, camGame.scaleY);
	}
}
	
  public function clearShaderFromCamera(cam:String){
	  
	  
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': 
				camHUD.filters = [];
			case 'camother' | 'other': 
				camOther.filters = [];
			default: 
				camGame.filters = [];
		}
		
	  
  }
	
	
	
	
	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function startVideo(name:String):Void {
		#if VIDEOS_ALLOWED
		var foundFile:Bool = false;
		var fileName:String = #if MODS_ALLOWED Paths.modFolders('videos/' + name + '.' + Paths.VIDEO_EXT); #else ''; #end
		#if sys
		if(FileSystem.exists(fileName)) {
			foundFile = true;
		}
		#end

		if(!foundFile) {
			fileName = Paths.video(name);
			#if sys
			if(FileSystem.exists(fileName)) {
			#else
			if(OpenFlAssets.exists(fileName)) {
			#end
				foundFile = true;
			}
		}

		if(foundFile) {
			inCutscene = true;
			var bg = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			bg.scrollFactor.set();
			bg.cameras = [camHUD];
			add(bg);

			(new FlxVideo(fileName)).finishCallback = function() {
				remove(bg);
				startAndEnd();
			}
			return;
		}
		else
		{
			FlxG.log.warn('Couldnt find video file: ' + fileName);
			startAndEnd();
		}
		#end
		startAndEnd();
	}

	function startAndEnd()
	{
		if(endingSong){
			endSong();
			//trace("EndSong triggerd from Start And End");
		}
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(dialogueJson);" and it should work
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			CoolUtil.precacheSound('dialogue/dialogue');
			CoolUtil.precacheSound('dialogue/generic');
			CoolUtil.precacheSound('dialogue/kb');
			CoolUtil.precacheSound('dialogue/qt');
			CoolUtil.precacheSound('dialogue/gf');
			CoolUtil.precacheSound('dialogue/bf');
			CoolUtil.precacheSound('dialogue/qt_error');
			CoolUtil.precacheSound('dialogue/dialogueClose');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					if(SONG.song.toLowerCase()=="cessation")
						endScreenHazard();
					else{
						endSong();
						//trace("endSong triggerd from Dialogue top");
					}
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			if(endingSong) {
				if(SONG.song.toLowerCase()=="cessation")
					endScreenHazard();
				else{
					endSong();
					//trace("endSong triggerd from Dialogue bottom");
				}
			} else {
				if(SONG.song.toLowerCase()== 'carefree' || SONG.song.toLowerCase()=='censory-overload'){
					FlxG.sound.music.fadeOut(1.5, 0);
				}
				startCountdown();
			}
		}
	}

	function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		inCutscene = true;
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		add(black);

		var red:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();

		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.getSparrowAtlas('weeb/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();
		senpaiEvil.x += 300;

		var songName:String = Paths.formatToSongPath(SONG.song);
		if (songName == 'roses' || songName == 'thorns')
		{
			remove(black);

			if (songName == 'thorns')
			{
				add(red);
				camHUD.visible = false;
			}
		}

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;

			if (black.alpha > 0)
			{
				tmr.reset(0.3);
			}
			else
			{
				if (dialogueBox != null)
				{
					if (Paths.formatToSongPath(SONG.song) == 'thorns')
					{
						add(senpaiEvil);
						senpaiEvil.alpha = 0;
						new FlxTimer().start(0.3, function(swagTimer:FlxTimer)
						{
							senpaiEvil.alpha += 0.15;
							if (senpaiEvil.alpha < 1)
							{
								swagTimer.reset();
							}
							else
							{
								senpaiEvil.animation.play('idle');
								FlxG.sound.play(Paths.sound('Senpai_Dies'), 1, false, null, true, function()
								{
									remove(senpaiEvil);
									remove(red);
									FlxG.camera.fade(FlxColor.WHITE, 0.01, true, function()
									{
										add(dialogueBox);
										camHUD.visible = true;
									}, true);
								});
								new FlxTimer().start(3.2, function(deadTime:FlxTimer)
								{
									FlxG.camera.fade(FlxColor.WHITE, 1.6, false);
								});
							}
						});
					}
					else
					{
						add(dialogueBox);
					}
				}
				else
					startCountdown();

				remove(black);
			}
		});
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	public function startCountdown():Void
	{
		if(startedCountdown) {
			callOnLuas('onStartCountdown', []);
			return;
		}

		inCutscene = false;
		var ret:Dynamic = callOnLuas('onStartCountdown', []);
		if(ret != FunkinLua.Function_Stop) {
			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...playerStrums.length) {
				setOnLuas('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnLuas('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnLuas('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnLuas('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = 0;
			Conductor.songPosition -= Conductor.crochet * 5;
			setOnLuas('startedCountdown', true);
			callOnLuas('onCountdownStarted', []);

			var swagCounter:Int = 0;

			if (skipCountdown){
				Conductor.songPosition = 0;
				Conductor.songPosition -= Conductor.crochet ;
				swagCounter = 3;
				camHUD.visible=true;
			}
			startTimer = new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
			{
				if (!gfScared && tmr.loopsLeft % gfSpeed == 0 && !gf.stunned && gf.animation.curAnim.name != null && !gf.animation.curAnim.name.startsWith("sing"))
				{
					gf.dance();
				}
				if(tmr.loopsLeft % 2 == 0) {
					if (boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !bfDodging && !boyfriend.stunned)
					{
						boyfriend.dance();
					}
					if (dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
					{
						dad.dance();
					}
				}
				else if(dad.danceIdle && dad.animation.curAnim != null && !dad.stunned && !dad.curCharacter.startsWith('gf') && !dad.animation.curAnim.name.startsWith("sing"))
				{
					dad.dance();
				}

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				introAssets.set('default', ['ready', 'set', 'go']);
				introAssets.set('pixel', ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel']);

				var introAlts:Array<String> = introAssets.get('default');
				var antialias:Bool = ClientPrefs.globalAntialiasing;
				if(isPixelStage) {
					introAlts = introAssets.get('pixel');
					antialias = false;
				}

				// head bopping for bg characters on Mall
				if(curStage == 'mall') {
					if(!ClientPrefs.lowQuality)
						upperBoppers.dance(true);
	
					bottomBoppers.dance(true);
					santa.dance(true);
				}

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
					case 1:
						countdownReady = new FlxSprite().loadGraphic(Paths.image(introAlts[0]));
						countdownReady.scrollFactor.set();
						countdownReady.updateHitbox();

						if (PlayState.isPixelStage)
							countdownReady.setGraphicSize(Std.int(countdownReady.width * daPixelZoom));

						countdownReady.screenCenter();
						countdownReady.antialiasing = antialias;
						add(countdownReady);
						FlxTween.tween(countdownReady, {/*y: countdownReady.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownReady);
								countdownReady.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
					case 2:
						countdownSet = new FlxSprite().loadGraphic(Paths.image(introAlts[1]));
						countdownSet.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownSet.setGraphicSize(Std.int(countdownSet.width * daPixelZoom));

						countdownSet.screenCenter();
						countdownSet.antialiasing = antialias;
						add(countdownSet);
						FlxTween.tween(countdownSet, {/*y: countdownSet.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownSet);
								countdownSet.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
					case 3:
						if (!skipCountdown){
						countdownGo = new FlxSprite().loadGraphic(Paths.image(introAlts[2]));
						countdownGo.scrollFactor.set();

						if (PlayState.isPixelStage)
							countdownGo.setGraphicSize(Std.int(countdownGo.width * daPixelZoom));

						countdownGo.updateHitbox();

						countdownGo.screenCenter();
						countdownGo.antialiasing = antialias;
						add(countdownGo);
						FlxTween.tween(countdownGo, {/*y: countdownGo.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
							ease: FlxEase.cubeInOut,
							onComplete: function(twn:FlxTween)
							{
								remove(countdownGo);
								countdownGo.destroy();
							}
						});
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
						}
					case 4:
				}

				notes.forEachAlive(function(note:Note) {
					note.copyAlpha = false;
					note.alpha = note.multAlpha;
					if(forceMiddleScroll && !note.mustPress && note.noteType == null) {
						note.alpha *= 0.5;
					}
				});
				callOnLuas('onCountdownTick', [swagCounter]);

				swagCounter += 1;
				// generateSong('fresh');
			}, 5);
		}
	}

	function startNextDialogue() {
		dialogueCount++;
		callOnLuas('onNextDialogue', [dialogueCount]);
	}

	function skipDialogue() {
		callOnLuas('onSkipDialogue', [dialogueCount]);
	}

	var previousFrameTime:Int = 0;
	var lastReportedPlayheadPosition:Int = 0;
	var songTime:Float = 0;

	function startSong():Void
	{
		if(introSkip>0 && deathCounter > 0) {
			introSkipSprite.alpha=0;
			add(introSkipSprite);
			//Make introskipsprite fade in because it looks nicer
			FlxTween.tween(introSkipSprite, {alpha: 0.49}, 1.25);
			new FlxTimer().start(5, function(tmr:FlxTimer)
			{
				FlxTween.tween(introSkipSprite, {alpha:0.08}, 1.5, {ease: FlxEase.quadInOut });
			});
		}

		for (i in 0...playerStrums.length) {
			hazardModChartDefaultStrumX[i] = opponentStrums.members[i].x;
			hazardModChartDefaultStrumY[i] = opponentStrums.members[i].y;

			hazardModChartDefaultStrumX[i+4] = playerStrums.members[i].x;
			hazardModChartDefaultStrumY[i+4] = playerStrums.members[i].y;

			//trace("Strum1 X = ", hazardModChartDefaultStrumX[i+4]);
		}

		hazardRandom = FlxG.random.int(1, 5);
		FlxG.log.notice(('Cessation Random Roll:' + hazardRandom));

		if(SONG.song.toLowerCase() == "interlope"){ 
			remove(hazardBlack); //Layering moment LMAO
			add(hazardBlack);
			
			//Shaders? Pog
			if(!ClientPrefs.lowQuality && !ClientPrefs.noShaders){
				//Disables with flashing lights just to be safe.
				if(ClientPrefs.flashing){
					interlopeChroma = new ChromaticAberrationEffect(0);
					addShaderToCamera("hud", interlopeChroma);
				}
				interlopeFadeinShader = new TiltshiftEffect(4,0);
				addShaderToCamera("hud", interlopeFadeinShader);
				
				addShaderToCamera("hud", new GrainEffect(0.575,2,true));
				addShaderToCamera("game", new GrainEffect(1.1,0.95,true));
			}		
			for (i in 0...opponentStrums.length) {
				opponentStrums.members[i].alpha = 0;
				opponentStrums.members[i].x = hazardModChartDefaultStrumX[i+4];
				//FlxTween.tween(i, {alpha: 0}, 0.5, {ease: FlxEase.linear});
			}
			for (i in 0...playerStrums.length){
				playerStrums.members[i].angle=360;
				playerStrums.members[i].x -= 90;
				playerStrums.members[i].y += ClientPrefs.downScroll ? -130 : 130;
			}
			interlopeIntroTween = FlxTween.tween(hazardBlack, {alpha: 0.5}, 24, {onComplete: function(twn:FlxTween){interlopeIntroTween = null;}});

			interlopeIntroTweenHUD = FlxTween.tween(camHUD, {alpha: 1}, 24, {onComplete: function(twn:FlxTween){interlopeIntroTweenHUD = null;}});

		}else if (SONG.song.toLowerCase() == 'censory-overload') {
			gfSpeed = 2;
		}//else if (SONG.song.toLowerCase() == "termination") {
			/*
			qt_tv01.animation.play("instructions");
			FlxG.camera.shake(0.003,1);
			camHUD.shake(0.003,1);
			if(ClientPrefs.downScroll){
				strumLineNotes.members[0].y-20;
				strumLineNotes.members[7].y-20;
			}else{
				strumLineNotes.members[0].y+20;
				strumLineNotes.members[7].y+20;
			}
			FlxTween.tween(strumLineNotes.members[0], {y: hazardModChartDefaultStrumY[0], alpha: 1}, 1.22, {ease: FlxEase.cubeOut});
			FlxTween.tween(strumLineNotes.members[7], {y: hazardModChartDefaultStrumY[7], alpha: 1}, 1.22, {ease: FlxEase.cubeOut});
			*/
			//bfCanDodge = true;
		//}

		if(SONG.dodgeEnabled)
			bfCanDodge = true;

		if(!ClientPrefs.lowQuality){
			add(qt_gas01);
			add(qt_gas02);
		}

		startingSong = false;

		previousFrameTime = FlxG.game.ticks;
		lastReportedPlayheadPosition = 0;

		//Use this path for classic termination
		if(Paths.formatToSongPath(SONG.song) == 'termination' && storyDifficulty==2){
			trace("USING TERMINATION OLD INST");
			FlxG.sound.playMusic(Paths.instOLD(PlayState.SONG.song), 1, false);
		}else{
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
		}
		//FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
		FlxG.sound.music.onComplete = finishSong;
		vocals.play();

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		if(SONG.song.toLowerCase() == "terminate") //Fakes the timebar
			songLength=316219;
		//trace("I wonder what the length of this song is? ", songLength);
		//Termination returns 316219
		//Tutorial returns 67213
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		
		#if desktop
		// Updating Discord Rich Presence (with Time Left)
		if(discordDifficultyOverrideShouldUse){
			DiscordClient.changePresence(detailsText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter(), true, songLength);
		}else{
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		}
		
		#end
		setOnLuas('songLength', songLength);
		callOnLuas('onSongStart', []);
	}

	var debugNum:Int = 0;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	private var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
	private function generateSong(dataPath:String):Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}
		
		var songData = SONG;
		Conductor.changeBPM(songData.bpm);
		
		curSong = songData.song;

		if (SONG.needsVoices)
			//Use this path for classic termination
			if(Paths.formatToSongPath(SONG.song) == 'termination' && storyDifficulty==2){
				vocals = new FlxSound().loadEmbedded(Paths.voicesOLD(PlayState.SONG.song));
			}else{
				if(ClientPrefs.qtOldVocals && Paths.formatToSongPath(SONG.song) != 'interlope'){
					vocals = new FlxSound().loadEmbedded(Paths.voicesCLASSIC(PlayState.SONG.song));
				}else{
					vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
				}
			}
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(vocals);

		//Use this path for classic termination
		//I don't even know what the fuck this even is lmao
		if(Paths.formatToSongPath(SONG.song) == 'termination' && storyDifficulty==2){
			trace("USING TERMINATION OLD INST (dafuq)");
			FlxG.sound.list.add(new FlxSound().loadEmbedded(Paths.instOLD(PlayState.SONG.song)));
		}else{
			FlxG.sound.list.add(new FlxSound().loadEmbedded(Paths.inst(PlayState.SONG.song)));
		}

		notes = new FlxTypedGroup<Note>();
		add(notes);

		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

		var songName:String = Paths.formatToSongPath(SONG.song);
		var file:String = Paths.json(songName + '/events');
		#if sys
		if (FileSystem.exists(Paths.modsJson(songName + '/events')) || FileSystem.exists(file)) {
		#else
		if (OpenFlAssets.exists(file)) {
		#end
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) //Event Notes
			{
				for (i in 0...event[1].length)
				{
					var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
					var subEvent:Array<Dynamic> = [newEventNote[0] + ClientPrefs.noteOffset - eventNoteEarlyTrigger(newEventNote), newEventNote[1], newEventNote[2], newEventNote[3]];
					eventNotes.push(subEvent);
					eventPushed(subEvent);
				}
			}
		}

		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);

				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] > 3)
				{
					gottaHitNote = !section.mustHitSection;
				}

				var oldNote:Note;
				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				swagNote.noteType = songNotes[3];
				if(!Std.isOfType(songNotes[3], String)) swagNote.noteType = editors.ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts
				
				swagNote.scrollFactor.set();

				var susLength:Float = swagNote.sustainLength;

				susLength = susLength / Conductor.stepCrochet;
				unspawnNotes.push(swagNote);

				var floorSus:Int = Math.floor(susLength);
				if(floorSus > 0) {
					for (susNote in 0...floorSus+1)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(songSpeed, 2)), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1]<4));
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						unspawnNotes.push(sustainNote);

						if (sustainNote.mustPress)
						{
							sustainNote.x += FlxG.width / 2; // general offset
						}
						else if(forceMiddleScroll)
						{
							sustainNote.x += 310;
							if(daNoteData > 1) //Up and Right
							{
								sustainNote.x += FlxG.width / 2 + 25;
							}
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(forceMiddleScroll)
				{
					swagNote.x += 310;
					if(daNoteData > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}

				if(!noteTypeMap.exists(swagNote.noteType)) {
					noteTypeMap.set(swagNote.noteType, true);
				}
			}
			daBeats += 1;
		}
		for (event in songData.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
				var subEvent:Array<Dynamic> = [newEventNote[0] + ClientPrefs.noteOffset - eventNoteEarlyTrigger(newEventNote), newEventNote[1], newEventNote[2], newEventNote[3]];
				eventNotes.push(subEvent);
				eventPushed(subEvent);
			}
		}

		// trace(unspawnNotes.length);
		// playerCounter += 1;

		unspawnNotes.sort(sortByShit);
		if(eventNotes.length > 1) { //No need to sort if there's a single one or none at all
			eventNotes.sort(sortByTime);
		}
		checkEventNote();
		generatedMusic = true;
	}

	function eventPushed(event:Array<Dynamic>) {
		switch(event[1]) {
			case 'Change Character OPTIONAL':
				if(!ClientPrefs.lowQuality){
					var charType:Int = 0;
					switch(event[2].toLowerCase()) {
						case 'gf' | 'girlfriend' | '1':
							charType = 2;
						case 'dad' | 'opponent' | '0':
							charType = 1;
						default:
							charType = Std.parseInt(event[2]);
							if(Math.isNaN(charType)) charType = 0;
					}

					var newCharacter:String = event[3];
					addCharacterToList(newCharacter, charType);
				}

			case 'Change Character':
				var charType:Int = 0;
				switch(event[2].toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						charType = Std.parseInt(event[2]);
						if(Math.isNaN(charType)) charType = 0;
				}

				var newCharacter:String = event[3];
				addCharacterToList(newCharacter, charType);
		}

		if(!eventPushedMap.exists(event[1])) {
			eventPushedMap.set(event[1], true);
		}
	}

	function eventNoteEarlyTrigger(event:Array<Dynamic>):Float {
		var returnedValue:Float = callOnLuas('eventEarlyTrigger', [event[1]]);
		if(returnedValue != 0) {
			return returnedValue;
		}

		switch(event[1]) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position

			//These events are called early so that the sound effects they play remain synced to the music with people playing with note offset.
			//However, the actual mechanics are put on a timer so that they can still be synced to the charting.
			case 'KB_Alert' | 'KB_AlertDouble' | 'KB_AttackPrepare' | 'KB_AttackFire' | 'KB_AttackFireDOUBLE':
				if(ClientPrefs.noteOffset <= 0) {
					return 0;
				} else {
					return ClientPrefs.noteOffset;
				}
				 
		}
		return 0;
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
			if (player < 1 && forceMiddleScroll) targetAlpha = 0.35;

			var babyArrow:StrumNote = new StrumNote(forceMiddleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player);
			babyArrow.downScroll = ClientPrefs.downScroll;

			if(!disableArrowIntro){
				if (!isStoryMode)
				{
					babyArrow.y -= 10;
					babyArrow.alpha = 0;
					FlxTween.tween(babyArrow, {y: babyArrow.y + 10, alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
				}
				else
				{
					babyArrow.alpha = targetAlpha;
				}
			}else{
				babyArrow.alpha = 0;
			}

			if (player == 1)
			{
				playerStrums.add(babyArrow);
			}
			else
			{
				if(forceMiddleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	function openSubStatePauseShit(){
		if (paused)
			{
				if (FlxG.sound.music != null)
				{
					FlxG.sound.music.pause();
					vocals.pause();
				}
	
				if (!startTimer.finished)
					startTimer.active = false;
				if (finishTimer != null && !finishTimer.finished)
					finishTimer.active = false;
				if (songSpeedTween != null)
					songSpeedTween.active = false;
				
				if(interlopeIntroTween != null)
					interlopeIntroTween.active = false;

				if(interlopeIntroTweenHUD != null)
					interlopeIntroTweenHUD.active = false;
	
				if(blammedLightsBlackTween != null)
					blammedLightsBlackTween.active = false;
				if(phillyCityLightsEventTween != null)
					phillyCityLightsEventTween.active = false;
	
				if(carTimer != null) carTimer.active = false;
	
				var chars:Array<Character> = [boyfriend, gf, dad];
				for (i in 0...chars.length) {
					if(chars[i].colorTween != null) {
						chars[i].colorTween.active = false;
					}
				}
	
				for (tween in modchartTweens) {
					tween.active = false;
				}
				for (tween in interlopeIntroTweens){
					tween.active = false;
				}
				for (timer in modchartTimers) {
					timer.active = false;
				}
			}
	}

	override function openSubState(SubState:FlxSubState)
	{
		openSubStatePauseShit();
		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
			{
				resyncVocals();
			}

			if (!startTimer.finished)
				startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;

			if(blammedLightsBlackTween != null)
				blammedLightsBlackTween.active = true;
			if(phillyCityLightsEventTween != null)
				phillyCityLightsEventTween.active = true;
			
			if(carTimer != null) carTimer.active = true;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (i in 0...chars.length) {
				if(chars[i].colorTween != null) {
					chars[i].colorTween.active = true;
				}
			}

			if(interlopeIntroTween != null)
				interlopeIntroTween.active = true;

			if(interlopeIntroTweenHUD != null)
				interlopeIntroTweenHUD.active = true;
			
			for (tween in modchartTweens) {
				tween.active = true;
			}
			for (tween in interlopeIntroTweens){
				tween.active = true;
			}
			for (timer in modchartTimers) {
				timer.active = true;
			}
			paused = false;
			callOnLuas('onResume', []);

			#if desktop
			if(discordDifficultyOverrideShouldUse){
				if (startTimer.finished)
				{
					DiscordClient.changePresence(detailsText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
				}
				else
				{
					DiscordClient.changePresence(detailsText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter());
				}
			}else{
				if (startTimer.finished)
				{
					DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
				}
				else
				{
					DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				}
			}
			#end
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		#if desktop
		if (health > 0 && !paused)
		{
			if (Conductor.songPosition > 0.0)
			{
				if(discordDifficultyOverrideShouldUse)
					DiscordClient.changePresence(detailsText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.noteOffset);
				else
					DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
			else
			{
				if(discordDifficultyOverrideShouldUse)
					DiscordClient.changePresence(detailsText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter());
				else
					DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			}
		}
		#end

		super.onFocus();
	}
	
	override public function onFocusLost():Void
	{
		#if desktop
		if (health > 0 && !paused)
		{
			if(discordDifficultyOverrideShouldUse)
				DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter());
			else
				DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
		#end

		super.onFocusLost();
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		vocals.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();
	}

	public var paused:Bool = false;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var limoSpeed:Float = 0;

	override public function update(elapsed:Float)
	{
		/*if (FlxG.keys.justPressed.NINE)
		{
			iconP1.swapOldIcon();
		}*/

		callOnLuas('onUpdate', [elapsed]);

		if(hazardOverlayShit != null){
			if(hazardOverlayShit.alpha > 0) //Seperate if check because I'm paranoid of a crash -Haz
				hazardOverlayShit.alpha -= 1.2 * elapsed;
		}
		if(interlopeChroma != null){
			if(interlopeChromaIntensity > 0){
				//Effect is reduced at a much faster rate for swapping bullshit
				if(hazardModChartEffect == 5 || hazardModChartEffect == 3)
					interlopeChromaIntensity -= 0.082 * elapsed;
				else
					interlopeChromaIntensity -= 0.044 * elapsed;
			}
			else if(interlopeChromaIntensity < 0) 
				interlopeChromaIntensity = 0; //Stop going below zero

			interlopeChroma.setChrome(interlopeChromaIntensity);
		}

		if(interlopeFadeinShader != null){
			if(interlopeFadeinShaderFading){
				if(interlopeFadeinShaderIntensity > 0){
					interlopeFadeinShaderIntensity -= 0.208 * elapsed;
				}
				else if(interlopeFadeinShaderIntensity < 0) {
					interlopeFadeinShaderIntensity = 0; //Stop going below zero	
					interlopeFadeinShaderFading=false;
				}	
			}
			interlopeFadeinShader.setTiltShit(interlopeFadeinShaderIntensity);
		}

		if(wiggleShitShow != null)
		{
			wiggleShitShow.update(elapsed);
		}
		if(wiggleShitShowCAMERA != null)
		{
			wiggleShitShowCAMERA.update(elapsed);
		}
	
			/*
			if(hazardModChartEffectWave == 1){
				var strumYforWave:Float;
				if(isDownscroll)
					strumYforWave = FlxG.height - 150;
				else
					strumYforWave = 50;
	
				for (i in 0...playerStrums.length) {
					playerStrums.members[i].y = FlxMath.lerp(
						strumYforWave, 
							strumYforWave + (Math.sin(((Conductor.songPosition/300) + (i*0.2) )*Math.PI) * 22), 
								hazardModChartLerpVariable.x);
	
					opponentStrums.members[i].y = FlxMath.lerp(
						strumYforWave, 
							strumYforWave + (Math.sin(((Conductor.songPosition/300) + (i*0.2) )*Math.PI) * 22), 
								hazardModChartLerpVariable.x);
				}
			}
			*/
	
			//modchart case
			switch (hazardModChartEffect){
				case 4:
					for (i in 0...playerStrums.length) {
						playerStrums.members[i].x = FlxMath.lerp(
							hazardModChartDefaultStrumX[i+4], 
							hazardModChartDefaultStrumX[i+4] + (Math.sin((Conductor.songPosition/(Conductor.crochet*16))*Math.PI) * -200), 
							hazardModChartVariable1
							);
					}

				case 1:
					//Scrolling effect
					//x spacing is 112!!!! -Haz
					//New logic:
					//Scrolling Horizontal
					for (i in 0...playerStrums.length) {
						playerStrums.members[i].x += hazardModChartVariable1;
						opponentStrums.members[i].x += hazardModChartVariable1;
						//if(i == 1) trace(playerStrums.members[i].x);
					}
					if(SONG.song.toLowerCase()=="her" && curBeat < 608){
						//Checking if it needs to be looped around
						if(hazardModChartVariable1>0){
							if(playerStrums.members[1].x >= 1250){
								playerStrums.members[2].x = -120;
								playerStrums.members[1].x = playerStrums.members[2].x-112;
								playerStrums.members[3].x = playerStrums.members[2].x+112; 
								playerStrums.members[0].x = playerStrums.members[2].x-224;
							}
						}else{
							if(playerStrums.members[2].x <= -120){
								playerStrums.members[1].x = 1250;
								playerStrums.members[0].x = playerStrums.members[1].x-112;
								playerStrums.members[2].x = playerStrums.members[1].x+112; 
								playerStrums.members[3].x = playerStrums.members[1].x+224;
							}
						}
						if(hazardModChartVariable1>0){
							if(opponentStrums.members[1].x >= 1250){
								opponentStrums.members[2].x = -120;
								opponentStrums.members[1].x = opponentStrums.members[2].x-112;
								opponentStrums.members[3].x = opponentStrums.members[2].x+112; 
								opponentStrums.members[0].x = opponentStrums.members[2].x-224;
							}
						}else{
							if(opponentStrums.members[2].x <= -120){
								opponentStrums.members[1].x = 1250;
								opponentStrums.members[0].x = opponentStrums.members[1].x-112;
								opponentStrums.members[2].x = opponentStrums.members[1].x+112; 
								opponentStrums.members[3].x = opponentStrums.members[1].x+224;
							}
						}
					}else{
						//Checking if it needs to be looped around
						if(hazardModChartVariable1>0){
							if(playerStrums.members[1].x >= 1400){
								playerStrums.members[2].x = -270;
								playerStrums.members[1].x = playerStrums.members[2].x-112;
								playerStrums.members[3].x = playerStrums.members[2].x+112; 
								playerStrums.members[0].x = playerStrums.members[2].x-224;
							}
						}else{
							if(playerStrums.members[2].x <= -270){
								playerStrums.members[1].x = 1400;
								playerStrums.members[0].x = playerStrums.members[1].x-112;
								playerStrums.members[2].x = playerStrums.members[1].x+112; 
								playerStrums.members[3].x = playerStrums.members[1].x+224;
							}
						}
						if(hazardModChartVariable1>0){
							if(opponentStrums.members[1].x >= 1400){
								opponentStrums.members[2].x = -270;
								opponentStrums.members[1].x = opponentStrums.members[2].x-112;
								opponentStrums.members[3].x = opponentStrums.members[2].x+112; 
								opponentStrums.members[0].x = opponentStrums.members[2].x-224;
							}
						}else{
							if(opponentStrums.members[2].x <= -270){
								opponentStrums.members[1].x = 1400;
								opponentStrums.members[0].x = opponentStrums.members[1].x-112;
								opponentStrums.members[2].x = opponentStrums.members[1].x+112; 
								opponentStrums.members[3].x = opponentStrums.members[1].x+224;
							}
						}
					}

				case 7:
					//Speen (code from Inhuman mod. Does this count as an Inhuman mod leak?)
					for (i in 0...playerStrums.length) {
						if(i % 2 == 0){
							playerStrums.members[i].x = hazardModChartDefaultStrumX[i+4]+55 + (Math.cos((Conductor.songPosition/Conductor.crochet)*Math.PI) * -55);
							playerStrums.members[i].y = hazardModChartDefaultStrumY[i+4] + (Math.sin((Conductor.songPosition/Conductor.crochet)*Math.PI) * -55);
						}else{
							playerStrums.members[i].x = hazardModChartDefaultStrumX[i+4]-55 + (Math.cos((Conductor.songPosition/Conductor.crochet)*Math.PI) * 55);
							playerStrums.members[i].y = hazardModChartDefaultStrumY[i+4] + (Math.sin((Conductor.songPosition/Conductor.crochet)*Math.PI) * 55);
						}
					}

				
				case 2:
					//Screen shaking effect (Termination)
					camHUD.angle = Math.sin((Conductor.songPosition/Conductor.crochet)*Math.PI) * 5;

				default:
					//do nothing
			}

		if(!inCutscene) {
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
			if(!startingSong && !endingSong && boyfriend.animation.curAnim.name.startsWith('idle')) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		}

		super.update(elapsed);

		if(ratingName == '?') {
			scoreTxt.text = 'Score: ' + songScore + ' | Misses: ' + songMisses + ' | Rating: ' + ratingName;
		} else {
			scoreTxt.text = 'Score: ' + songScore + ' | Misses: ' + songMisses + ' | Rating: ' + ratingName + ' (' + Highscore.floorDecimal(ratingPercent * 100, 2) + '%)' + ' - ' + ratingFC;//peeps wanted no integer rating
		}

		if(botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}


		if (controls.PAUSE) //Modified so that enter can skip the thanks for playing screen.
		{
			if(startedCountdown && canPause){
				var ret:Dynamic = callOnLuas('onPause', []);
				if(ret != FunkinLua.Function_Stop) {
					persistentUpdate = false;
					persistentDraw = true;
					paused = true;

					// 1 / 1000 chance for Gitaroo Man easter egg
					/*if (FlxG.random.bool(0.1))
					{
						// gitaroo man easter egg
						cancelMusicFadeTween();
						MusicBeatState.switchState(new GitarooPause());
					}
					else {*/
					if(FlxG.sound.music != null) {
						FlxG.sound.music.pause();
						vocals.pause();
					}
					openSubState(new PauseSubState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
					//}
			
					#if desktop
					if(discordDifficultyOverrideShouldUse)
						DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter());
					else
						DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
					#end
				}
			}else if(canSkipEndScreen){
				endSong();
				//trace("endSong triggerd from qtCanSkipEndScreen");
			}
		}

		if (FlxG.keys.anyJustPressed(debugKeysChart) && !endingSong && !inCutscene)
		{
			openChartEditor();
		}

		// FlxG.watch.addQuick('VOL', vocals.amplitudeLeft);
		// FlxG.watch.addQuick('VOLRight', vocals.amplitudeRight);

		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, CoolUtil.boundTo(1 - (elapsed * 9), 0, 1));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();

		var iconOffset:Int = 26;

		iconP1.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.x + (healthBar.width * (FlxMath.remapToRange(healthBar.percent, 0, 100, 100, 0) * 0.01)) - (150 * iconP2.scale.x) / 2 - iconOffset * 2;

		if (health > 2)
			health = 2;
		else if (health < maxHealth && godMode){
			health = 0;
		}

		if (healthBar.percent < 20)
			iconP1.animation.curAnim.curFrame = 1;
		else
			iconP1.animation.curAnim.curFrame = 0;

		if (healthBar.percent > 80)
			iconP2.animation.curAnim.curFrame = 1;
		else
			iconP2.animation.curAnim.curFrame = 0;

		if (FlxG.keys.anyJustPressed(debugKeysCharacter) && !endingSong && !inCutscene) {
			persistentUpdate = false;
			paused = true;
			cancelMusicFadeTween();
			MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
		}

		if (startingSong)
		{
			if (startedCountdown)
			{
				Conductor.songPosition += FlxG.elapsed * 1000;
				if (Conductor.songPosition >= 0)
					startSong();
			}
		}
		else
		{
			Conductor.songPosition += FlxG.elapsed * 1000;

			if (!paused)
			{
				songTime += FlxG.game.ticks - previousFrameTime;
				previousFrameTime = FlxG.game.ticks;

				// Interpolation type beat
				if (Conductor.lastSongPos != Conductor.songPosition)
				{
					songTime = (songTime + Conductor.songPosition) / 2;
					Conductor.lastSongPos = Conductor.songPosition;
					// Conductor.songPosition += FlxG.elapsed * 1000;
					// trace('MISSED FRAME');
				}

				if(updateTime) {
					var curTime:Float = Conductor.songPosition - ClientPrefs.noteOffset;
					if(curTime < 0) curTime = 0;
					songPercent = (curTime / songLength);

					var songCalc:Float = (songLength - curTime);
					if(ClientPrefs.timeBarType == 'Time Elapsed') songCalc = curTime;

					var secondsTotal:Int = Math.floor(songCalc / 1000);
					if(secondsTotal < 0) secondsTotal = 0;

					if(ClientPrefs.timeBarType != 'Song Name')
						timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
				}
			}

			// Conductor.lastSongPos = FlxG.sound.music.time;
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125), 0, 1));
		}

		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.noReset && controls.RESET && !inCutscene && !endingSong)
		{
			health = 0;
			trace("RESET = True");
			causeOfDeath = 'reset';
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = 3000;//shit be werid on 4:3
			if(songSpeed < 1) time /= songSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
			notes.forEachAlive(function(daNote:Note)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
				if(!daNote.mustPress) strumGroup = opponentStrums;

				var strumX:Float = strumGroup.members[daNote.noteData].x;
				var strumY:Float = strumGroup.members[daNote.noteData].y;
				var strumAngle:Float = strumGroup.members[daNote.noteData].angle;
				var strumDirection:Float = strumGroup.members[daNote.noteData].direction;
				var strumAlpha:Float = strumGroup.members[daNote.noteData].alpha;
				var strumScroll:Bool = strumGroup.members[daNote.noteData].downScroll;

				strumX += daNote.offsetX;
				strumY += daNote.offsetY;
				strumAngle += daNote.offsetAngle;
				strumAlpha *= daNote.multAlpha;

				if(!freezeNotes){
					if (strumScroll) //Downscroll
					{
						//daNote.y = (strumY + 0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
						daNote.distance = (0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
					}
					else //Upscroll
					{
						//daNote.y = (strumY - 0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
						daNote.distance = (-0.45 * (Conductor.songPosition - daNote.strumTime) * songSpeed);
					}
				}

				var angleDir = strumDirection * Math.PI / 180;
				if (daNote.copyAngle)
					daNote.angle = strumDirection - 90 + strumAngle;

				if(daNote.copyAlpha)
					daNote.alpha = strumAlpha;

				if(daNote.noteType == "Hurt Note")
					daNote.alpha *= ClientPrefs.hurtNoteAlpha;

				
				if(daNote.copyX)
					daNote.x = strumX + Math.cos(angleDir) * daNote.distance;

				if(daNote.copyY && !freezeNotes)
				{
					daNote.y = strumY + Math.sin(angleDir) * daNote.distance;

					//Jesus fuck this took me so much mother fucking time AAAAAAAAAA
					if(strumScroll && daNote.isSustainNote)
					{
						if (daNote.animation.curAnim.name.endsWith('end')) {
							daNote.y += 10.5 * (fakeCrochet / 400) * 1.5 * songSpeed + (46 * (songSpeed - 1));
							daNote.y -= 46 * (1 - (fakeCrochet / 600)) * songSpeed;
							if(PlayState.isPixelStage) {
								daNote.y += 8;
							} else {
								daNote.y -= 19;
							}
						} 
						daNote.y += (Note.swagWidth / 2) - (60.5 * (songSpeed - 1));
						daNote.y += 27.5 * ((SONG.bpm / 100) - 1) * (songSpeed - 1);
					}
				}

				if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote && !dad.stunned)
				{
					opponentNoteHit(daNote);
				}

				if(daNote.mustPress && cpuControlled) {
					if(daNote.isSustainNote) {
						if(daNote.canBeHit) {
							goodNoteHit(daNote);
						}
					} else if(daNote.strumTime <= Conductor.songPosition || (daNote.isSustainNote && daNote.canBeHit && daNote.mustPress)) {
						goodNoteHit(daNote);
					}
				}
				
				var center:Float = strumY + Note.swagWidth / 2;
				if(strumGroup.members[daNote.noteData].sustainReduce && daNote.isSustainNote && (daNote.mustPress || !daNote.ignoreNote) &&
					(!daNote.mustPress || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
				{
					if (strumScroll)
					{
						if(daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center)
						{
							var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
							swagRect.height = (center - daNote.y) / daNote.scale.y;
							swagRect.y = daNote.frameHeight - swagRect.height;

							daNote.clipRect = swagRect;
						}
					}
					else
					{
						if (daNote.y + daNote.offset.y * daNote.scale.y <= center)
						{
							var swagRect = new FlxRect(0, 0, daNote.width / daNote.scale.x, daNote.height / daNote.scale.y);
							swagRect.y = (center - daNote.y) / daNote.scale.y;
							swagRect.height -= swagRect.y;

							daNote.clipRect = swagRect;
						}
					}
				}

				if(opponentNoteColourChange && !daNote.mustPress){
					daNote.color = FlxColor.GRAY; //darken
				}else{
					daNote.color = FlxColor.WHITE; //back to normal
				}

				// Kill extremely late notes and cause misses
				if (Conductor.songPosition > noteKillOffset + daNote.strumTime && !freezeNotes)
				{
					if (daNote.mustPress && !cpuControlled &&!daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit)) {
						noteMiss(daNote);
					}

					daNote.active = false;
					daNote.visible = false;

					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}
			});
		}
		checkEventNote();

		if (!inCutscene) {
			if(!cpuControlled) {
				keyShit();
			} else if(!bfDodging && !boyfriend.stunned && boyfriend.holdTimer > Conductor.stepCrochet * 0.001 * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss')) {
				boyfriend.dance();
			}
		}

		if(!endingSong && !startingSong) {
			if(!skippedIntro && introSkip > 0){
				if(Conductor.songPosition < introSkip*1000 ){
					if(FlxG.keys.justPressed.SPACE && deathCounter > 0) { //skip to the future! wow!
						skipIntro();
					}
				}else if(!skippedIntro){
					skippedIntro = true;
					remove(introSkipSprite);
					trace("Didn't skip Intro!");
				}
				
			}
		}
		
		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.FIVE){
				godMode = !godMode;
				if(godMode)
					scoreTxt.color = FlxColor.CYAN;
				else
					scoreTxt.color = FlxColor.WHITE;
			}
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				FlxG.sound.music.pause();
				vocals.pause();
				Conductor.songPosition += 10000;
				notes.forEachAlive(function(daNote:Note)
				{
					if(daNote.strumTime + 800 < Conductor.songPosition) {
						daNote.active = false;
						daNote.visible = false;

						daNote.kill();
						notes.remove(daNote, true);
						daNote.destroy();
					}
				});
				for (i in 0...unspawnNotes.length) {
					var daNote:Note = unspawnNotes[0];
					if(daNote.strumTime + 800 >= Conductor.songPosition) {
						break;
					}

					daNote.active = false;
					daNote.visible = false;

					daNote.kill();
					unspawnNotes.splice(unspawnNotes.indexOf(daNote), 1);
					daNote.destroy();
				}

				health = 1.8; //Restores health?

				FlxG.sound.music.time = Conductor.songPosition;
				FlxG.sound.music.play();

				vocals.time = Conductor.songPosition;
				vocals.play();
			}
		}
		#end

		setOnLuas('cameraX', camFollowPos.x);
		setOnLuas('cameraY', camFollowPos.y);
		setOnLuas('botPlay', cpuControlled);
		
		callOnLuas('onUpdatePost', [elapsed]);
		for (i in shaderUpdates){
			i(elapsed);
		}
	}

	function skipIntro(){
		trace("Skipped Intro!");
		skippedIntro = true;
		remove(introSkipSprite);
		if(SONG.song.toLowerCase() == "interlope"){
			if(interlopeIntroTween != null)
				interlopeIntroTween.cancel();
			if(interlopeIntroTweenHUD != null)
				interlopeIntroTweenHUD.cancel();
			for (tween in interlopeIntroTweens){ //Stops moving the arrows
				tween.cancel();
			}

			camHUD.visible=true;
			camHUD.alpha=1;
			for (i in 0...playerStrums.length){
				//Forces arrows into starting positions
				playerStrums.members[i].angle = 0;
				playerStrums.members[i].alpha = 1;
				playerStrums.members[i].x = hazardModChartDefaultStrumX[i+4];
				playerStrums.members[i].y = hazardModChartDefaultStrumY[i+4];
			}
		}

		FlxG.sound.music.pause();
		#if debug
		health = 2; //Don't change health
		#end
		vocals.pause();
		Conductor.songPosition = introSkip * 1000;
		notes.forEachAlive(function(daNote:Note)
		{
			if(daNote.strumTime + 800 < Conductor.songPosition) {
				daNote.active = false;
				daNote.visible = false;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
		});
		for (i in 0...unspawnNotes.length) {
			var daNote:Note = unspawnNotes[0];
			if(daNote.strumTime + 800 >= Conductor.songPosition) {
				break;
			}

			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			unspawnNotes.splice(unspawnNotes.indexOf(daNote), 1);
			daNote.destroy();
		}

		FlxG.sound.music.time = Conductor.songPosition;
		FlxG.sound.music.play();

		vocals.time = Conductor.songPosition;
		vocals.play();
	}

	function epicStuff(){
		//Don't spoil the fun for others.
		if(!ClientPrefs.lowQuality){ //Don't do secrets if on low quality.
			var wack:Bool = false;
			if(SONG.song.toLowerCase()=="interlope")
				wack = FlxG.random.bool(10); //Increased chance for secrets in Interlope.
			else
				wack = FlxG.random.bool(5);
			if(wack){
				var horror:FlxSprite;
				var wack:Int = FlxG.random.int(1,9);
				//Update v2.1, Interlope screen is 100% now after Cessation. Will be like this until you've beaten Interlope.
				if(!Achievements.achievementsMap.exists(Achievements.achievementsStuff[10][2]) && Achievements.achievementsMap.exists(Achievements.achievementsStuff[5][2])){ //If you can access Interlope, allows for the Interlope hint to be shown.
					wack = 100;
				}
				switch(wack)
				{
					case 2:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret02'));
					case 3:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret03'));
					case 4:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret04'));
					case 5:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret05'));
					case 6:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret06'));
					case 7:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret07'));
					case 8:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret08'));
					case 9:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret09')); //v2.2 final secret screen.
					case 100: //Interlope secret screen
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecretInterlope'));
					default:
						horror = new FlxSprite(-80).loadGraphic(Paths.image('hazard/qt-port/stage/topsecretfolder/DoNotLook/horrorSecret01'));
				}			
				horror.scrollFactor.x = 0;
				horror.scrollFactor.y = 0.15;
				horror.setGraphicSize(Std.int(horror.width * 1.1));
				horror.updateHitbox();
				horror.screenCenter();
				horror.antialiasing = ClientPrefs.globalAntialiasing;
				horror.cameras = [camOther];
				var visiblityShit:Bool = camHUD.visible; //In case the HUD starts invisible or visible, I do this shit instead.
				camHUD.visible = false;
				add(horror);

				new FlxTimer().start(0.5, function(tmr:FlxTimer)
				{
					camHUD.visible = visiblityShit;
					remove(horror);
				});
			}
		}
		
	}

	function openChartEditor()
	{
		persistentUpdate = false;
		paused = true;
		THISISFUCKINGDISGUSTINGPLEASESAVEME = false;
		cancelMusicFadeTween();
		MusicBeatState.switchState(new ChartingState());
		chartingMode = true;

		#if desktop
		DiscordClient.changePresence("Chart Editor", null, null, true);
		#end
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= maxHealth) && !practiceMode && !isDead && !godMode)
		{
			var ret:Dynamic = callOnLuas('onGameOver', []);
			if(ret != FunkinLua.Function_Stop) {
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				vocals.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				for (tween in modchartTweens) {
					tween.active = true;
				}
				for (tween in interlopeIntroTweens){
					tween.active = true;
				}
				for (timer in modchartTimers) {
					timer.active = true;
				}
				if(SONG.song.toLowerCase()=="interlope"){ //Use INHUMAN gameover screen instead of vanilla.
					BrutalityGameOverSubstate.characterName = 'amelia';
					openSubState(new BrutalityGameOverSubstate(causeOfDeath, this));
				}
				else{
					openSubState(new GameOverSubstate(causeOfDeath, boyfriend.getScreenPosition().x - boyfriend.positionArray[0], boyfriend.getScreenPosition().y - boyfriend.positionArray[1], camFollowPos.x, camFollowPos.y));
				}
				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
				
				#if desktop
				// Game Over doesn't get his own variable because it's only used here
				if(discordDifficultyOverrideShouldUse)
					DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + discordDifficultyOverride + ")", iconP2.getCharacter());
				else
					DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0][0];
			if(Conductor.songPosition < leStrumTime) {
				break;
			}

			var value1:String = '';
			if(eventNotes[0][2] != null)
				value1 = eventNotes[0][2];

			var value2:String = '';
			if(eventNotes[0][3] != null)
				value2 = eventNotes[0][3];

			triggerEventNote(eventNotes[0][1], value1, value2);
			eventNotes.shift();
		}
	}

	public function getControl(key:String) {
		var pressed:Bool = Reflect.getProperty(controls, key);
		//trace('Control result: ' + pressed);
		return pressed;
	}

	//Code from the Lullaby mod. You should check it out if you haven't already.	=D
	function reduceMaxHealth():Void{
		remove(healthBar);
		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8) - Std.int(healthBar.width * (maxHealth / 2)) , Std.int(healthBarBG.height - 8), this,
			'health', maxHealth, 2);
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.hideHud;
		remove(iconP1);
		remove(iconP2);
		add(healthBar);
		add(iconP1);
		add(iconP2);
		healthBar.cameras = [camHUD];
		reloadHealthBarColors();
	}

	public function kbATTACK_ALERT(alertType:Int = 1, playSound:Bool = true):Void
	{
		//Feel free to add your own alert types in here. Make sure that the alert sprite has the animation and the sound is also available.
		switch(alertType){
			case 2:
				if(playSound) FlxG.sound.play(Paths.sound('hazard/alertDouble'), 1);

				if(ClientPrefs.noteOffset <= 0) {
					kbATTACK_ALERT_PART2(0.55,'alertDOUBLE');
				} else {
					new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
						kbATTACK_ALERT_PART2(0.55,'alertDOUBLE');
					});
				}	
				
			case 3:
				if(playSound) FlxG.sound.play(Paths.sound('hazard/alertTriple'), 1);

				if(ClientPrefs.noteOffset <= 0) {
					kbATTACK_ALERT_PART2(0.5875,'alertTRIPLE');
				} else {
					new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
						kbATTACK_ALERT_PART2(0.5875,'alertTRIPLE');
					});
				}		
				
			case 4:
				if(playSound) FlxG.sound.play(Paths.sound('hazard/alertQuadruple'), 1);
				
				if(ClientPrefs.noteOffset <= 0) {
					kbATTACK_ALERT_PART2(0.6,'alertQUAD');
				} else {
					new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
						kbATTACK_ALERT_PART2(0.6,'alertQUAD');
					});
				}		
				
			default:
				if(playSound) FlxG.sound.play(Paths.sound('hazard/alert'), 1);
				
				//Not the best way to do offset since I fear lag can lead to an offsync sawblade, but hey I tried at least and it's better then no support at all. -Haz
				if(ClientPrefs.noteOffset <= 0) {
					kbATTACK_ALERT_PART2(0.49,'alert');
				} else {
					new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
						kbATTACK_ALERT_PART2(0.49,'alert');
					});
				}			
		}
	}

	function kbATTACK_ALERT_PART2(newAlpha:Float, animationToPlay:String):Void{
		if(!qtAlertAdded){
			add(kb_attack_alert);
			qtAlertAdded=true;
		}

		//NewAlpha is for the alert overlay vigenette.
		if(ClientPrefs.flashing && hazardOverlayShit != null)
			hazardOverlayShit.alpha=newAlpha;

		kb_attack_alert.animation.play(animationToPlay);
		switch(animationToPlay){
			default:
				kb_attack_alert.offset.set(0,0);
			case "alertQUAD":
				kb_attack_alert.offset.set(152,38);
			case "alertTRIPLE":
				kb_attack_alert.offset.set(150,56);
			case "alertDOUBLE":
				kb_attack_alert.offset.set(70,5);
		}
	}

	function kbATTACK_DELAYED(state:Bool = false, soundToPlay:String = 'hazard/attack', instaKill:Bool = false){
		if(state){
			if(!qtSawbladeAdded){
				add(kb_attack_saw);
				qtSawbladeAdded = true;
			}
			//Play saw attack animation
			kb_attack_saw.animation.play('fire');
			kb_attack_saw.offset.set(1600,0);
			FlxG.camera.shake(0.001675,0.6);
			camHUD.shake(0.001675,0.2);
			if(cpuControlled) bfDodge();
			//Slight delay for animation. Yeah I know I should be doing this using curStep and curBeat and what not, but I'm lazy -Haz
			new FlxTimer().start(0.09, function(tmr:FlxTimer)
			{
				if(!bfDodging){
					if(!godMode){
						sawbladeHits ++;
						trace("sawbladeHits: ",sawbladeHits);

						//Classic Termination sawblade which instakill.
						//After 3rd sawblade, will guarantee an instakill.
						if((instaKill || sawbladeHits > 3 || (storyDifficulty==2 && SONG.song.toLowerCase() == "termination"))){
							//MURDER THE BITCH!
							trace("Instakill sawblade missed");
							health -= 404;
							causeOfDeath = "sawblade";
							#if ACHIEVEMENTS_ALLOWED
							Achievements.sawbladeDeath++;
							FlxG.save.data.sawbladeDeath = Achievements.sawbladeDeath;
							var achieve:String = checkForAchievement(['sawblade_death']);
							if (achieve != null) {
								startAchievement(achieve);
							} else {
								FlxG.save.flush();
							}
							FlxG.log.add('ClassicBonks: ' + Achievements.sawbladeDeath);
							#end
						}else{
							health -= 0.265;
							if(health >= maxHealth+0.51125){
								maxHealth = maxHealth+0.51125;
								reduceMaxHealth();
								//Only reduce max health if possible. This is here to hopefully avoid a crash with the regerneating the bar or something.
							}
							//mmmmm I loved scuffed code. But it works!
							if(health < maxHealth){ //If the health is too low after the sawblade, sawblade kills you.
								health -= 404; 		//v2.1, I forgot to add this line of code so errr, now sawblades actually kill you again :D
								causeOfDeath = "sawblade";
								#if ACHIEVEMENTS_ALLOWED
								Achievements.sawbladeDeath++;
								FlxG.save.data.sawbladeDeath = Achievements.sawbladeDeath;
								var achieve:String = checkForAchievement(['sawblade_death']);
								if (achieve != null) {
									startAchievement(achieve);
								} else {
									FlxG.save.flush();
								}
								FlxG.log.add('Bonks: ' + Achievements.sawbladeDeath);
								#end
							}else{
								//Done so that the sound doesn't play if the sawblade would've killed the player.
								if(ClientPrefs.qtBonk)
									FlxG.sound.play(Paths.sound('bonk'),1); //This is fucking amazing.
								else
									FlxG.sound.play(Paths.sound('hazard/sawbladeHit'),1); //Ouch
							}
							boyfriend.stunned=true;
							boyfriend.playAnim('hurt',true);
							new FlxTimer().start(0.495, function(tmr:FlxTimer)
							{
								boyfriend.stunned=false;
								//trace("Not fucked anymore?");
							});
						}
					}
				}
			});
		}else{
			//Forces BF to be able to dodge again in preperation for the sawblade. Mainly useful for the Double Sawblade.
			bfCanDodge=true;
			kb_attack_saw.animation.play('prepare');
			kb_attack_saw.offset.set(-333,0);
		}
	}

	public function KBATTACK(state:Bool = false, soundToPlay:String = 'hazard/attack', instaKill:Bool = false):Void
	{
		if(state)	FlxG.sound.play(Paths.sound(soundToPlay),0.765);

		if(!qtSawbladeAdded){
			add(kb_attack_saw);
			qtSawbladeAdded = true;
		}

		if(ClientPrefs.noteOffset <= 0) {
			kbATTACK_DELAYED(state,soundToPlay,instaKill);
		} else {
			new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
				kbATTACK_DELAYED(state,soundToPlay,instaKill);
			});
		}	
	}


	//Pincer logic, used by the modchart but can be hardcoded like saws if you want.
	public function KBPINCER_PREPARE(laneID:Int, goAway:Bool):Void
	{
		// 1 = BF far left, 4 = BF far right. This only works for BF!
		// Update! 5 now refers to the far left lane (KB side). Mainly used for the shaking section or whatever.
		// UPDATE 2! 6 now refers to the far right lane (KB side). Used for the screen shasking effect when in middle scroll.
		// Qt Fixes: Optmized code as much as possible. -Luis
		if (laneID > 6)
			return trace('Invalid LaneID for pincer');

		var pincer:FlxSprite;
		pincer = pincers[(laneID - 1) % 4].loadGraphic(Paths.image('hazard/qt-port/pincer-open'), false);
		pincer.cameras = [camHUD];

		var spr:StrumNote = null;
		if (laneID < 5)
			spr = playerStrums.members[laneID - 1];
		else
			spr = opponentStrums.members[laneID == 5 ? 0 : 3];

		var sign:Int = ClientPrefs.downScroll ? 1 : -1;
		var yPos:Float = spr.y + sign * 500;

		if (!goAway)
		{
			pincer.setPosition(spr.x, yPos);
			add(pincer);
			FlxTween.tween(pincer, {y: spr.y}, 0.3, {ease: FlxEase.elasticOut});
		}
		else
		{
			FlxTween.tween(pincer, {y: yPos}, 0.4, {
				ease: FlxEase.backIn,
				onComplete: function(twn:FlxTween)
				{
					remove(pincer, true);
				}
			});
		}
	}

	function TerminationIntroShit(state:Int, playerShit:Bool):Void
	{
		FlxG.camera.shake(0.002,1);
		camHUD.shake(0.002,1);
		if(playerShit){
			playerStrums.members[state].y += (ClientPrefs.downScroll ? -25:25);
			FlxTween.tween(playerStrums.members[state], {y: hazardModChartDefaultStrumY[state], alpha: 1}, 1.22, {ease: FlxEase.cubeOut});
		}else{
			opponentStrums.members[state].y += (ClientPrefs.downScroll ? -25:25);
			FlxTween.tween(opponentStrums.members[state], {y: hazardModChartDefaultStrumY[state], alpha: forceMiddleScroll ? 0.35:1}, 1.22, {ease: FlxEase.cubeOut});
		}
	}
	function TerminationOutroShit(state:Int):Void
	{
		if(state > 3){
			//trace("Bye bye player", state-4);
			FlxTween.tween(playerStrums.members[state-4], {alpha: 0}, 1.1, {ease: FlxEase.sineInOut});
		}else{
			//trace("Bye bye opponent", state);
			FlxTween.tween(opponentStrums.members[state], {alpha: 0}, 1.1, {ease: FlxEase.sineInOut});
		}
	}

	public function KBPINCER_GRAB(laneID:Int):Void
	{
		switch(laneID)
		{
			case 1 | 5:
				pincer1.loadGraphic(Paths.image('hazard/qt-port/pincer-close'), false);
			case 2:
				pincer2.loadGraphic(Paths.image('hazard/qt-port/pincer-close'), false);
			case 3:
				pincer3.loadGraphic(Paths.image('hazard/qt-port/pincer-close'), false);
			case 4:
				pincer4.loadGraphic(Paths.image('hazard/qt-port/pincer-close'), false);
			default:
				trace("Invalid LaneID for pincerGRAB");
		}
	}

	public function qtStreetTV(stateID:Int){
		/*Use to control the TV's on QT's stage.
		0 = static
		1 = alert
		2 = instructions part 1
		3 = instructions part 2
		4 = watch out
		5 = BLabs moment 
		6 = Glitch
		7 = Bluescreen
		8 = incoming drop*/
		switch(stateID){
			case 0:
				qt_tv01.animation.play("idle");
			case 2:
				qt_tv01.animation.play("instructions");
			case 3:
				qt_tv01.animation.play("gl");
			case 1:
				qt_tv01.animation.play("alert");
			case 4:
				qt_tv01.animation.play("watch");
			case 5:
				qt_tv01.animation.play("eye");
			case 6:
				qt_tv01.animation.play("error");
			case 7:
				qt_tv01.animation.play("404");
			case 9:
				qt_tv01.animation.play("drop");
			case 8:
				qt_tv01.animation.play("heart");
			case 420 | 69:
				qt_tv01.animation.play("sus");
		}
		qtTVstate = stateID;
	}

	public function qtStreetBG(stateID:Int){
		switch(stateID){					
			case 1:
				//Change to glitch background
				if(!ClientPrefs.lowQuality){
					streetBGerror.visible = true;
					streetBG.visible = false;
				}
				FlxG.camera.shake(0.0078,0.675);
				//dadDrainHealth=0.0055; //Reducing health drain because fuck me that's a lot of notes!
				//healthLossMultiplier=1.1375; //More forgiving because fuck me that's a lot of notes!
				//healthGainMultiplier=1.125;
			case 2:
				if(!ClientPrefs.lowQuality){
					streetBG.visible = false;
					streetBGerror.visible = false;
					streetFrontError.visible = true;
					CensoryOverload404();
				}
			case 0:
				//healthLossMultiplier=1.22;
				//healthGainMultiplier=1.12;
				//dadDrainHealth=0.013; //Reduced health drain compared to normal for forgivness (player may have hit a sawblade, or suffering from the nerves)
				if(!ClientPrefs.lowQuality){
					streetBG.visible = true;
					streetFrontError.visible = false;
				}
		}
	}
	
	function terminateEndEarly():Void
	{
		qt_tv01.animation.play("error");
		camZooming = false;
		canPause = false;
		inCutscene = true;
		new FlxTimer().start(0.021, function(tmr:FlxTimer) //Slight delay
		{
			dad.stunned = true;
			freezeNotes = true;
			dad.playAnim('singLEFT', true);
			dad.singDuration = 9999;
		});
	}

	public function triggerEventNote(eventName:String, value1:String, value2:String) {
		switch(eventName) {
			//Hazard Events
			case 'gfScared':
				var newValue:Bool = false;
				if(value1.toLowerCase()=="true")
					newValue = true;
				gfScared = newValue;
			case 'newLossMultiplier':
				var value:Float = Std.parseFloat(value1);
				if(Math.isNaN(value)) value = 1;
				healthLossMultiplier = value;
			case 'newHealthGainMultiplier':
				var value:Float = Std.parseFloat(value1);
				if(Math.isNaN(value)) value = 1;
				healthGainMultiplier = value;
			case 'newDadDrainHealthValue':
				if(value1.toLowerCase()!="skip"){
					var value:Float = Std.parseFloat(value1);
					if(Math.isNaN(value)) value = 0;
					dadDrainHealth = value;
				}				
				if(value2.toLowerCase()=="false")
					dadDrainHealthSustain = false;
				else if(value2.toLowerCase()=="true")
					dadDrainHealthSustain = true;

			case 'newDodgeCooldown':
				var value:Float = Std.parseFloat(value1);
				if(Math.isNaN(value)) value = 0;
				bfDodgeCooldown = value;
			case 'newDodgeDuration':
				var value:Float = Std.parseFloat(value1);
				if(Math.isNaN(value)) value = 0;
				bfDodgeTiming = value;

			case 'streetTV state':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value)) value = 0;
				qtStreetTV(value);
			case 'streetBG state':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value)) value = 0;
				//0 = normal
				//1 = glitch
				//2 = bluescreen
				qtStreetBG(value);
				//trace("BG state =",value);

			case 'Rotating':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value)) value = 0;
				if(value == 3){
					noteSpeen = 0;
					for (i in 0...playerStrums.length) {
						FlxTween.tween(playerStrums.members[i], {angle:0,x:hazardModChartDefaultStrumX[i+4], y:hazardModChartDefaultStrumY[i+4]}, 0.39, {ease: FlxEase.quadInOut});
					}
					for (i in 0...opponentStrums.length) {
						FlxTween.tween(opponentStrums.members[i], {angle:0,x:hazardModChartDefaultStrumX[i], y:hazardModChartDefaultStrumY[i]}, 0.39, {ease: FlxEase.quadInOut});
					}
				}else{
					noteSpeen = value;
				}

			case 'Gas Effect':
				if(!ClientPrefs.lowQuality){
					var animationToPlay:String = value1.toLowerCase().trim();

					if(animationToPlay == "burst"){
						qt_gas01.animation.play('burst');
						qt_gas02.animation.play('burst');
					}else if(animationToPlay == "burstfast"){
						qt_gas01.animation.play('burstALT');
						qt_gas02.animation.play('burstALT');
					}else if(animationToPlay == "burstfaster"){
						qt_gas01.animation.play('burstFAST');
						qt_gas02.animation.play('burstFAST');
					}
				}

			case 'Alarm Gradient':
				if(ClientPrefs.flashing && !ClientPrefs.lowQuality){
					//Value 1  = which side
					//Value 2 = alpha to fade to
					var targetAlpha:Float = Std.parseFloat(value2);
					if(Math.isNaN(targetAlpha)) targetAlpha = 0;

					if(value1.toLowerCase()=="left"){

						//hazardBGashley is gradient flipped
						FlxTween.tween(hazardAlarmLeft, {alpha:targetAlpha}, 0.25, {
							ease: FlxEase.quartOut,
							onComplete: function(twn:FlxTween)
							{
								FlxTween.tween(hazardAlarmLeft, {alpha: 0}, 0.36, {ease: FlxEase.cubeOut });
							}
						});
					}else if(value1.toLowerCase()=="right"){
						//hazardBGblank is gradient
						FlxTween.tween(hazardAlarmRight, {alpha:targetAlpha}, 0.25, {
							ease: FlxEase.quartOut,
							onComplete: function(twn:FlxTween)
							{
								FlxTween.tween(hazardAlarmRight, {alpha: 0}, 0.36, {ease: FlxEase.cubeOut });
							}
						});
					}else{
						FlxG.log.warn('Value 1 for alarm has to either be "right" or "left"');
					}
				}

			case 'CessationTroll':
				if (curSong.toLowerCase() == 'cessation'){
					var value:Int = Std.parseInt(value1);
					if(Math.isNaN(value)) value = 0;

					var valueFORCE:Int = Std.parseInt(value2);
					if(Math.isNaN(valueFORCE)) valueFORCE = 0;

					if((hazardRandom==5 || valueFORCE==1) && !cpuControlled){
						if(value == 0){
							add(kb_attack_alert);
							kbATTACK_ALERT(1);
						}
						else if (value == 1){
							kbATTACK_ALERT(1);
						}
						else if(value == 2){
							FlxG.sound.play(Paths.sound('hazard/bruh'),0.75);
							add(cessationTroll);
						}
						else if(value == 3){
							remove(cessationTroll);
						}
						cessationTrollDone=true;
					}
				}else{
					FlxG.log.notice("CessationTroll only works on Cessation!");
				}
				
			case 'InterlopeEffect' | '??????':
				var modChartEffectShit:Int = Std.parseInt(value1);
				if(Math.isNaN(modChartEffectShit)) modChartEffectShit = 0;

				hazardModChartEffect = modChartEffectShit;

				var value:Int = Std.parseInt(value2);
				if(Math.isNaN(value)) value = 0;

				switch(value){
					case 1:
						if(!skippedIntro){
							interlopeFadeinShaderFading = true;
							interlopeIntroTweens.set("introEffect1", FlxTween.tween(playerStrums.members[0], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[4], y:hazardModChartDefaultStrumY[4]}, 6, {ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween) {
									interlopeIntroTweens.remove("introEffect1");
								}
							}));
							//FlxTween.tween(playerStrums.members[0], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[4], y:hazardModChartDefaultStrumY[4]}, 6, {ease: FlxEase.quadOut});
						}							
					case 2:
						if(!skippedIntro){
							interlopeIntroTweens.set("introEffect2", FlxTween.tween(playerStrums.members[1], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[5], y:hazardModChartDefaultStrumY[5]}, 6, {ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween) {
									interlopeIntroTweens.remove("introEffect2");
								}
							}));
							//FlxTween.tween(playerStrums.members[1], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[5], y:hazardModChartDefaultStrumY[5]}, 6, {ease: FlxEase.quadOut});
						}		
					case 3:
						if(!skippedIntro){
							interlopeIntroTweens.set("introEffect3", FlxTween.tween(playerStrums.members[2], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[6], y:hazardModChartDefaultStrumY[6]}, 6, {ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween) {
									interlopeIntroTweens.remove("introEffect3");
								}
							}));
							//FlxTween.tween(playerStrums.members[2], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[6], y:hazardModChartDefaultStrumY[6]}, 6, {ease: FlxEase.quadOut});
						}
					case 4:
						if(!skippedIntro){
							interlopeIntroTweens.set("introEffect4", FlxTween.tween(playerStrums.members[3], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[7], y:hazardModChartDefaultStrumY[7]}, 6, {ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween) {
									interlopeIntroTweens.remove("introEffect4");
								}
							}));
							//FlxTween.tween(playerStrums.members[3], {alpha: 1, angle: 0, x:hazardModChartDefaultStrumX[7], y:hazardModChartDefaultStrumY[7]}, 6, {ease: FlxEase.quadOut});
						}
					case 5: //First Chuckle 
						interlopeFadeinShaderFading=false;
						interlopeFadeinShaderIntensity=1.2;
						hazardBlack.alpha = 0.75;
						opponentNoteColourChange = true;
						for (i in 0...opponentStrums.length) {
							opponentStrums.members[i].x = hazardModChartDefaultStrumX[i];
							opponentStrums.members[i].color = FlxColor.GRAY;
							FlxTween.tween(opponentStrums.members[i], {alpha: 0.325}, 0.55, {ease: FlxEase.linear});
						}

						if(!ClientPrefs.lowQuality){
							hazardInterlopeLaugh.animation.play("laugh1");
							hazardInterlopeLaugh.alpha = 0.3;
						}
					case 6: //Begin
						interlopeFadeinShaderFading=false;
						interlopeFadeinShaderIntensity=0;
						hazardBlack.alpha = 0;
						if(!ClientPrefs.lowQuality){
							hazardInterlopeLaugh.alpha=0;
						}
					case 7: // drums begin
						hazardModChartVariable1=0;
						FlxTween.num(0, 1, 6, {type: ONESHOT}, function(v){
							hazardModChartVariable1 = v;
						});
					case 17: //Begin halfway point
						for (i in 0...opponentStrums.length) {
							opponentStrums.members[i].color = FlxColor.GRAY;
							FlxTween.tween(opponentStrums.members[i], {alpha: 0.95, x: playerStrums.members[i].x}, 7, {ease: FlxEase.quadInOut});
						}
					case 18: //Begin halfway point
						for (i in 0...opponentStrums.length) {
							FlxTween.tween(opponentStrums.members[i], {alpha: 0, x: hazardModChartDefaultStrumX[i]}, 0.75, {ease: FlxEase.linear});
						}
						
					case 19: //MMM BASS (right before)
						for (i in 0...playerStrums.length) {
							FlxTween.tween(playerStrums.members[i], {x: hazardModChartDefaultStrumX[i+4]}, 0.77922, {ease: FlxEase.linear});
						}
					case 20: //Bass Chroma distort
						if(interlopeChroma != null)
							interlopeChromaIntensity = 0.045;

					case 8: //2nd chuckle
						if(!ClientPrefs.lowQuality){
							hazardInterlopeLaugh.animation.play("laugh1");
							modchartTweens.set("interlopeTaunt", FlxTween.tween(hazardInterlopeLaugh, {alpha: 0.55}, 0.33, {ease: FlxEase.linear ,
								onComplete: function(twn:FlxTween) {
									modchartTweens.remove("interlopeTaunt");
								}
							}));
						}
					case 9: //main effect start
						hazardBGpulsing = true;
						if(!ClientPrefs.lowQuality){
							hazardInterlopeLaugh.alpha=0;
						}
					case 10: //laugh
						opponentNoteColourChange = true;
						hazardBGpulsing = false;
						if(!ClientPrefs.lowQuality){
							hazardInterlopeLaugh.x += 175;
							hazardInterlopeLaugh.animation.play("laugh2");
							modchartTweens.set("interlopeTaunt", FlxTween.tween(hazardInterlopeLaugh, {alpha: 0.8}, 0.325, {ease: FlxEase.quadOut ,
								onComplete: function(twn:FlxTween) {
									modchartTweens.remove("interlopeTaunt");
								}
							}));
						}
						for (i in 0...opponentStrums.length) {
							opponentStrums.members[i].color = FlxColor.GRAY;
							opponentStrums.members[i].x = playerStrums.members[i].x;
							playerStrums.members[i].x = hazardModChartDefaultStrumX[i+4]+300;

							//FlxTween.tween(opponentStrums.members[i], {alpha: 0.4}, 0.5, {ease: FlxEase.linear});
							//FlxTween.tween(opponentStrums.members[i], {x: playerStrums.members[i].x-600}, 0.7, {ease: FlxEase.quadOut});

							//This is probably going to break something. I don't care.
							modchartTweens.set("interlopeOpponentMove", FlxTween.tween(opponentStrums.members[i], {x: playerStrums.members[i].x-600}, 0.7, {ease: FlxEase.quadOut,
								onComplete: function(twn:FlxTween) {
									modchartTweens.remove("interlopeOpponentMove");
								}
							}));
							modchartTweens.set("interlopeOpponentAlpha", FlxTween.tween(opponentStrums.members[i], {alpha: 0.4}, 0.5, {ease: FlxEase.linear,
								onComplete: function(twn:FlxTween) {
									modchartTweens.remove("interlopeOpponentAlpha");
								}
							}));
						}

					case 11: //after laugh
						hazardBGpulsing = true;
						if(!ClientPrefs.lowQuality){
							hazardInterlopeLaugh.alpha=0;
						}
					case 12: //pulse begin
						hazardBGpulsing = true;
						
					case 13: //finish
						hazardBGpulsing = false;
						FlxTween.tween(playerStrums.members[0], {alpha: 0}, 1, {ease: FlxEase.linear});
						FlxTween.tween(playerStrums.members[1], {alpha: 0}, 1, {ease: FlxEase.linear});
						FlxTween.tween(playerStrums.members[2], {alpha: 0}, 1, {ease: FlxEase.linear});
						modchartTweens.set("interlopeEndingFadeToBlack", FlxTween.tween(hazardBlack, {alpha: 0.5}, 2.7, {ease: FlxEase.linear,
							onComplete: function(twn:FlxTween) {
								modchartTweens.remove("interlopeEndingFadeToBlack");
							}
						}));
					case 14:
						FlxTween.tween(playerStrums.members[3], {alpha: 0.375}, 1, {ease: FlxEase.linear});
					case 15:
						FlxTween.tween(playerStrums.members[3], {alpha: 0}, 0.375, {ease: FlxEase.linear});

						modchartTweens.set("interlopeEndingFadeToBlack2", FlxTween.tween(hazardBlack, {alpha: 1}, 0.475, {ease: FlxEase.linear,
							onComplete: function(twn:FlxTween) {
								modchartTweens.remove("interlopeEndingFadeToBlack2");
							}
						}));
					case 16:
						hazardBGpulsing = false;
						for (i in 0...playerStrums.length) {
							FlxTween.tween(playerStrums.members[i], {x: hazardModChartDefaultStrumX[i+4]}, 0.5, {ease: FlxEase.quadInOut});
						}
						for (i in 0...opponentStrums.length) {
							FlxTween.tween(opponentStrums.members[i], {alpha: 0}, 0.45, {ease: FlxEase.linear});
						}
				}


			//XD
			case 'TerminateEndEarly':
				terminateEndEarly();

			//Termination shit
			case 'TerminationIntro':
				var value:Int = Std.parseInt(value1);
				var playShit:Bool = false;
				if(value2 == "player"){
					playShit = true;
				}
				TerminationIntroShit(value, playShit);
			case 'TerminationOutro':
				var value:Int = Std.parseInt(value1);
				TerminationOutroShit(value);

			case 'KB_Alert':
				var alertType:Int = Std.parseInt(value1);
				if(Math.isNaN(alertType)){ 
					//If value 1 isn't a number, checks if the player wrote it as words instead
					switch(value1){
						case "double":
							alertType = 2;
						case "triple":
							alertType = 3;
						case "quadruple" | "quad":
							alertType = 4;
						default:
							alertType = 1;
					}
				}
				kbATTACK_ALERT(alertType);
			case 'KB_AlertDouble':
				//Kept for legacy support
				kbATTACK_ALERT(2);
			case 'KB_AttackPrepare':
				KBATTACK(false);
				if(value1!='0'){ 
					kbATTACK_ALERT();
				}
					
			case 'KB_AttackFire':
				//For playing different sounds:
				var soundToPlay:String = value1.toLowerCase();
				if(soundToPlay == null || soundToPlay == " "  || soundToPlay == "" || soundToPlay == "single"  || soundToPlay == "1"){
					soundToPlay = "hazard/attack";
				}
				else{
					soundToPlay = "hazard/attack-"+soundToPlay;
					trace("sawblade sound file: ", ("hazard/attack-"+soundToPlay));
				}

				//Checking if it should be an insta-kill sawblade.
				if(value2=='1' || value2=='instakill'){
					KBATTACK(true, soundToPlay, true);
				}else{
					KBATTACK(true, soundToPlay, false);
				}

			case 'KB_AttackFireDOUBLE':
				//Kept for legacy support
				if(value1=='1'){
					KBATTACK(false);
				}else{
					if(value2=='1' || value2=='instakill'){
						KBATTACK(true, "hazard/attack-double", true);
					}else{
						KBATTACK(true, "hazard/attack-double", false);
					}
				}
			case 'KB_Pincer':
				switch(Std.parseInt(value1)){
					//An awful way to convert the modchart shit from lua, but fuck you.
					//first pincer move

					case 0:
						KBPINCER_PREPARE(3,false);
					case 1:
						KBPINCER_GRAB(3);
						
						if(ClientPrefs.downScroll){
							FlxTween.tween(playerStrums.members[2], {y: hazardModChartDefaultStrumY[6]-70}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer3, {y: hazardModChartDefaultStrumY[6]-70}, 0.25, {ease: FlxEase.quadOut});
						}else{
							FlxTween.tween(playerStrums.members[2], {y: hazardModChartDefaultStrumY[6]+70}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer3, {y: hazardModChartDefaultStrumY[6]+70}, 0.25, {ease: FlxEase.quadOut});
						}
						
					case 2:
						KBPINCER_PREPARE(3,true);

					//2nd pincer move
					case 3:
						KBPINCER_PREPARE(3,false);
						KBPINCER_PREPARE(1,false);
					case 4:
						KBPINCER_GRAB(1);
						KBPINCER_GRAB(3);
						FlxTween.tween(playerStrums.members[2], {y: hazardModChartDefaultStrumY[6]}, 0.3, {ease: FlxEase.quadOut});
						FlxTween.tween(pincer3, {y: hazardModChartDefaultStrumY[6]}, 0.3, {ease: FlxEase.quadOut});
						if(ClientPrefs.downScroll){
							FlxTween.tween(playerStrums.members[0], {x:hazardModChartDefaultStrumX[4]-25, y: hazardModChartDefaultStrumY[4]-62}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer1, {x:hazardModChartDefaultStrumX[4]-25, y: hazardModChartDefaultStrumY[4]-62}, 0.25, {ease: FlxEase.quadOut});
						}else{
							FlxTween.tween(playerStrums.members[0], {x:hazardModChartDefaultStrumX[4]-25, y: hazardModChartDefaultStrumY[4]+62}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer1, {x:hazardModChartDefaultStrumX[4]-25, y: hazardModChartDefaultStrumY[4]+62}, 0.25, {ease: FlxEase.quadOut});
						}
					case 5:
						KBPINCER_PREPARE(3,true);
						KBPINCER_PREPARE(1,true);

					//3rd pincer move
					case 6:
						KBPINCER_PREPARE(1,false);
						KBPINCER_PREPARE(2,false);
						KBPINCER_PREPARE(4,false);
					case 7:
						KBPINCER_GRAB(1);
						KBPINCER_GRAB(2);
						KBPINCER_GRAB(4);
						FlxTween.tween(playerStrums.members[0], {x: hazardModChartDefaultStrumX[4],y: hazardModChartDefaultStrumY[4]}, 0.3, {ease: FlxEase.quadOut});
						FlxTween.tween(pincer1, {x: hazardModChartDefaultStrumX[4],y: hazardModChartDefaultStrumY[4]}, 0.3, {ease: FlxEase.quadOut});
						if(ClientPrefs.downScroll){
							FlxTween.tween(playerStrums.members[3], {x:hazardModChartDefaultStrumX[7]+50, y: hazardModChartDefaultStrumY[7]-40}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer4, {x:hazardModChartDefaultStrumX[7]+50, y: hazardModChartDefaultStrumY[7]-40}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[1], {x:hazardModChartDefaultStrumX[5]+11, y: hazardModChartDefaultStrumY[5]-70}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer2, {x:hazardModChartDefaultStrumX[5]+11, y: hazardModChartDefaultStrumY[5]-70}, 0.25, {ease: FlxEase.quadOut});
						}else{
							FlxTween.tween(playerStrums.members[3], {x:hazardModChartDefaultStrumX[7]+50, y: hazardModChartDefaultStrumY[7]+40}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer4, {x:hazardModChartDefaultStrumX[7]+50, y: hazardModChartDefaultStrumY[7]+40}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[1], {x:hazardModChartDefaultStrumX[5]+11, y: hazardModChartDefaultStrumY[5]+70}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer2, {x:hazardModChartDefaultStrumX[5]+11, y: hazardModChartDefaultStrumY[5]+70}, 0.25, {ease: FlxEase.quadOut});
						}
					case 8:
						KBPINCER_PREPARE(4,true);
						KBPINCER_PREPARE(2,true);
						KBPINCER_PREPARE(1,true);

					//4th pincer move
					case 9: 
						KBPINCER_PREPARE(1,false);
						KBPINCER_PREPARE(2,false);
						KBPINCER_PREPARE(3,false);
						KBPINCER_PREPARE(4,false);
					case 10:
						KBPINCER_GRAB(1);
						KBPINCER_GRAB(2);
						KBPINCER_GRAB(3);
						KBPINCER_GRAB(4);
						if(ClientPrefs.downScroll){
							FlxTween.tween(playerStrums.members[0], {x:hazardModChartDefaultStrumX[4]-16, y: hazardModChartDefaultStrumY[4]-32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer1, {x:hazardModChartDefaultStrumX[4]-16, y: hazardModChartDefaultStrumY[4]-32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[1], {x:hazardModChartDefaultStrumX[5], y: hazardModChartDefaultStrumY[5]+11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer2, {x:hazardModChartDefaultStrumX[5], y: hazardModChartDefaultStrumY[5]+11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[3], {x:hazardModChartDefaultStrumX[7]+16, y: hazardModChartDefaultStrumY[7]-32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer4, {x:hazardModChartDefaultStrumX[7]+16, y: hazardModChartDefaultStrumY[7]-32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[2], {x:hazardModChartDefaultStrumX[6], y: hazardModChartDefaultStrumY[6]+11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer3, {x:hazardModChartDefaultStrumX[6], y: hazardModChartDefaultStrumY[6]+11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[3], {angle:-40}, 0.25, {ease: FlxEase.linear});
							FlxTween.tween(playerStrums.members[0], {angle:40}, 0.25, {ease: FlxEase.linear});
						}else{
							FlxTween.tween(playerStrums.members[0], {x:hazardModChartDefaultStrumX[4]-16, y: hazardModChartDefaultStrumY[4]+32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer1, {x:hazardModChartDefaultStrumX[4]-16, y: hazardModChartDefaultStrumY[4]+32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[1], {x:hazardModChartDefaultStrumX[5], y: hazardModChartDefaultStrumY[5]-11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer2, {x:hazardModChartDefaultStrumX[5], y: hazardModChartDefaultStrumY[5]-11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[3], {x:hazardModChartDefaultStrumX[7]+16, y: hazardModChartDefaultStrumY[7]+32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer4, {x:hazardModChartDefaultStrumX[7]+16, y: hazardModChartDefaultStrumY[7]+32}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[2], {x:hazardModChartDefaultStrumX[6], y: hazardModChartDefaultStrumY[6]-11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(pincer3, {x:hazardModChartDefaultStrumX[6], y: hazardModChartDefaultStrumY[6]-11}, 0.25, {ease: FlxEase.quadOut});
							FlxTween.tween(playerStrums.members[3], {angle:40}, 0.25, {ease: FlxEase.linear});
							FlxTween.tween(playerStrums.members[0], {angle:-40}, 0.25, {ease: FlxEase.linear});
						}
					case 11:
						KBPINCER_PREPARE(1,true);
						KBPINCER_PREPARE(2,true);
						KBPINCER_PREPARE(3,true);
						KBPINCER_PREPARE(4,true);
					
					//Long section
					case 12:
						KBPINCER_PREPARE(4,false);
						KBPINCER_PREPARE(1,false);
					case 13:
						KBPINCER_GRAB(1);
						KBPINCER_GRAB(4);
						FlxTween.tween(playerStrums.members[0], {x:hazardModChartDefaultStrumX[4], y: hazardModChartDefaultStrumY[4]+75}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer1, {x:hazardModChartDefaultStrumX[4], y: hazardModChartDefaultStrumY[4]+75}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(playerStrums.members[3], {x:hazardModChartDefaultStrumX[7], y: hazardModChartDefaultStrumY[7]-75}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer4, {x:hazardModChartDefaultStrumX[7], y: hazardModChartDefaultStrumY[7]-75}, 0.75, {ease: FlxEase.quadInOut});
					case 14:
						FlxTween.tween(playerStrums.members[0], {x:hazardModChartDefaultStrumX[7]}, 0.9, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer1, {x:hazardModChartDefaultStrumX[7]}, 0.9, {ease: FlxEase.quadInOut});
						FlxTween.tween(playerStrums.members[3], {x:hazardModChartDefaultStrumX[4]}, 0.9, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer4, {x:hazardModChartDefaultStrumX[4]}, 0.9, {ease: FlxEase.quadInOut});
					case 15:
						FlxTween.tween(playerStrums.members[0], {x:hazardModChartDefaultStrumX[7], y:hazardModChartDefaultStrumY[7]}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer1, {x:hazardModChartDefaultStrumX[7], y:hazardModChartDefaultStrumY[7]}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(playerStrums.members[3], {x:hazardModChartDefaultStrumX[4], y:hazardModChartDefaultStrumY[4]}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer4, {x:hazardModChartDefaultStrumX[4], y:hazardModChartDefaultStrumY[4]}, 0.75, {ease: FlxEase.quadInOut});

						FlxTween.tween(playerStrums.members[3], {angle:0}, 0.725, {ease: FlxEase.quadOut});
						FlxTween.tween(playerStrums.members[0], {angle:0}, 0.725, {ease: FlxEase.quadOut});
					case 16:
						KBPINCER_PREPARE(4,true);
						KBPINCER_PREPARE(1,true);
						KBPINCER_PREPARE(3,false);
						KBPINCER_PREPARE(2,false);
					case 17:
						KBPINCER_GRAB(2);
						KBPINCER_GRAB(3);
						FlxTween.tween(playerStrums.members[2], {x:hazardModChartDefaultStrumX[6], y:hazardModChartDefaultStrumY[6]+75}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer3, {x:hazardModChartDefaultStrumX[6], y:hazardModChartDefaultStrumY[6]+75}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(playerStrums.members[1], {x:hazardModChartDefaultStrumX[5], y:hazardModChartDefaultStrumY[5]-75}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer2, {x:hazardModChartDefaultStrumX[5], y:hazardModChartDefaultStrumY[5]-75}, 0.75, {ease: FlxEase.quadInOut});
					case 18:
						FlxTween.tween(playerStrums.members[2], {x:hazardModChartDefaultStrumX[5]}, 0.9, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer3, {x:hazardModChartDefaultStrumX[5]}, 0.9, {ease: FlxEase.quadInOut});
						FlxTween.tween(playerStrums.members[1], {x:hazardModChartDefaultStrumX[6]}, 0.9, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer2, {x:hazardModChartDefaultStrumX[6]}, 0.9, {ease: FlxEase.quadInOut});
					case 19:
						FlxTween.tween(playerStrums.members[2], {x:hazardModChartDefaultStrumX[5], y:hazardModChartDefaultStrumY[5]}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer3, {x:hazardModChartDefaultStrumX[5], y:hazardModChartDefaultStrumY[5]}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(playerStrums.members[1], {x:hazardModChartDefaultStrumX[6], y:hazardModChartDefaultStrumY[6]}, 0.75, {ease: FlxEase.quadInOut});
						FlxTween.tween(pincer2, {x:hazardModChartDefaultStrumX[6], y:hazardModChartDefaultStrumY[6]}, 0.75, {ease: FlxEase.quadInOut});
					case 20:
						KBPINCER_PREPARE(3,true);
						KBPINCER_PREPARE(2,true);
					case 21:
						for (i in 0...playerStrums.length) {
							FlxTween.tween(playerStrums.members[i], {angle:0,x:hazardModChartDefaultStrumX[i+4], y:hazardModChartDefaultStrumY[i+4]}, 1.375, {ease: FlxEase.quadInOut});
						}
					case 22: //Prepare screenshake
						KBPINCER_PREPARE(5,false);
						if(forceMiddleScroll)
							KBPINCER_PREPARE(6,false);
						else
							KBPINCER_PREPARE(4,false);
					case 23: //SHAKEY SHAKEY
						KBPINCER_GRAB(1);
						if(forceMiddleScroll)
							KBPINCER_GRAB(2);
						else
							KBPINCER_GRAB(4);
						hazardModChartEffect=2;
					case 24: //Screenshake end
						KBPINCER_PREPARE(5,true);
						if(forceMiddleScroll)
							KBPINCER_PREPARE(6,true);
						else
							KBPINCER_PREPARE(4,true);
						hazardModChartEffect=0;
						camHUD.angle=0;
				}

			case 'ShaderTesting':
				switch(value1.toLowerCase()){
					case "clear":
						clearShaderFromCamera(value2);
						clearShaderFromCamera(value2);
						clearShaderFromCamera(value2);

					case "bloom":
						addShaderToCamera(value2, new BloomEffect(1.0/512.0,0.35));

					case "chroma":
						addShaderToCamera(value2, new ChromaticAberrationEffect(0.005));

					case "scanline":
						addShaderToCamera(value2, new ScanlineEffect(false));

					case "grain":
						addShaderToCamera(value2, new GrainEffect(0.1,0.3,false));

					case "glitch":
						addShaderToCamera(value2, new GlitchEffect(0.1,0.1,0.1));

					case "vcr":
						addShaderToCamera(value2, new VCRDistortionEffect(0.05,true,true,true));

					case "3d":
						addShaderToCamera(value2, new ThreeDEffect(0.3,0.15,0,0.2));
				}

			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				var time:Float = Std.parseFloat(value2);
				if(Math.isNaN(time) || time <= 0) time = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = time;
					} else {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = time;
					}

					if(curStage == 'mall') {
						bottomBoppers.animation.play('hey', true);
						heyTimer = time;
					}
				}
				if(value != 1 && !boyfriend.stunned && !bfDodging) { //Boyfriend dodge/stun take priority.
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = time;
				}

			case 'Set GF Speed':
				var value:Int = Std.parseInt(value1);
				if(Math.isNaN(value)) value = 1;
				gfSpeed = value;

			case 'Blammed Lights':
				var lightId:Int = Std.parseInt(value1);
				if(Math.isNaN(lightId)) lightId = 0;

				if(lightId > 0 && curLightEvent != lightId) {
					if(lightId > 5) lightId = FlxG.random.int(1, 5, [curLightEvent]);

					var color:Int = 0xffffffff;
					switch(lightId) {
						case 1: //Blue
							color = 0xff31a2fd;
						case 2: //Green
							color = 0xff31fd8c;
						case 3: //Pink
							color = 0xfff794f7;
						case 4: //Red
							color = 0xfff96d63;
						case 5: //Orange
							color = 0xfffba633;
					}
					curLightEvent = lightId;

					if(blammedLightsBlack.alpha == 0) {
						if(blammedLightsBlackTween != null) {
							blammedLightsBlackTween.cancel();
						}
						blammedLightsBlackTween = FlxTween.tween(blammedLightsBlack, {alpha: 1}, 1, {ease: FlxEase.quadInOut,
							onComplete: function(twn:FlxTween) {
								blammedLightsBlackTween = null;
							}
						});

						var chars:Array<Character> = [boyfriend, gf, dad];
						for (i in 0...chars.length) {
							if(chars[i].colorTween != null) {
								chars[i].colorTween.cancel();
							}
							chars[i].colorTween = FlxTween.color(chars[i], 1, FlxColor.WHITE, color, {onComplete: function(twn:FlxTween) {
								chars[i].colorTween = null;
							}, ease: FlxEase.quadInOut});
						}
					} else {
						if(blammedLightsBlackTween != null) {
							blammedLightsBlackTween.cancel();
						}
						blammedLightsBlackTween = null;
						blammedLightsBlack.alpha = 1;

						var chars:Array<Character> = [boyfriend, gf, dad];
						for (i in 0...chars.length) {
							if(chars[i].colorTween != null) {
								chars[i].colorTween.cancel();
							}
							chars[i].colorTween = null;
						}
						dad.color = color;
						boyfriend.color = color;
						gf.color = color;
					}
					
					if(curStage == 'philly') {
						if(phillyCityLightsEvent != null) {
							phillyCityLightsEvent.forEach(function(spr:BGSprite) {
								spr.visible = false;
							});
							phillyCityLightsEvent.members[lightId - 1].visible = true;
							phillyCityLightsEvent.members[lightId - 1].alpha = 1;
						}
					}
				} else {
					if(blammedLightsBlack.alpha != 0) {
						if(blammedLightsBlackTween != null) {
							blammedLightsBlackTween.cancel();
						}
						blammedLightsBlackTween = FlxTween.tween(blammedLightsBlack, {alpha: 0}, 1, {ease: FlxEase.quadInOut,
							onComplete: function(twn:FlxTween) {
								blammedLightsBlackTween = null;
							}
						});
					}

					if(curStage == 'philly') {
						phillyCityLights.forEach(function(spr:BGSprite) {
							spr.visible = false;
						});
						phillyCityLightsEvent.forEach(function(spr:BGSprite) {
							spr.visible = false;
						});

						var memb:FlxSprite = phillyCityLightsEvent.members[curLightEvent - 1];
						if(memb != null) {
							memb.visible = true;
							memb.alpha = 1;
							if(phillyCityLightsEventTween != null)
								phillyCityLightsEventTween.cancel();

							phillyCityLightsEventTween = FlxTween.tween(memb, {alpha: 0}, 1, {onComplete: function(twn:FlxTween) {
								phillyCityLightsEventTween = null;
							}, ease: FlxEase.quadInOut});
						}
					}

					var chars:Array<Character> = [boyfriend, gf, dad];
					for (i in 0...chars.length) {
						if(chars[i].colorTween != null) {
							chars[i].colorTween.cancel();
						}
						chars[i].colorTween = FlxTween.color(chars[i], 1, chars[i].color, FlxColor.WHITE, {onComplete: function(twn:FlxTween) {
							chars[i].colorTween = null;
						}, ease: FlxEase.quadInOut});
					}

					curLight = 0;
					curLightEvent = 0;
				}

			case 'Add Camera Zoom':
				if(ClientPrefs.camZooms && FlxG.camera.zoom < 1.35) {
					var camZoom:Float = Std.parseFloat(value1);
					var hudZoom:Float = Std.parseFloat(value2);
					if(Math.isNaN(camZoom)) camZoom = 0.015;
					if(Math.isNaN(hudZoom)) hudZoom = 0.03;

					FlxG.camera.zoom += camZoom;
					camHUD.zoom += hudZoom;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						var val2:Int = Std.parseInt(value2);
						if(Math.isNaN(val2)) val2 = 0;
		
						switch(val2) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}
				char.playAnim(value1, true);
				char.specialAnim = true;

			case 'Camera Follow Pos':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 0;
				if(Math.isNaN(val2)) val2 = 0;

				isCameraOnForcedPos = false;
				if(!Math.isNaN(Std.parseFloat(value1)) || !Math.isNaN(Std.parseFloat(value2))) {
					camFollow.x = val1;
					camFollow.y = val2;
					isCameraOnForcedPos = true;
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}
				char.idleSuffix = value2;
				char.recalculateDanceIdle();

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}

			//V2.1, made it so the the change character event is completely skipped when in low quality. Kept the original event if somebody had a song where the character change is actually important.
			case 'Change Character OPTIONAL':
				if(!ClientPrefs.lowQuality){
					var charType:Int = 0;
					switch(value1) {
						case 'gf' | 'girlfriend':
							charType = 2;
						case 'dad' | 'opponent':
							charType = 1;
						default:
							charType = Std.parseInt(value1);
							if(Math.isNaN(charType)) charType = 0;
					}

					switch(charType) {
						case 0:
							if(boyfriend.curCharacter != value2) {
								if(!boyfriendMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = boyfriend.alpha;
								boyfriend.alpha = 0.00001;
								boyfriend = boyfriendMap.get(value2);
								boyfriend.alpha = lastAlpha;
								iconP1.changeIcon(boyfriend.healthIcon);
							}
							setOnLuas('boyfriendName', boyfriend.curCharacter);

						case 1:
							if(dad.curCharacter != value2) {
								if(!dadMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var wasGf:Bool = dad.curCharacter.startsWith('gf');
								var lastAlpha:Float = dad.alpha;
								dad.alpha = 0.00001;
								dad = dadMap.get(value2);
								if(!dad.curCharacter.startsWith('gf')) {
									if(wasGf) {
										gf.visible = true;
									}
								} else {
									gf.visible = false;
								}
								dad.alpha = lastAlpha;
								iconP2.changeIcon(dad.healthIcon);
							}
							setOnLuas('dadName', dad.curCharacter);

						case 2:
							if(gf.curCharacter != value2) {
								if(!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnLuas('gfName', gf.curCharacter);
					}
					reloadHealthBarColors();
				}

			case 'Change Character':
				var charType:Int = 0;
				switch(value1) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnLuas('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf');
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf')) {
								if(wasGf) {
									gf.visible = true;
								}
							} else {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnLuas('dadName', dad.curCharacter);

					case 2:
						if(gf.curCharacter != value2) {
							if(!gfMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = gf.alpha;
							gf.alpha = 0.00001;
							gf = gfMap.get(value2);
							gf.alpha = lastAlpha;
						}
						setOnLuas('gfName', gf.curCharacter);
				}
				reloadHealthBarColors();
			
			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1;
				if(Math.isNaN(val2)) val2 = 0;

				var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if(val2 <= 0)
				{
					songSpeed = newValue;
				}
				else
				{
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}
		}
		callOnLuas('onEvent', [eventName, value1, value2]);
	}

	function moveCameraSection(?id:Int = 0):Void {
		if(SONG.notes[id] == null) return;

		if (SONG.notes[id].gfSection)
		{
			camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollow.x += gf.cameraPosition[0];
			camFollow.y += gf.cameraPosition[1];
			tweenCamIn();
			callOnLuas('onMoveCamera', ['gf']);
			return;
		}

		if (!SONG.notes[id].mustHitSection)
		{
			moveCamera(true);
			callOnLuas('onMoveCamera', ['dad']);
		}
		else
		{
			moveCamera(false);
			callOnLuas('onMoveCamera', ['boyfriend']);
		}
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if(isDad)
		{
			camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0];
			camFollow.y += dad.cameraPosition[1];
			tweenCamIn();
		}
		else
		{
			camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);

			switch (curStage)
			{
				case 'limo':
					camFollow.x = boyfriend.getMidpoint().x - 300;
				case 'mall':
					camFollow.y = boyfriend.getMidpoint().y - 200;
				case 'school' | 'schoolEvil':
					camFollow.x = boyfriend.getMidpoint().x - 200;
					camFollow.y = boyfriend.getMidpoint().y - 200;
			}
			camFollow.x -= boyfriend.cameraPosition[0];
			camFollow.y += boyfriend.cameraPosition[1];

			if (Paths.formatToSongPath(SONG.song) == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
					function (twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	function tweenCamIn() {
		if (Paths.formatToSongPath(SONG.song) == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3) {
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		}
	}

	function snapCamFollowToPos(x:Float, y:Float) {
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
	}

	function startEndingDialogue(){
		if((isStoryMode || SONG.song.toLowerCase()=="cessation") && !endingCutsceneDone){
			var file:String = Paths.json(Paths.formatToSongPath(SONG.song) + '/dialogueEND'); //Checks for json/Psych Engine dialogue

			//Terminate harder difficulty dialogue lmao
			if(SONG.song.toLowerCase()=="terminate" && storyDifficulty==3){
				file = Paths.json(Paths.formatToSongPath(SONG.song) + '/dialogueEND-alt'); 
				if (OpenFlAssets.exists(file)) {
					canPause = false;
					inCutscene = true;
					camZooming = false;
					endingCutsceneDone=true;
					dialogueJson = DialogueBoxPsych.parseDialogue(file);
					startDialogue(dialogueJson);
				}else{
					file = Paths.json(Paths.formatToSongPath(SONG.song) + '/dialogueEND'); //Defaults back to normal end dialogue if couldn't find -alt
				}
			}

			if (OpenFlAssets.exists(file)) {
				canPause = false;
				inCutscene = true;
				camZooming = false;
				endingCutsceneDone=true;
				dialogueJson = DialogueBoxPsych.parseDialogue(file);
				startDialogue(dialogueJson);
			}else{
				//trace("endSong triggerd from start ending dialogue");
				endSong();
			}
		}else{
			endSong();
			//trace("endSong triggerd from ending dialogue FAIL");
		}
	}

	function finishSong():Void
	{
		if(!endingSong){ //Done to ensure this only triggers once.
			var finishCallback:Void->Void = startEndingDialogue;

			updateTime = false;
			FlxG.sound.music.volume = 0;
			vocals.volume = 0;
			vocals.pause();
			endingSong = true; //So that the dialogue knows what to do after the dialogue is over.

			if(ClientPrefs.noteOffset <= 0) {
				finishCallback();
			} else {
				finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer) {
					finishCallback();
				});
			}
		}
	}


	function endScreenHazard():Void //For displaying the "thank you for playing" screen on Cessation
	{
		var black:FlxSprite = new FlxSprite(-300, -100).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
		black.scrollFactor.set();

		var screen:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('hazard/qt-port/FinalScreen'));
		screen.setGraphicSize(Std.int(screen.width * 0.625));
		screen.antialiasing = ClientPrefs.globalAntialiasing;
		screen.scrollFactor.set();
		screen.screenCenter();

		var hasTriggeredAlready:Bool = false;

		screen.alpha = 0;
		black.alpha = 0;
		
		add(black);
		add(screen);

		FlxTween.tween(camHUD, {alpha:0}, 1, {ease: FlxEase.linear});

		//Fade in code stolen from schoolIntro() >:3
		new FlxTimer().start(0.15, function(swagTimer:FlxTimer)
		{
			black.alpha += 0.075;
			if (black.alpha < 1)
			{
				swagTimer.reset();
			}
			else
			{
				screen.alpha += 0.075;
				if (screen.alpha < 1)
				{
					swagTimer.reset();
				}
				canSkipEndScreen = true;
				//Wait 12 seconds, then do shit -Haz
				new FlxTimer().start(12, function(tmr:FlxTimer)
				{
					if(!hasTriggeredAlready){
						hasTriggeredAlready = true;
						endSong();
					}
				});
			}
		});		
	}

	public var transitioning = false;
	public function endSong():Void
	{
		//Should kill you if you tried to cheat
		//Added a check to make sure this is executed for terminate because of how fucked the notes get -Haz
		if(!startingSong && Paths.formatToSongPath(SONG.song) != 'terminate') {
			notes.forEach(function(daNote:Note) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss * healthLossMultiplier;
				}
			});
			for (daNote in unspawnNotes) {
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss * healthLossMultiplier;
				}
			}

			if(doDeathCheck()) {
				return;
			}
		}
		
		timeBarBG.visible = false;
		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;
		THISISFUCKINGDISGUSTINGPLEASESAVEME = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		if(achievementObj != null) {
			return;
		} else {
			var achieve:String = checkForAchievement();

			if(achieve != null) {
				startAchievement(achieve);
				return;
			}
		}
		#end

		
		#if LUA_ALLOWED
		var ret:Dynamic = callOnLuas('onEndSong', []);
		#else
		var ret:Dynamic = FunkinLua.Function_Continue;
		#end

		if(ret != FunkinLua.Function_Stop && !transitioning) {
			if (SONG.validScore)
			{
				#if !switch
				var percent:Float = ratingPercent;
				if(Math.isNaN(percent)) percent = 0;
				Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);
				#end
			}

			if (chartingMode)
			{
				openChartEditor();
				return;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					FlxG.sound.playMusic(Paths.music('freakyMenu'));

					cancelMusicFadeTween();
					if(FlxTransitionableState.skipNextTransIn) {
						CustomFadeTransition.nextCamera = null;
					}
					MusicBeatState.switchState(new StoryMenuState());

					// if ()
					if(!ClientPrefs.getGameplaySetting('practice', false) && !ClientPrefs.getGameplaySetting('botplay', false)) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);

						if (SONG.validScore)
						{
							Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);
						}

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = CoolUtil.getDifficultyFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					var winterHorrorlandNext = (Paths.formatToSongPath(SONG.song) == "eggnog");
					if (winterHorrorlandNext)
					{
						var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
							-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
						blackShit.scrollFactor.set();
						add(blackShit);
						camHUD.visible = false;

						FlxG.sound.play(Paths.sound('Lights_Shut_off'));
					}

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;

					prevCamFollow = camFollow;
					prevCamFollowPos = camFollowPos;

					PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					if(winterHorrorlandNext) {
						new FlxTimer().start(1.5, function(tmr:FlxTimer) {
							cancelMusicFadeTween();
							LoadingState.loadAndSwitchState(new PlayState());
						});
					} else {
						cancelMusicFadeTween();
						LoadingState.loadAndSwitchState(new PlayState());
					}
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				cancelMusicFadeTween();
				if(FlxTransitionableState.skipNextTransIn) {
					CustomFadeTransition.nextCamera = null;
				}
				MusicBeatState.switchState(new FreeplayState());
				if(Paths.formatToSongPath(SONG.song) == 'cessation') {
					trace("Play Cessation end music.");
					FlxG.sound.playMusic(Paths.music('thanks'));
				}else{
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				changedDifficulty = false;
			}
			transitioning = true;
		}
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementObject = null;
	function startAchievement(achieve:String) {
		achievementObj = new AchievementObject(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}
	function achievementEnd():Void
	{
		achievementObj = null;
		if(endingSong && !inCutscene) {
			endSong();
			//trace("endSong triggerd from achievement end");
		}
	}
	#end

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;
	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);
		//trace(noteDiff, ' ' + Math.abs(note.strumTime - Conductor.songPosition));

		// boyfriend.playAnim('hey');
		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.35;
		//

		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:String = Conductor.judgeNote(note, noteDiff);

		switch (daRating)
		{
			case "shit": // shit
				totalNotesHit += 0;
				score = 50;
				shits++;
			case "bad": // bad
				totalNotesHit += 0.5;
				score = 100;
				bads++;
			case "good": // good
				totalNotesHit += 0.75;
				score = 200;
				goods++;
			case "sick": // sick
				totalNotesHit += 1;
				sicks++;
		}


		if(daRating == 'sick' && !note.noteSplashDisabled)
		{
			spawnNoteSplashOnNote(note);

			//Makes KB's strums move back a bit to show his power... or something idfk it looks cool okay? -Haz
			//Ported for BF. I don't know but it feels pretty buggy ngl
			if(boyfriend.curCharacter.startsWith('kb') && !note.isSustainNote){
				//trace("KB shit");
				playerStrums.members[note.noteData].y = hazardModChartDefaultStrumY[note.noteData+4] + (ClientPrefs.downScroll ? 22: -22);
				FlxTween.tween(playerStrums.members[note.noteData], {y: hazardModChartDefaultStrumY[note.noteData+4]}, 0.126, {ease: FlxEase.cubeOut});
			}
		}

		if(!practiceMode && !cpuControlled) {
			songScore += score;
			songHits++;
			totalPlayed++;
			RecalculateRating();

			if(ClientPrefs.scoreZoom)
			{
				if(scoreTxtTween != null) {
					scoreTxtTween.cancel();
				}
				scoreTxt.scale.x = 1.075;
				scoreTxt.scale.y = 1.075;
				scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
					onComplete: function(twn:FlxTween) {
						scoreTxtTween = null;
					}
				});
			}
		}

		/* if (combo > 60)
				daRating = 'sick';
			else if (combo > 12)
				daRating = 'good'
			else if (combo > 4)
				daRating = 'bad';
		 */

		var pixelShitPart1:String = "";
		var pixelShitPart2:String = '';

		if (PlayState.isPixelStage)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.image(pixelShitPart1 + daRating + pixelShitPart2));
		rating.cameras = [camHUD];
		rating.screenCenter();
		rating.x = coolText.x - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.visible = !ClientPrefs.hideHud;
		rating.x += ClientPrefs.comboOffset[0];
		rating.y -= ClientPrefs.comboOffset[1];


		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
		comboSpr.cameras = [camHUD];
		comboSpr.screenCenter();
		comboSpr.x = coolText.x;
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.y -= 150;
		comboSpr.visible = !ClientPrefs.hideHud;
		comboSpr.x += ClientPrefs.comboOffset[0];
		comboSpr.y -= ClientPrefs.comboOffset[1];


		comboSpr.velocity.x += FlxG.random.int(1, 10);
		insert(members.indexOf(strumLineNotes), rating);

		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			rating.antialiasing = ClientPrefs.globalAntialiasing;
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			comboSpr.antialiasing = ClientPrefs.globalAntialiasing;
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var seperatedScore:Array<Int> = [];

		if(combo >= 1000) {
			seperatedScore.push(Math.floor(combo / 1000) % 10);
		}
		seperatedScore.push(Math.floor(combo / 100) % 10);
		seperatedScore.push(Math.floor(combo / 10) % 10);
		seperatedScore.push(combo % 10);

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2));
			numScore.cameras = [camHUD];
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * daLoop) - 90;
			numScore.y += 80;

			numScore.x += ClientPrefs.comboOffset[2];
			numScore.y -= ClientPrefs.comboOffset[3];

			if (!PlayState.isPixelStage)
			{
				numScore.antialiasing = ClientPrefs.globalAntialiasing;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);
			numScore.visible = !ClientPrefs.hideHud;

			//if (combo >= 10 || combo == 0)
				insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}
		/* 
			trace(combo);
			trace(seperatedScore);
		 */

		coolText.text = Std.string(seperatedScore);
		// add(coolText);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		//trace('Pressed: ' + eventKey);

		if (!cpuControlled && !paused && key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED) || ClientPrefs.controllerMode))
		{
			if(!boyfriend.stunned && generatedMusic && !endingSong)
			{
				//more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.ghostTapping;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				//var notesDatas:Array<Int> = [];
				var notesStopped:Bool = false;

				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive(function(daNote:Note)
				{
					if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote)
					{
						if(daNote.noteData == key)
						{
							sortedNotesList.push(daNote);
							//notesDatas.push(daNote.noteData);
						}
						canMiss = true;
					}
				});
				sortedNotesList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				if (sortedNotesList.length > 0) {
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes) {
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							} else
								notesStopped = true;
						}
							
						// eee jack detection before was not super good
						if (!notesStopped) {
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}

					}
				}
				else if (canMiss) {
					noteMissPress(key);
					callOnLuas('noteMissPress', [key]);
				}

				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				keysPressed[key] = true;

				//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if(spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			if(controlsPlayer2){
				var spr:StrumNote = opponentStrums.members[key];
				if(spr != null)
				{
					spr.playAnim('pressed');
					spr.resetAnim = 0;
				}
			}
			callOnLuas('onKeyPress', [key]);
		}
		//trace('pressed: ' + controlArray);
	}
	
	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if(!cpuControlled && !paused && key > -1)
		{
			var spr:StrumNote = playerStrums.members[key];
			if(spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			if(controlsPlayer2){
				var spr:StrumNote = opponentStrums.members[key];
				if(spr != null)
				{
					spr.playAnim('static');
					spr.resetAnim = 0;
				}
			}
			callOnLuas('onKeyRelease', [key]);
		}
		//trace('released: ' + controlArray);
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if(key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	//Oh come on, really? You're not even going to change the dodge code?!
	//Dodge code, yes it's bad but oh well. -Haz
	//var dodgeButton = controls.ACCEPT; //I have no idea how to add custom controls so fuck it. -Haz
	function bfDodge():Void{
		//trace('DODGE START!');
		bfDodging = true;
		bfCanDodge = false;

		//if(qtIsBlueScreened)
			//boyfriend404.playAnim('dodge');
		//else
		boyfriend.playAnim('dodge');

		FlxG.sound.play(Paths.sound('hazard/dodge01'));

		//Wait, then set bfDodging back to false. -Haz
		//V1.2 - Timer lasts a bit longer (by 0.00225)
		new FlxTimer().start(bfDodgeTiming, function(tmr:FlxTimer) 	//COMMENT THIS IF YOU WANT TO USE DOUBLE SAW VARIATIONS!
		{
			bfDodging=false;
			boyfriend.dance(); //V1.3 = This forces the animation to end when you are no longer safe as the animation keeps misleading people.
			//trace('DODGE END!');
			//Cooldown timer so you can't keep spamming it.
			//V1.3 = Incremented this by a little (0.005)
			//new FlxTimer().start(0.1135, function(tmr:FlxTimer) 	//COMMENT THIS IF YOU WANT TO USE DOUBLE SAW VARIATIONS!
			//new FlxTimer().start(0.1, function(tmr:FlxTimer) 		//UNCOMMENT THIS IF YOU WANT TO USE DOUBLE SAW VARIATIONS!
			new FlxTimer().start(bfDodgeCooldown, function(tmr:FlxTimer) 	//COMMENT THIS IF YOU WANT TO USE DOUBLE SAW VARIATIONS!
			{
				bfCanDodge=true;
				//trace('DODGE RECHARGED!');
			});
		});
	}


	// Hold notes
	private function keyShit():Void
	{
		if(SONG.dodgeEnabled){
			// FlxG.keys.justPressed.SPACE
			if(FlxG.keys.anyJustPressed(dodgeKey) && !bfDodging && bfCanDodge){
				bfDodge();
			}
		}

		// HOLDING
		var up = controls.NOTE_UP;
		var right = controls.NOTE_RIGHT;
		var down = controls.NOTE_DOWN;
		var left = controls.NOTE_LEFT;
		var controlHoldArray:Array<Bool> = [left, down, up, right];
		
		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [controls.NOTE_LEFT_P, controls.NOTE_DOWN_P, controls.NOTE_UP_P, controls.NOTE_RIGHT_P];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}

		// FlxG.watch.addQuick('asdfa', upP);
		if (!boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			notes.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (daNote.isSustainNote && controlHoldArray[daNote.noteData] && daNote.canBeHit 
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit) {
					goodNoteHit(daNote);
				}
			});


			//Fuck you, I added a taunt button because it's funny! -Haz
			//FlxG.keys.justPressed.SHIFT
			if(!inhumanSong && FlxG.keys.anyJustPressed(tauntKey) && !bfDodging && !controlHoldArray.contains(true) && !boyfriend.animation.curAnim.name.endsWith('miss') && boyfriend.specialAnim == false){
				boyfriend.playAnim('hey', true);
				boyfriend.specialAnim = true;
				boyfriend.heyTimer = 0.59;
				FlxG.sound.play(Paths.sound('hey'));
				tauntCounter++;
				trace("taunts: ",tauntCounter);
			}

			if (controlHoldArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			} else if (!boyfriend.stunned && !bfDodging && boyfriend.holdTimer > Conductor.stepCrochet * 0.001 * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing')
			&& !boyfriend.animation.curAnim.name.endsWith('miss'))
				boyfriend.dance();
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [controls.NOTE_LEFT_R, controls.NOTE_DOWN_R, controls.NOTE_UP_R, controls.NOTE_RIGHT_R];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		combo = 0;
														//Less miss health when stunned since you can't really do anything while stunned and it'll be too unfair to deal full damage.
		health -= (daNote.missHealth * healthLoss * healthLossMultiplier)  * (boyfriend.stunned ? 0.195 : 1);
		causeOfDeath = 'health';
		if(instakillOnMiss)
		{
			vocals.volume = 0;
			doDeathCheck(true);
		}

		//For testing purposes
		//trace(daNote.missHealth);
		songMisses++;
		vocals.volume = 0;
		if(!practiceMode) songScore -= 10;
		
		totalPlayed++;
		RecalculateRating();

		var char:Character = boyfriend;
		if(daNote.gfNote) {
			char = gf;
		}

		if(char.hasMissAnimations && !bfDodging && !boyfriend.stunned)
		{
			var daAlt = '';
			if(daNote.noteType == 'Alt Animation') daAlt = '-alt';

			var animToPlay:String = singAnimations[Std.int(Math.abs(daNote.noteData))] + 'miss' + daAlt;
			char.playAnim(animToPlay, true);
		}

		callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if (!boyfriend.stunned)
		{
			health -= 0.05 * healthLoss * healthLossMultiplier;
			if(instakillOnMiss)
			{
				vocals.volume = 0;
				doDeathCheck(true);
			}

			if(ClientPrefs.ghostTapping) return;

			if (combo > 5 && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
			}
			combo = 0;

			if(!practiceMode) songScore -= 10;
			if(!endingSong) {
				songMisses++;
			}
			totalPlayed++;
			RecalculateRating();

			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
			// FlxG.sound.play(Paths.sound('missnote1'), 1, false);
			// FlxG.log.add('played imss note');

			/*boyfriend.stunned = true;

			// get stunned for 1/60 of a second, makes you able to
			new FlxTimer().start(1 / 60, function(tmr:FlxTimer)
			{
				boyfriend.stunned = false;
			});*/

			//Would be cool to make BF change colour when missing while dodging / stunned to communicate that the player is still missing in these states. -Haz
			//Update, I decided to implement this!
			if(boyfriend.hasMissAnimations && !bfDodging && !boyfriend.stunned) {
				boyfriend.playAnim(singAnimations[Std.int(Math.abs(direction))] + 'miss', true);
			}else if(boyfriend.hasMissAnimations && (bfDodging || boyfriend.stunned)){
				boyfriend.color = FlxColor.BLUE;
			}
			vocals.volume = 0;
		}
	}

	function opponentNoteHit(note:Note):Void
	{
		if (Paths.formatToSongPath(SONG.song) != 'tutorial')
			camZooming = true;

		//Dad Health Drain Code. It's scuffed, but gets the job done -Haz
		//Only works on Hard difficulty.
		//v2.2: Updated to support Harder difficulty.
		if((storyDifficulty == 2 || storyDifficulty == 3 || SONG.song.toLowerCase()=="termination" || SONG.song.toLowerCase()=="cessation") && dadDrainHealth>0 && !note.ignoreNote && !note.hitCausesMiss){
			//prevents health drain if the drain would kill the player.
			if(health - dadDrainHealth - 0.1 > maxHealth){
				//And here I thought that this code couldn't get any worse. What is wrong with me?

				//Health drain on sustain notes. Note that this is ignored if you've been hit by 2 or more sawblades.
				if(dadDrainHealthSustain && note.isSustainNote && sawbladeHits < 2){
					switch(sawbladeHits){
						case 0:
							if(health < 1.35){
								if(health < 0.8){
									//trace("0 - AWWW SHIT");
									health -= dadDrainHealth/8.1; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}else{
									//trace("0 - fuck you, you're above halfway now");
									health -= dadDrainHealth/5.7; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}
							}else{
								//trace("0 - Nah, no nerfing just yet");
								health -= dadDrainHealth/4.375;
							}
						case 1:
							if(health < 1.5){
								if(health < 1){
									//trace("1 - AWWW SHIT");
									health -= dadDrainHealth/8.62; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}else{
									//trace("1 - fuck you, you're above halfway now");
									health -= dadDrainHealth/6.1; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}
							}else{
								//trace("1 - Nah, no nerfing just yet");
								health -= dadDrainHealth/4.38;
							}
						case 2:
							if(health < 1.8125){
								if(health < 1.43){
									//trace("2 - AWWW SHIT");
									health -= dadDrainHealth/9.3; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}else{
									//trace("2 - fuck you, you're above halfway now");
									health -= dadDrainHealth/6.65; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}
							}else{
								//trace("2 - Nah, no nerfing just yet");
								health -= dadDrainHealth/4.46;
							}
						default:
							//This shouldn't trigger in normal circumstances.
							if(health < 1.6){
								//trace("DEFAULT - AWWW SHIT");
								health -= dadDrainHealth/8.25; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
							}else{
								//trace("DEFAULT - fuck you, you're above halfway now");
								health -= dadDrainHealth/6.25; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
							}
						}
				}else if (!note.isSustainNote){
					if(sawbladeHits > 3){
						health -= dadDrainHealth/3.15; //At this point, just constantly nerf the opponent.
						//trace("+3 - You're completely fucked.");
					}else{
						switch(sawbladeHits){
							case 0:
								if(health < 1.35){
									if(health < 0.8){
										//trace("0 - AWWW SHIT");
										health -= dadDrainHealth/3; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
									}else{
										//trace("0 - fuck you, you're above halfway now");
										health -= dadDrainHealth/1.75; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
									}
								}else{
									//trace("0 - Nah, no nerfing just yet");
									health -= dadDrainHealth;
								}
							case 1:
								if(health < 1.5){
									if(health < 1){
										//trace("1 - AWWW SHIT");
										health -= dadDrainHealth/3; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
									}else{
										//trace("1 - fuck you, you're above halfway now");
										health -= dadDrainHealth/1.77; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
									}
								}else{
									//trace("1 - Nah, no nerfing just yet");
									health -= dadDrainHealth/1.1;
								}
							case 2:
								if(health < 1.8125){
									if(health < 1.45){
										//trace("2 - AWWW SHIT");
										health -= dadDrainHealth/3.1; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
									}else{
										//trace("2 - fuck you, you're above halfway now");
										health -= dadDrainHealth/2; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
									}
								}else{
									//trace("2 - Nah, no nerfing just yet");
									health -= dadDrainHealth/1.2;
								}
							case 3:
								if(health < 1.82){
									//trace("3 - AWWW SHIT");
									health -= dadDrainHealth/3.3; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}else{
									//trace("3 - fuck you, you're above halfway now");
									health -= dadDrainHealth/2.4; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}
							default:
								//This shouldn't trigger in normal circumstances.
								if(health < 1.6){
									//trace("DEFAULT - AWWW SHIT");
									health -= dadDrainHealth/3; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}else{
									//trace("DEFAULT - fuck you, you're above halfway now");
									health -= dadDrainHealth/1.5; //nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
								}
						}
					}
				}
			}
				//I FUCKING HATE WORKING WITH PERCENTAGES HOLY SHIT
				//I GIVE UP ON THIS SHIT, I'M JUST MAKING IT SO THAT IT'S SET POINTS NOW.
				/*
				if(health < 0.475 * (2 + maxHealth)){
					if(health < 0.2 * (2 + maxHealth)){
						trace("AWWW SHIT");
						health -= dadDrainHealth/3; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
					}else{
						trace("fuck you, you're above halfway now");
						health -= dadDrainHealth/1.75; //Massively nerfs the amount of health Opponent can recover if over halfway to give the player more room to breath health-wise.
					}
				}else{
					trace("Nah, no nerfing just yet");
					health -= dadDrainHealth;
					}
				}*/
		}

		if(note.noteType == 'Hey!' && dad.animOffsets.exists('hey')) {
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		} else if(!note.ignoreNote && !note.hitCausesMiss) { //Added ignoreNote and hitMiss check to stop animations from playing from hurt notes. -Haz
			var altAnim:String = "";

			//Makes KB's strums move back a bit to show his power... or something idfk it looks cool okay? -Haz
			if(dad.curCharacter.startsWith('kb') && !note.isSustainNote){
				opponentStrums.members[note.noteData].y = hazardModChartDefaultStrumY[note.noteData] + (ClientPrefs.downScroll ? 22: -22);
				FlxTween.tween(opponentStrums.members[note.noteData], {y: hazardModChartDefaultStrumY[note.noteData]}, 0.125, {ease: FlxEase.cubeOut});
			}
			else if((dad.curCharacter == "qt_annoyed" || dad.curCharacter == "qt-nervous") && FlxG.random.int(1, 18) == 2)
			{
				//Code for QT's random "glitch" alt animation to play.
				altAnim = '-alt';
				
				//Probably a better way of doing this by using the random int and throwing that at the end of the string... but I'm stupid and lazy. -Haz
				switch(FlxG.random.int(1, 3))
				{
					case 2:
						FlxG.sound.play(Paths.sound('hazard/glitch-error02'));
					case 3:
						FlxG.sound.play(Paths.sound('hazard/glitch-error03'));
					default:
						FlxG.sound.play(Paths.sound('hazard/glitch-error01'));
				}

				//10% chance of an eye appearing on TV when glitching
				if(curStage == "street-real" && FlxG.random.bool(10)){ 
					if(!(curBeat >= 190 && curStep <= 898)){ //Makes sure the alert animation stuff isn't happening when the TV is playing the alert animation.
						if(FlxG.random.bool(52)) //Randomises whether the eye appears on left or right screen.
							qt_tv01.animation.play('eyeLeft');
						else
							qt_tv01.animation.play('eyeRight');

						qt_tv01.animation.finishCallback = function(pog:String){
							if(qt_tv01.animation.curAnim.name == 'eyeLeft' || qt_tv01.animation.curAnim.name == 'eyeRight'){ //Making sure this only executes for only the eye animation played by the random chance. Probably a better way of doing it, but eh. -Haz
								qt_tv01.animation.play('idle');
							}
						}
					}
				}
			}
			if (!note.noAnimation)
			{
			var curSection:Int = Math.floor(curStep / 16);
			if (SONG.notes[curSection] != null)
			{
				if (SONG.notes[curSection].altAnim || note.noteType == 'Alt Animation') {
					altAnim = '-alt';
				}
			}
			if(SONG.song.toLowerCase() == "cessation"){
				if(curBeat >= 199 && curBeat <= 262) //first drop
				{
					altAnim = '-together';
				}
				else if(curBeat >= 300)
				{
					altAnim = '-together';
				}
			}

			var char:Character = dad;
			var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))] + altAnim;
			if(note.gfNote) {
				char = gf;
			}

			char.playAnim(animToPlay, true);
			char.holdTimer = 0;
		}
		}

		if (SONG.needsVoices && !inhumanSong) //Player2/Opponent can't restore vocals, only player1 can.
			vocals.volume = 1;

		var time:Float = 0.15;
		if(!controlsPlayer2 || cpuControlled){
			if(!note.ignoreNote && !note.hitCausesMiss){
				if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end')) {
					time += 0.15;
				}
				StrumPlayAnim(true, Std.int(Math.abs(note.noteData)) % 4, time);
			}
		}
		note.hitByOpponent = true;

		callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);

		if (!note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			if(cpuControlled && (note.ignoreNote || note.hitCausesMiss)) return;

			if(note.hitCausesMiss) {
				noteMiss(note);
				if(!note.noteSplashDisabled && !note.isSustainNote) {
					spawnNoteSplashOnNote(note);
				}
				
				causeOfDeath = "hurt";
				
				switch(note.noteType) {
					case 'Hurt Note': //Hurt note
						if(boyfriend.animation.getByName('hurt') != null) {
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
					case 'Invisible Hurt Note': //Hurt note
						if(boyfriend.animation.getByName('hurt') != null) {
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
				}
				
				note.wasGoodHit = true;
				if (!note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote)
			{
				//hitsound ported from charting state LMAO.
				if(ClientPrefs.hitsoundVolume > 0){
					FlxG.sound.play(Paths.sound('ChartingTick'), ClientPrefs.hitsoundVolume).pan = note.noteData < 4? -0.3 : 0.3; //would be coolio
				}

				combo += 1;
				popUpScore(note);
				if(combo > 9999) combo = 9999;

				//Fuck you, no health gain on sustain notes.
				health += note.hitHealth * healthGain * healthGainMultiplier; 
			}

			if(!note.noAnimation && !bfDodging && !boyfriend.stunned) {
				var daAlt = '';
				if(note.noteType == 'Alt Animation') daAlt = '-alt';
	
				var animToPlay:String = singAnimations[Std.int(Math.abs(note.noteData))];

				//if (note.isSustainNote){ wouldn't this be fun : P. i think it would be swell
					
					//if(note.gfNote) {
					//  var anim = animToPlay +"-hold" + daAlt;
					//	if(gf.animation.getByName(anim) == null)anim = animToPlay + daAlt;
					//	gf.playAnim(anim, true);
					//	gf.holdTimer = 0;
					//} else {
					//  var anim = animToPlay +"-hold" + daAlt;
					//	if(boyfriend.animation.getByName(anim) == null)anim = animToPlay + daAlt;
					//	boyfriend.playAnim(anim, true);
					//	boyfriend.holdTimer = 0;
					//}
				//}else{
					if(note.gfNote) {
						gf.playAnim(animToPlay + daAlt, true);
						gf.holdTimer = 0;
					} else {
						boyfriend.playAnim(animToPlay + daAlt, true);
						boyfriend.holdTimer = 0;
					}
				//}
				if(note.noteType == 'Hey!') {
					if(boyfriend.animOffsets.exists('hey')) {
						boyfriend.playAnim('hey', true);
						boyfriend.specialAnim = true;
						boyfriend.heyTimer = 0.6;
					}
	
					if(gf.animOffsets.exists('cheer')) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = 0.6;
					}
				}
			}

			if(cpuControlled) {
				var time:Float = 0.15;
				if(note.isSustainNote && !note.animation.curAnim.name.endsWith('end')) {
					time += 0.15;
				}
				StrumPlayAnim(false, Std.int(Math.abs(note.noteData)) % 4, time);
			} else {
				playerStrums.forEach(function(spr:StrumNote)
				{
					if (Math.abs(note.noteData) == spr.ID)
					{
						spr.playAnim('confirm', true);
					}
				});
			}
			note.wasGoodHit = true;
			vocals.volume = 1;

			var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
			var leData:Int = Math.round(Math.abs(note.noteData));
			var leType:String = note.noteType;
			callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	function spawnNoteSplashOnNote(note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var skin:String = 'noteSplashes';
		if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) skin = PlayState.SONG.splashSkin;
		
		var hue:Float = ClientPrefs.arrowHSV[data % 4][0] / 360;
		var sat:Float = ClientPrefs.arrowHSV[data % 4][1] / 100;
		var brt:Float = ClientPrefs.arrowHSV[data % 4][2] / 100;
		if(note != null) {
			skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	var fastCarCanDrive:Bool = true;

	function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	var carTimer:FlxTimer;
	function fastCarDrive()
	{
		//trace('Car drive');
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			resetFastCar();
			carTimer = null;
		});
	}

	var trainMoving:Bool = false;
	var trainFrameTiming:Float = 0;

	var trainCars:Int = 8;
	var trainFinishing:Bool = false;
	var trainCooldown:Int = 0;

	function trainStart():Void
	{
		trainMoving = true;
		if (!trainSound.playing)
			trainSound.play(true);
	}

	var startedMoving:Bool = false;

	function updateTrainPos():Void
	{
		if (trainSound.time >= 4700)
		{
			startedMoving = true;
			gf.playAnim('hairBlow');
			gf.specialAnim = true;
		}

		if (startedMoving)
		{
			phillyTrain.x -= 400;

			if (phillyTrain.x < -2000 && !trainFinishing)
			{
				phillyTrain.x = -1150;
				trainCars -= 1;

				if (trainCars <= 0)
					trainFinishing = true;
			}

			if (phillyTrain.x < -4000 && trainFinishing)
				trainReset();
		}
	}

	function trainReset():Void
	{
		gf.danced = false; //Sets head to the correct position once the animation ends
		gf.playAnim('hairFall');
		gf.specialAnim = true;
		phillyTrain.x = FlxG.width + 200;
		trainMoving = false;
		// trainSound.stop();
		// trainSound.time = 0;
		trainCars = 8;
		trainFinishing = false;
		startedMoving = false;
	}

	private var preventLuaRemove:Bool = false;
	override function destroy() {
		preventLuaRemove = true;
		for (i in 0...luaArray.length) {
			luaArray[i].call('onDestroy', []);
			luaArray[i].stop();
		}
		luaArray = [];

		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		super.destroy();
	}

	public static function cancelMusicFadeTween() {
		if(FlxG.sound.music.fadeTween != null) {
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	public function removeLua(lua:FunkinLua) {
		if(luaArray != null && !preventLuaRemove) {
			luaArray.remove(lua);
		}
	}




	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();
		if (FlxG.sound.music.time > Conductor.songPosition + 20 || FlxG.sound.music.time < Conductor.songPosition - 20)
		{
			resyncVocals();
		}

		//if(interlopeChroma != null){
			//trace("intensity:",interlopeChromaIntensity);
			//trace("intensity:",interlopeFadeinShaderIntensity);
		//}

		if(curStep == lastStepHit) {
			return;
		}

		//if(fogShitDEBUG != null){
		//	trace("FogShitDEBUG X: ",fogShitDEBUG.x);
		//}
		
		if(fogShitGroup != null) {
			fogShitGroup.forEach(function(fog:FogThing) {
				fog.x += fog.movementSpeed;
				if(fog.x >= 2050){
					//trace("LoopBack!!!");
					fog.x = -2050;
					if(!fog.isUpperLayer)
						fog.y = 50 + FlxG.random.float(-24,24);
					else
						fog.y = FlxG.random.float(-6,18);
					fog.regenerate();
				}
			});
		}

		if(gfScared && curStep % 2 == 0)
		{
			gf.playAnim('scared', true);
			//if(!ClientPrefs.lowQuality)
				//gf404.playAnim('scared', true);
		}


		//v2.2 update: Opponent arrows now just copy the rotation of the players notes so they never desync.
		if(noteSpeen==1){
			if(curStep % 2 == 0){
				for (i in 0...playerStrums.length) {
					playerStrums.members[i].angle += 22.5;
					//opponentStrums.members[i].angle += 22.5;

					//overflow shit
					//if(opponentStrums.members[i].angle >= 360){
					//	opponentStrums.members[i].angle = (opponentStrums.members[i].angle % 360) * 360;
					//}
					if(playerStrums.members[i].angle >= 360){
						playerStrums.members[i].angle = (playerStrums.members[i].angle % 360) * 360;
					}
					opponentStrums.members[i].angle = playerStrums.members[i].angle;
				}
			}
		}else if(noteSpeen==2){
			for (i in 0...playerStrums.length) {
				playerStrums.members[i].angle += 22.5;
				//opponentStrums.members[i].angle += 22.5;

				//overflow shit
				//if(opponentStrums.members[i].angle >= 360){
				//	opponentStrums.members[i].angle = (opponentStrums.members[i].angle % 360) * 360;
				//}
				if(playerStrums.members[i].angle >= 360){
					playerStrums.members[i].angle = (playerStrums.members[i].angle % 360) * 360;
				}
				opponentStrums.members[i].angle = playerStrums.members[i].angle;
			}
		}
		
		lastStepHit = curStep;
		setOnLuas('curStep', curStep);
		callOnLuas('onStepHit', []);
	}

	var lastBeatHit:Int = -1;
	
	
	//Call this function to update the visuals for Censory overload!
	function CensoryOverload404():Void
	{
		trace("This literally does nothing now. Isn't that funny?!");
		/*
		if(qtIsBlueScreened){
			//Hide original versions
			boyfriend.alpha = 0;
			gf.alpha = 0;
			dad.alpha = 0;

			//New versions un-hidden.
			boyfriend404.alpha = 1;
			gf404.alpha = 1;
			dad404.alpha = 1;
		}
		else{ //Reset back to normal

			//Return to original sprites.
			boyfriend404.alpha = 0;
			gf404.alpha = 0;
			dad404.alpha = 0;

			//Hide 404 versions
			boyfriend.alpha = 1;
			gf.alpha = 1;
			dad.alpha = 1;
		}
		*/
	}
	
	override function beatHit()
	{
		super.beatHit();

		if(lastBeatHit >= curBeat) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		if(hazardBGpulsing && ClientPrefs.flashing){
			hazardBGkb.animation.play('pulse');
		}

		if(hazardModChartEffect == 6){
			//scrollspeed pulse effect
			var scrollSpeedShit:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			songSpeed = 1;
			songSpeedTween = FlxTween.tween(this, {songSpeed: scrollSpeedShit}, 0.37, {ease: FlxEase.sineOut, onComplete:
				function (twn:FlxTween)
				{
					songSpeedTween = null;
				}
			});
		}else if(hazardModChartEffect == 5 || hazardModChartEffect == 3){
			if(interlopeChroma != null)
				interlopeChromaIntensity = 0.018;
			if(curBeat % 2 == 0){
				trace("Left");
				for (i in 0...playerStrums.length) {
					playerStrums.members[i].x = hazardModChartDefaultStrumX[i+4] -300;
					opponentStrums.members[i].x = hazardModChartDefaultStrumX[i+4] +300;
				}
			}else{
				trace("Right");
				for (i in 0...playerStrums.length) {
					playerStrums.members[i].x = hazardModChartDefaultStrumX[i+4] +300;
					opponentStrums.members[i].x = hazardModChartDefaultStrumX[i+4] -300;
				}
			}
		}

		if(qtTVstate==8){  
			qt_tv01.animation.play("heart");
		}else if(qtTVstate==1){
			qt_tv01.animation.play("alert");
		}

		if (SONG.notes[Math.floor(curStep / 16)] != null)
		{
			if (SONG.notes[Math.floor(curStep / 16)].changeBPM)
			{
				Conductor.changeBPM(SONG.notes[Math.floor(curStep / 16)].bpm);
				//FlxG.log.add('CHANGED BPM!');
				setOnLuas('curBpm', Conductor.bpm);
				setOnLuas('crochet', Conductor.crochet);
				setOnLuas('stepCrochet', Conductor.stepCrochet);
			}
			setOnLuas('mustHitSection', SONG.notes[Math.floor(curStep / 16)].mustHitSection);
			setOnLuas('altAnim', SONG.notes[Math.floor(curStep / 16)].altAnim);
			setOnLuas('gfSection', SONG.notes[Math.floor(curStep / 16)].gfSection);
			// else
			// Conductor.changeBPM(SONG.bpm);
		}
		// FlxG.log.add('change bpm' + SONG.notes[Std.int(curStep / 16)].changeBPM);

		if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
		{
			moveCameraSection(Std.int(curStep / 16));
		}
		if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms && curBeat % 4 == 0)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		if (!gfScared && curBeat % gfSpeed == 0 && !gf.stunned && gf.animation.curAnim.name != null && !gf.animation.curAnim.name.startsWith("sing"))
		{
			gf.dance();
		}

		if(curBeat % 2 == 0) {
			if (!bfDodging && !boyfriend.stunned && boyfriend.animation.curAnim.name != null && !boyfriend.animation.curAnim.name.startsWith("sing"))
			{
				boyfriend.dance();
			}
			if (dad.animation.curAnim.name != null && !dad.animation.curAnim.name.startsWith("sing") && !dad.stunned)
			{
				dad.dance();
			}
		} else if(dad.danceIdle && dad.animation.curAnim.name != null && !dad.curCharacter.startsWith('gf') && !dad.animation.curAnim.name.startsWith("sing") && !dad.stunned) {
			dad.dance();
		}


		switch(SONG.song.toLowerCase()){
			case 'interlope':
				if((curBeat >= 448 && curBeat < 510) || (curBeat >= 512 && curBeat < 574) || (curBeat >= 575 && curBeat < 640))
				{
					if(camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
					{
						FlxG.camera.zoom += 0.0075;
						camHUD.zoom += 0.015;
					}
				}
			case 'termination':
				if(curBeat >= 192 && curBeat <= 320) //1st drop
				{
					if(camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
					{
						FlxG.camera.zoom += 0.0075;
						camHUD.zoom += 0.015;
					}
				}
				else if(curBeat >= 512 && curBeat <= 640) //1st drop
				{
					if(camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
					{
						FlxG.camera.zoom += 0.0075;
						camHUD.zoom += 0.015;
					}
				}
				else if(curBeat >= 832 && curBeat <= 1088) //last drop
				{
					if(camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
					{
						FlxG.camera.zoom += 0.0075;
						camHUD.zoom += 0.015;
					}
				}
			case 'censory-overload':
				if(curBeat >= 80 && curBeat <= 208) //first drop
				{
					//Gas Release effect
					if (curBeat % 16 == 0 && !ClientPrefs.lowQuality)
					{
						qt_gas01.animation.play('burst');
						qt_gas02.animation.play('burst');
					}
				}
				else if(curBeat >= 304 && curBeat <= 432) //second drop
				{
					if(camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
					{
						FlxG.camera.zoom += 0.0075;
						camHUD.zoom += 0.015;
					}
	
					//Gas Release effect
					if (curBeat % 8 == 0 && !ClientPrefs.lowQuality)
					{
						qt_gas01.animation.play('burstALT');
						qt_gas02.animation.play('burstALT');
					}
				}
				else if(curBeat >= 560 && curBeat <= 688){ //third drop
					if(camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
					{
						FlxG.camera.zoom += 0.0075;
						camHUD.zoom += 0.015;
					}
					//Gas Release effect
					if (curBeat % 4 == 0 && !ClientPrefs.lowQuality)
					{
						qt_gas01.animation.play('burstFAST');
						qt_gas02.animation.play('burstFAST');
					}
				}
				else if(curBeat >= 832 && curBeat <= 960){ //final drop
					if(camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
					{
						FlxG.camera.zoom += 0.0075;
						camHUD.zoom += 0.015;
					}

					//Gas Release effect
					if (curBeat % 4 == 2 && !ClientPrefs.lowQuality)
					{
						qt_gas01.animation.play('burstFAST');
						qt_gas02.animation.play('burstFAST');
					}
				}
				else if((curBeat == 976 || curBeat == 992) && camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms){ //Extra zooms for distorted kicks at end
					FlxG.camera.zoom += 0.031;
					camHUD.zoom += 0.062;
				}else if(curBeat == 702 && !ClientPrefs.lowQuality){
					qt_gas01.animation.play('burst');
					qt_gas02.animation.play('burst');
				}

		}

		switch (curStage)
		{
			case 'school':
				if(!ClientPrefs.lowQuality) {
					bgGirls.dance();
				}

			case 'mall':
				if(!ClientPrefs.lowQuality) {
					upperBoppers.dance(true);
				}

				if(heyTimer <= 0) bottomBoppers.dance(true);
				santa.dance(true);

			case 'limo':
				if(!ClientPrefs.lowQuality) {
					grpLimoDancers.forEach(function(dancer:BackgroundDancer)
					{
						dancer.dance();
					});
				}

				if (FlxG.random.bool(10) && fastCarCanDrive)
					fastCarDrive();
			case "philly":
				if (!trainMoving)
					trainCooldown += 1;

				if (curBeat % 4 == 0)
				{
					phillyCityLights.forEach(function(light:BGSprite)
					{
						light.visible = false;
					});

					curLight = FlxG.random.int(0, phillyCityLights.length - 1, [curLight]);

					phillyCityLights.members[curLight].visible = true;
					phillyCityLights.members[curLight].alpha = 1;
				}

				if (curBeat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8)
				{
					trainCooldown = FlxG.random.int(-4, 0);
					trainStart();
				}
		}

		lastBeatHit = curBeat;

		setOnLuas('curBeat', curBeat);//DAWGG?????
		callOnLuas('onBeatHit', []);
	}

	public var closeLuas:Array<FunkinLua> = [];
	public function callOnLuas(event:String, args:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			var ret:Dynamic = luaArray[i].call(event, args);
			if(ret != FunkinLua.Function_Continue) {
				returnVal = ret;
			}
		}

		for (i in 0...closeLuas.length) {
			luaArray.remove(closeLuas[i]);
			closeLuas[i].stop();
		}
		#end
		return returnVal;
	}

	public function setOnLuas(variable:String, arg:Dynamic) {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			luaArray[i].set(variable, arg);
		}
		#end
	}

	function StrumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = strumLineNotes.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating() {
		setOnLuas('score', songScore);
		setOnLuas('misses', songMisses);
		setOnLuas('hits', songHits);

		var ret:Dynamic = callOnLuas('onRecalculateRating', []);
		if(ret != FunkinLua.Function_Stop)
		{
			if(totalPlayed < 1) //Prevent divide by 0
				ratingName = '?';
			else
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				if(ratingPercent >= 1)
				{
					ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				}
				else
				{
					for (i in 0...ratingStuff.length-1)
					{
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}

			// Rating FC
			ratingFC = "";
			if (sicks > 0) ratingFC = "SFC";
			if (goods > 0) ratingFC = "GFC";
			if (bads > 0 || shits > 0) ratingFC = "FC";
			if (songMisses > 0 && songMisses < 10) ratingFC = "SDCB";
			else if (songMisses >= 10) ratingFC = "Clear";
		}
		setOnLuas('rating', ratingPercent);
		setOnLuas('ratingName', ratingName);
		setOnLuas('ratingFC', ratingFC);
	}

	public static var othersCodeName:String = 'otherAchievements';
	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null):String {

		if(chartingMode) return null;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice', false) || ClientPrefs.getGameplaySetting('botplay', false));
		var achievementsToCheck:Array<String> = achievesToCheck;
		if (achievementsToCheck == null) {
			achievementsToCheck = [];
			for (i in 0...Achievements.achievementsStuff.length) {
				achievementsToCheck.push(Achievements.achievementsStuff[i][2]);
			}
			achievementsToCheck.push(othersCodeName);
		}

		for (i in 0...achievementsToCheck.length) {
			var achievementName:String = achievementsToCheck[i];
			var unlock:Bool = false;

			/*
			if (achievementName == othersCodeName) {
				if(isStoryMode && campaignMisses + songMisses < 1 && CoolUtil.difficultyString() == 'HARD' && storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
				{
					var weekName:String = WeekData.getWeekFileName();

					for (json in Achievements.loadedAchievements) {
						if (json.unlocksAfter == weekName && !Achievements.isAchievementUnlocked(json.icon) && !json.customGoal) unlock = true;
						achievementName = json.icon;
					}

					for (k in 0...Achievements.achievementsStuff.length) {
						var unlockPoint:String = Achievements.achievementsStuff[k][3];
						if (unlockPoint != null) {
							if (unlockPoint == weekName && !unlock && !Achievements.isAchievementUnlocked(Achievements.achievementsStuff[k][2])) unlock = true;
							achievementName = Achievements.achievementsStuff[k][2];
						}
					}
				}
			}
			*/

			for (json in Achievements.loadedAchievements) { //Requires jsons for call
				var ret:Dynamic = callOnLuas('onCheckForAchievement', [json.icon]); //Set custom goals

				//IDK, like
				// if getProperty('misses') > 10 and leName == 'lmao_skill_issue' then return Function_Continue end

				if (ret == FunkinLua.Function_Continue && !Achievements.isAchievementUnlocked(json.icon) && json.customGoal && !unlock) {
					unlock = true;
					achievementName = json.icon;
				}
			}

			if(!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled && !unlock) {
				switch(achievementName)
				{
					case 'sawblade_death':
						if(Achievements.sawbladeDeath >= 24){
							unlock = true;
						}
					case 'sawblade_hell':
						if(Paths.formatToSongPath(SONG.song) == 'termination' && !usedPractice && sawbladeHits >=3) {
							unlock = true;
						}
					case 'taunter':
						if(Paths.formatToSongPath(SONG.song) == 'termination' && !usedPractice && tauntCounter > 100) {
							unlock = true;
						}
					case 'tutorial_hard':
						if(Paths.formatToSongPath(SONG.song) == 'tutorial' && !usedPractice && CoolUtil.difficultyString() == 'HARD') {
							unlock = true;
						}
					case 'qtweek_hard':
						if(WeekData.getWeekFileName().toLowerCase() == 'qt' && isStoryMode && CoolUtil.difficultyString() == 'HARD' && storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice) {
							unlock = true;
						}//Can unlock the achievement if playing on Harder.
						else if(WeekData.getWeekFileName().toLowerCase() == 'qt' && isStoryMode && CoolUtil.difficultyString() == 'HARDER' && storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice) {
							unlock = true;
						}
					case 'ur_bad':
						if(ratingPercent < 0.2 && !usedPractice && Paths.formatToSongPath(SONG.song) != 'terminate') {
							unlock = true;
						}
					case 'ur_good':
						if(ratingPercent >= 1 && !usedPractice && Paths.formatToSongPath(SONG.song) != 'terminate') {
							unlock = true;
						}
					case 'termination_beat':
						if(Paths.formatToSongPath(SONG.song) == 'termination' && !usedPractice && storyDifficulty==1) {
							unlock = true;
						}
					case 'termination_old':
						if(Paths.formatToSongPath(SONG.song) == 'termination' && !usedPractice && storyDifficulty==2) {
							unlock = true;
						}
					case 'cessation_beat':
						if(Paths.formatToSongPath(SONG.song) == 'cessation' && !usedPractice) {
							unlock = true;
						}
					case 'cessation_troll':
						if(Paths.formatToSongPath(SONG.song) == 'cessation' && cessationTrollDone == true){ //Can still be gotten even if you used practise
							unlock = true;
							//cessationTrollDone
						}
					case 'freeplay_depths':
						if(Paths.formatToSongPath(SONG.song) == 'interlope' && !usedPractice) {
							unlock = true;
						}
				}
			}

			if(unlock) {
				Achievements.unlockAchievement(achievementName);
				return achievementName;
			}
		}
		return null;
	}
	#end

	var curLight:Int = 0;
	var curLightEvent:Int = 0;
}
