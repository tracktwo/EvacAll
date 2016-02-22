/*
 * X2Actor_NoEvacTileGroup
 *
 * Actor to represent a group of no-evac tiles in an evac zone. Owns all the static mesh actors
 * that are displayed on the map.
 */
class X2Actor_NoEvacTileGroup extends Actor 
	placeable;

var array<X2Actor_NoEvacTile> NoEvacTiles;
var int ObjectID;

function InitTiles(XComGameState_NoEvacTiles NoEvacTilesState)
{
	local X2Actor_NoEvacTile NoEvacTile;
	local vector TileLocation;
	local XComWorldData WorldData;
	local TTile Tile;
	local Object ThisObj; 

	if (NoEvacTilesState != none)
	{
		// Clear out any existing tiles
		DestroyTileActors();

		WorldData = `XWORLD;

		ObjectID = NoEvacTilesState.ObjectID;
		`XCOMHISTORY.SetVisualizer(ObjectID, self);

		// Create all the tile actors
		foreach NoEvacTilesState.NoEvacTiles (Tile)
		{
			NoEvacTile = `BATTLE.spawn(class'X2Actor_NoEvacTile');
			TileLocation = WorldData.GetPositionFromTileCoordinates(Tile);
			TileLocation.Z = WorldData.GetFloorZForPosition(TileLocation) + 4;
			NoEvacTile.SetLocation(TileLocation);
			NoEvacTile.SetHidden(false);
			NoEvacTiles.AddItem(NoEvacTile);
		}

		// And register ourselves to pay attention if the evac zone gets nuked
		ThisObj = self;
		`XEVENTMGR.RegisterForEvent(ThisObj, 'EvacZoneDestroyed', OnEvacZoneDestroyed, ELD_OnStateSubmitted);
	}
}

function DestroyTileActors()
{
	local X2Actor_NoEvacTile NoEvacActor;
	
	foreach NoEvacTiles(NoEvacActor)
	{
		NoEvacActor.Destroy();
	}

	NoEvacTiles.Length = 0;	
}

// Evac zone has been destroyed! Destroy all our blocked tile actors and return.
function EventListenerReturn OnEvacZoneDestroyed(Object EventData, Object EventSource, XComGameState GameState, Name InEventID)
{
	local Object ThisObj;

	DestroyTileActors();
	ThisObj = self;
	`XEVENTMGR.UnregisterFromEvent(ThisObj, 'EvacZoneDestroyed');

	return ELR_NoInterrupt;
}
