class UIScreenListener_TacticalHUD_EvacAll extends UIScreenListener
	config(EvacAll);

var array<X2Actor_NoEvacTile> mBlockedTiles;

var const config bool ShowNoEvacTiles;

// Workaround to add the evac all ability to each xcom unit. Loop over all units on tactical UI load and
// add the ability to each one that doesn't already have it.
event OnInit(UIScreen Screen)
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate AbilityTemplate;
	local XComGameState_HeadquartersXCom XComHQ;
	local Object ThisObj;
	local XComGameState_NoEvacTiles NoEvacTilesState;
	local int i;
	
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	
	// Locate the evac all ability template
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate('EvacAll');

	// ** Legacy code: Add the ability to each squad member that doesn't already have it. **
    //
    // Note: This was how EvacAll was originally implemented, back before we had the new helpful DLCInfo
    // hooks. I now place the EvacAll ability on each appropriate character template after the templates
    // are loaded. This code remains to support old campaigns where there are characters that already exist
    // but that do not yet have the ability. This method isn't preferred because it only works on tactical
    // HUD init, which means that mods that enable Restart Mission will not re-add the ability to soldiers
    // after a mission restart as the event doesn't fire on the 2nd or subsequent attempt but all the soldiers
    // are reset to the start state.
    //
    // I can't reliably use the OnLoadedSaveGame hook either, because this mod may already be registered in
    // those campaigns and won't be fired again. So this code will likely need to be here forever.
	for (i = 0; i < XComHQ.Squad.Length; ++i) 
	{
		EnsureAbilityOnUnit(XComHQ.Squad[i], AbilityTemplate);
	}

	if (ShowNoEvacTiles)
	{
		// Register an event handler for the 'EvacZonePlaced' event so we can update the tile data to show the
		// inaccessible tiles.
		ThisObj = self;
		`XEVENTMGR.RegisterForEvent(ThisObj, 'EvacZonePlaced', OnEvacZonePlaced, ELD_OnVisualizationBlockCompleted, 50);

		// If we have a NoEvac state visualize it.
		NoEvacTilesState = class'XComGameState_NoEvacTiles'.static.LookupNoEvacTilesState();
		if (NoEvacTilesState != none)
		{
			NoEvacTilesState.FindOrCreateVisualizer();
			NoEvacTilesState.SyncVisualizer();
		}
	}
}

// Ensure the unit represented by the given reference has the EvacAll ability
function EnsureAbilityOnUnit(StateObjectReference UnitStateRef, X2AbilityTemplate AbilityTemplate)
{
	local XComGameState_Unit UnitState, NewUnitState;
	local XComGameState_Ability AbilityState;
	local StateObjectReference StateObjectRef;
	local XComGameState NewGameState;

	// Find the current unit state for this unit
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectId(UnitStateRef.ObjectID));

	// Loop over all the abilities they have
	foreach UnitState.Abilities(StateObjectRef) 
	{
		AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(StateObjectRef.ObjectID));

		// If the unit already has this ability, don't add a new one.
		if (AbilityState.GetMyTemplateName() == 'EvacAll')
		{
			return;
		}
	}

    `Log(" *** Unit " $ UnitState.GetFullname() $ " does not have evac all ability. Adding");

	// Construct a new unit game state for this unit, adding an instance of the ability
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Add EvacAll Ability");
	NewUnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
	AbilityState = AbilityTemplate.CreateInstanceFromTemplate(NewGameState);
	AbilityState.InitAbilityForUnit(NewUnitState, NewGameState);
	NewGameState.AddStateObject(AbilityState);
	NewUnitState.Abilities.AddItem(AbilityState.GetReference());
	NewGameState.AddStateObject(NewUnitState);

	// Submit the new state
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}


function EventListenerReturn OnEvacZonePlaced(Object EventData, Object EventSource, XComGameState GameState, Name InEventID)
{
	local XComGameState_EvacZone EvacState;
	local XComGameState NewGameState;
	local TTile Min, Max, TestTile;
	local array<TTile> NoEvacTiles;
	local int x, y;
	local int IsOnFloor;
	local XComWorldData WorldData;
	
	EvacState = XComGameState_EvacZone(EventSource);
	WorldData = `XWORLD;
	class'XComGameState_EvacZone'.static.GetEvacMinMax(EvacState.CenterLocation, Min, Max);

	TestTile.Z = EvacState.CenterLocation.Z;
	for (x = Min.X; x <= Max.X; ++x) 
	{
		TestTile.X = x;
		for (y = Min.Y; y <= Max.Y; ++y)
		{
			TestTile.Y = y;

			// If this tile is not a valid evac tile, add it to our list. But don't bother with tiles
			// that are not valid destinations.
			if (!class'X2TargetingMethod_EvacZone'.static.ValidateEvacTile(TestTile, IsOnFloor) && 
				WorldData.CanUnitsEnterTile(TestTile))
			{
				`Log("Invalid tile at " $ x $ ", " $ y);
				NoEvacTiles.AddItem(TestTile);
			}
		}
	}

	if (NoEvacTiles.Length > 0) 
	{
		// Create a new state for our no-evac tile placement.
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set NoEvac Tiles");	

		// Create the state for our bad tiles and add it to NewGameState.
		class'XComGameState_NoEvacTiles'.static.CreateNoEvacTilesState(NewGameState, NoEvacTiles);

		// Create and sync the visualizer to create the blocked tile actors
		XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = BuildVisualizationForNoEvacTiles;
		
		`TACTICALRULES.SubmitGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

function BuildVisualizationForNoEvacTiles(XComGameState VisualizeGameState, out array<VisualizationTrack> OutVisualizationTracks)
{
	local VisualizationTrack Track;
	local XComGameState_NoEvacTiles NoEvacTilesState;

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_NoEvacTiles', NoEvacTilesState)
	{
		break;
	}
	`assert(NoEvacTilesState != none);

	// Create a visualization track
	Track.StateObject_NewState = NoEvacTilesState;
	Track.StateObject_OldState = NoEvacTilesState;
	Track.TrackActor = NoEvacTilesState.GetVisualizer();
	class 'X2Action_NoEvacTiles'.static.AddToVisualizationTrack(Track, VisualizeGameState.GetContext());
	OutVisualizationTracks.AddItem(Track);
}

defaultProperties
{
    ScreenClass = UITacticalHUD
}