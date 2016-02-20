class UIScreenListener_TacticalHUD_EvacAll extends UIScreenListener;

var array<X2Actor_NoEvacTile> mBlockedTiles;

// Workaround to add the evac all ability to each xcom unit. Loop over all units on tactical UI load and
// add the ability to each one that doesn't already have it.
event OnInit(UIScreen Screen)
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate AbilityTemplate;
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference RewardUnitRef;
	local XComGameState_MissionSite Mission;
	local XComGameState_BattleData BattleData;
	local Object ThisObj;
	local StaticMesh WaypointMesh;
	local Texture2dArray StatusTextureArray;
	local Texture2D LootTexture;
	local XComGameState_NoEvacTiles NoEvacTilesState;
	local int i;
	
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	Mission = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(BattleData.m_iMissionID));
	//Mission = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));

	// Locate the evac all ability template
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate('EvacAll');

	// Add the ability to each squad member that doesn't already have it.
	for (i = 0; i < XComHQ.Squad.Length; ++i) 
	{
		EnsureAbilityOnUnit(XComHQ.Squad[i], AbilityTemplate);
	}

	if (Mission != none)
	{
		// If the mission has a reward VIP, add it to them too
		RewardUnitRef = Mission.GetRewardVIP();
		if (RewardUnitRef.ObjectID > 0)
		{
			EnsureAbilityOnUnit(RewardUnitRef, AbilityTemplate);
		}
	}

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
	local XComGameStateHistory History;
	local XComGameStateContext_ChangeContainer ChangeContainer;
	local XComGameState_EvacZone EvacState;
	local XComGameState NewGameState;
	local TTile Min, Max, TestTile;
	local array<TTile> NoEvacTiles;
	local int x, y;
	local int IsOnFloor;
	local XComWorldData WorldData;
	local TilePosPair OutPair;
	local X2Actor_NoEvacTile NoEvacMeshActor;
	local vector MeshTranslation;
	local SimpleShapeManager ShapeManager;
	local XComGameState_NoEvacTiles NoEvacTilesState;
	local VisualizationTrack Track;
	
	
	//local XComGameState NewGameState;
	`Log("*** OnEvacZonePlaced");

	EvacState = XComGameState_EvacZone(EventSource);
	`Log("*** Center tile is " $ EvacState.CenterLocation.X $ ", " $ EvacState.CenterLocation.Y);

	WorldData = `XWORLD;
	class'XComGameState_EvacZone'.static.GetEvacMinMax(EvacState.CenterLocation, Min, Max);

	TestTile.Z = EvacState.CenterLocation.Z;
	for (x = Min.X; x <= Max.X; ++x) 
	{
		TestTile.X = x;
		for (y = Min.Y; y <= Max.Y; ++y)
		{
			TestTile.Y = y;
			if (!class'X2TargetingMethod_EvacZone'.static.ValidateEvacTile(TestTile, IsOnFloor))
			{
				`Log("Invalid tile at " $ x $ ", " $ y);
				NoEvacTiles.AddItem(TestTile);
			}
		}
	}

	if (NoEvacTiles.Length > 0) 
	{
		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set NoEvac Hazards");

		/*
				//Defer to the game state that triggered us for timing.
		if (GameState.GetContext().DesiredVisualizationBlockIndex > -1)
		{
			ChangeContainer.SetDesiredVisualizationBlockIndex(GameState.GetContext().DesiredVisualizationBlockIndex);
		}
		else
		{
			ChangeContainer.SetDesiredVisualizationBlockIndex(GameState.HistoryIndex);
		}*/
			
		
		//NewGameState = History.CreateNewGameState(true, ChangeContainer);
		NoEvacTilesState = class'XComGameState_NoEvacTiles'.static.CreateNoEvacTilesState(NewGameState, NoEvacTiles);
		
		// Create and sync the visualizer to create the blocked tile actors
		XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = BuildVisualizationForNoEvacTiles;
		
		`TACTICALRULES.SubmitGameState(NewGameState);


	}
	/*
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("UpdateNoEvacTiles");
		EffectState = XComGameState_Effect(NewGameState.CreateStateObject(Class, ObjectID));
		NewGameState.AddStateObject(EffectState);
		++EffectState.AttacksReceived;

	SubmitNewGameState(NewGameState);
	*/
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