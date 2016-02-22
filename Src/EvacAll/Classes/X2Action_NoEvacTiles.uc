
/* X2Action_NoEvacTiles: An "action" for visualizing the blocked tiles in an evac zone. */

class X2Action_NoEvacTiles extends X2Action;

var XComGameState_NoEvacTiles NoEvacTilesState;

function Init(const out VisualizationTrack InTrack)
{
	super.Init(InTrack);

	NoEvacTilesState = XComGameState_NoEvacTiles(InTrack.StateObject_NewState);
}

simulated state Executing
{
Begin:
	NoEvacTilesState.FindOrCreateVisualizer();
	NoEvacTilesState.SyncVisualizer();
	CompleteAction();
}

