class X2Action_DelayedEvac extends X2Action_Evac;

var private CustomAnimParams DelayedAnimParams;

//------------------------------------------------------------------------------------------------
simulated state Executing
{
Begin:
        RequestRopeArchetype();
        Sleep(0.2 * `SYNC_RAND(10));
        SpawnAndPlayRopeAnim();

        DelayedAnimParams.AnimName = 'HL_EvacStart';
        DelayedAnimParams.PlayRate = GetNonCriticalAnimationSpeed();
        FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(DelayedAnimParams));

        CompleteAction();
}

defaultproperties
{
}
