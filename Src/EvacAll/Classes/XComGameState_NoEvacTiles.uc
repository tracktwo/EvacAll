class XComGameState_NoEvacTiles extends XComGameState_BaseObject;

var array<TTile> NoEvacTiles;

static function XComGameState_NoEvacTiles LookupNoEvacTilesState()
{
	local XComGameState_NoEvacTiles GameState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_NoEvacTiles', GameState)
	{
		return GameState;
	}

	return none;
}

static function XComGameState_NoEvacTiles CreateNoEvacTilesState(XComGameState NewGameState, const out array<TTile> BlockedTiles)
{
	local XComGameState_NoEvacTiles NoEvacTilesState;

	// See if we already have one.
	NoEvacTilesState = LookupNoEvacTilesState();
	if (NoEvacTilesState == none)
	{
		// Don't already have one. Make a new one.
		NoEvacTilesState = XComGameState_NoEvacTiles(NewGameState.CreateStateObject(class'XComGameState_NoEvacTiles'));
	}
	else
	{
		// We already had one, we're going to be updating the existing one.
		NoEvacTilesState = XComGameState_NoEvacTiles(NewGameState.CreateStateObject(NoEvacTilesState.Class, NoEvacTilesState.ObjectID));
	}

	NoEvacTilesState.NoEvacTiles = BlockedTiles;
	NoEvacTilesState.FindOrCreateVisualizer();
	NewGameState.AddStateObject(NoEvacTilesState);

	return NoEvacTilesState;
}

function Actor FindOrCreateVisualizer(optional XComGameState GameState = none)
{
	local X2Actor_NoEvacTileGroup NoEvacTilesActor;

	NoEvacTilesActor = X2Actor_NoEvacTileGroup(GetVisualizer());
	
	if (NoEvacTilesActor != none)
	{
		NoEvacTilesActor.Destroy();
	}

	NoEvacTilesActor = `BATTLE.Spawn(class'X2Actor_NoEvacTileGroup');
	`XCOMHISTORY.SetVisualizer(ObjectID, NoEvacTilesActor);

	return NoEvacTilesActor;
}

function SyncVisualizer(optional XComGameState GameState = none)
{
	local X2Actor_NoEvacTileGroup NoEvacTilesActor;

	NoEvacTilesActor = X2Actor_NoEvacTileGroup(GetVisualizer());
	NoEvacTilesActor.InitTiles(self);
}

function AppendAdditionalSyncActions( out VisualizationTrack BuildTrack )
{
}
