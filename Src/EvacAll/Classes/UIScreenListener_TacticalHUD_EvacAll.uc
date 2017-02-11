class UIScreenListener_TacticalHUD_EvacAll extends UIScreenListener
	config(EvacAll);

var array<X2Actor_NoEvacTile> mBlockedTiles;

var const config bool ShowNoEvacTiles;

// Handle event registration so we can paint overlays on inaccessible tiles. The evac all ability is no longer
// handled here, this is now done purely through template modifications in the DLCInfo (which weren't available
// until the Alien Hunters patch).
event OnInit(UIScreen Screen)
{
	local Object ThisObj;
	local XComGameState_NoEvacTiles NoEvacTilesState;

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