/*
 * X2Actor_NoEvacTile: A static mesh to represent a single blocked tile in an evac zone.
 */

class X2Actor_NoEvacTile extends StaticMeshActor;

var protected string MeshPath;

simulated event PostBeginPlay()
{
	local StaticMesh TargetMesh;

	super.PostBeginPlay();

	TargetMesh = StaticMesh(`CONTENT.RequestGameArchetype(default.MeshPath));
	`assert(TargetMesh != none);
	StaticMeshComponent.SetStaticMesh(TargetMesh);
}

DefaultProperties
{
	Begin Object Name=StaticMeshComponent0
		bOwnerNoSee=FALSE
		CastShadow=FALSE
		CollideActors=FALSE
		BlockActors=FALSE
		BlockZeroExtent=FALSE
		BlockNonZeroExtent=FALSE
		BlockRigidBody=FALSE
		HiddenGame=FALSE
		HideDuringCinematicView=true
	End Object

	bStatic=FALSE
	bWorldGeometry=FALSE
	bMovable=TRUE

	MeshPath="UI_EvacAll.NoEvacTile"
}