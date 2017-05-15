class X2Action_DelayedEvac extends X2Action_Evac;

var private CustomAnimParams DelayedAnimParams;

// Custom LW2 evac animations supported as of v1.3.
const CustomEvacLW2Version = 103000000;

var bool UseVanillaAnim;

// Find which version of LW2 is installed (if any)
function int GetLW2Version()
{
	local X2StrategyElementTemplateManager StratMgr;
	local X2StrategyElementTemplate StrategyTemplate;
	local LWXComGameVersionTemplate LWVersionTemplate;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	StrategyTemplate = StratMgr.FindStrategyElementTemplate('LWXComGameVersion');
	if (StrategyTemplate == none)
	{
		return 0;
	}

	LWVersionTemplate = LWXComGameVersionTemplate(StrategyTemplate);
	return LWVersionTemplate.GetVersionNumber();
}

//------------------------------------------------------------------------------------------------
simulated state Executing
{
Begin:
	// Assume we'll be using the vanilla animation
	UseVanillaAnim = true;

	if (bIsVisualizingGremlin)
	{
		// Don't need the normal anim for gremlins
		UseVanillaAnim = false;
		DelayedAnimParams.AnimName = 'HL_EvacStart';
		DelayedAnimParams.PlayRate = GetNonCriticalAnimationSpeed();

		FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(DelayedAnimParams));
		UnitPawn.UpdatePawnVisibility();
		CompleteAction();
	}
	else if (GetLW2Version() >= CustomEvacLW2Version)
	{
		AnimOverrideIdx = GetAnimOverride();
		if (AnimOverrideIdx >= 0)
		{
			// Using custom anim
			UseVanillaAnim = false;

			// Not using a rope, so just sleep a bit.
			Sleep(0.2f * `SYNC_RAND(10));

			if (AnimOverrides[AnimOverrideIdx].PreAnim != '')
			{
				DelayedAnimParams.AnimName = AnimOverrides[AnimOverrideIdx].PreAnim;
				DelayedAnimParams.PlayRate = GetNonCriticalAnimationSpeed();
				FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(DelayedAnimParams));
			}

			UnitPawn.bSkipIK = true;
			UnitPawn.EnableRMA(true, true);
			UnitPawn.EnableRMAInteractPhysics(true);

			DelayedAnimParams.AnimName = AnimOverrides[AnimOverrideIdx].AnimName;
			DelayedAnimParams.PlayRate = GetNonCriticalAnimationSpeed();
			StartingAtom.Rotation = QuatFromRotator(UnitPawn.Rotation);
			StartingAtom.Translation = UnitPawn.Location;
			StartingAtom.Scale = 1.0f;
			UnitPawn.GetAnimTreeController().GetDesiredEndingAtomFromStartingAtom(DelayedAnimParams, StartingAtom);
			FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(DelayedAnimParams));
			CompleteAction();
		}
	}

	// Vanilla evac behavior
	if (UseVanillaAnim)
	{
		if( UnitPawn.EvacWithRope )
		{
		RequestRopeArchetype();
		Sleep(0.2f * `SYNC_RAND(10));
		SpawnAndPlayRopeAnim();
		}
		else
		{
			// Not using a rope, so just sleep a bit.
			Sleep(0.2f * `SYNC_RAND(10));
		}
		DelayedAnimParams.AnimName = 'HL_EvacStart';
		DelayedAnimParams.PlayRate = GetNonCriticalAnimationSpeed();
		FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(DelayedAnimParams));
		CompleteAction();
	}
}

defaultproperties
{
}
