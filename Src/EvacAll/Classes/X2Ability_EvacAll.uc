class X2Ability_EvacAll extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(EvacAllAbility());
	return Templates;
}

static function X2AbilityTemplate EvacAllAbility()
{
	local X2AbilityTemplate             Template;
	local X2AbilityCost_ActionPoints    ActionPointCost;
	local X2AbilityTrigger_PlayerInput  PlayerInput;
	local X2Condition_UnitValue			UnitValue;	
	local X2Condition_UnitProperty      UnitProperty;
	local array<name>                   SkipExclusions;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'EvacAll');

	Template.RemoveTemplateAvailablility(Template.BITFIELD_GAMEAREA_Multiplayer); // Do not allow "Evac All" in MP!

	Template.Hostility = eHostility_Neutral;

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_ShowIfAvailable;
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.PLACE_EVAC_PRIORITY;
	Template.IconImage = "img:///UI_EvacAll.UIPerk_evac_all";
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	Template.bAllowedByDefault = true;

	// Allow anyone to evac.
	SkipExclusions.AddItem(class'X2Ability_CarryUnit'.default.CarryUnitEffectName);
	SkipExclusions.AddItem(class'X2AbilityTemplateManager'.default.DisorientedName);
	SkipExclusions.AddItem(class'X2StatusEffects'.default.BurningName);
	Template.AddShooterEffectExclusions(SkipExclusions);

	UnitProperty = new class'X2Condition_UnitProperty';
	UnitProperty.ExcludeDead = true;
	UnitProperty.ExcludeFriendlyToSource = false;
	UnitProperty.ExcludeHostileToSource = true;
	Template.AbilityShooterConditions.AddItem(UnitProperty);

	Template.AbilityToHitCalc = default.DeadEye;

	Template.AbilityTargetStyle = default.SelfTarget;
	PlayerInput = new class'X2AbilityTrigger_PlayerInput';
	Template.AbilityTriggers.AddItem(PlayerInput);	


	// Only allow when evac is allowed.
	UnitValue = new class'X2Condition_UnitValue';
	UnitValue.AddCheckValue(class'X2Ability_DefaultAbilitySet'.default.EvacThisTurnName, class'X2Ability_DefaultAbilitySet'.default.MAX_EVAC_PER_TURN, eCheck_LessThan);
	Template.AbilityShooterConditions.AddItem(UnitValue);
	Template.AbilityShooterConditions.AddItem(new class'X2Condition_UnitInEvacZone');

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 0;
	ActionPointCost.bFreeCost = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Template.BuildNewGameStateFn = EvacAll_BuildGameState;
	Template.BuildVisualizationFn = EvacAll_BuildVisualization;
	return Template;
}


simulated function XComGameState EvacAll_BuildGameState( XComGameStateContext Context )
{
	local XComGameStateHistory History;
	local XComGameState_Ability AbilityState;
	local StateObjectReference AbilityRef;
	local XComGameState_Unit GameStateUnit;

	History = `XCOMHISTORY;
	
	foreach History.IterateByClassType(class'XComGameState_Unit', GameStateUnit)
	{
		if (GameStateUnit.bRemovedFromPlay)
		{
				continue;
		}

		AbilityRef = GameStateUnit.FindAbility('Evac');
		AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(AbilityRef.ObjectID));

		if (AbilityState.CanActivateAbility(GameStateUnit) == 'AA_Success')
		{
			DoEvac(GameStateUnit, AbilityState.GetReference());
		}
	}

	// Return a dummy empty game state: DoEvac will have handled creating and submitting all the real
	// state changes for each evac.
	return TypicalAbility_BuildGameState(Context);
}

function DoEvac(XComGameState_Unit GameStateUnit, StateObjectReference AbilityRef)
{
	local int i, j;
	local X2TacticalGameRuleset TacticalRules;
	local GameRulesCache_Unit UnitCache;

	TacticalRules = `TACTICALRULES;

	if(TacticalRules.GetGameRulesCache_Unit(GameStateUnit.GetReference(), UnitCache))
	{
		for( i = 0; i < UnitCache.AvailableActions.Length; ++i )
		{
			if( UnitCache.AvailableActions[i].AbilityObjectRef.ObjectID == AbilityRef.ObjectID )
			{
				for( j = 0; j < UnitCache.AvailableActions[i].AvailableTargets.Length; ++j )
				{
					if( UnitCache.AvailableActions[i].AvailableTargets[j].PrimaryTarget == GameStateUnit.GetReference())
					{
						if( UnitCache.AvailableActions[i].AvailableCode == 'AA_Success' )
						{
							class'XComGameStateContext_Ability'.static.ActivateAbility(UnitCache.AvailableActions[i], j);
						}
						break;
					}
				}
				break;
			}
		}
	}
}

function EvacAll_BuildVisualization(XComGameState VisualizeGameState, out array<VisualizationTrack> OutVisualizationTracks)
{
	local XComGameStateHistory History;
	local XComGameStateContext_Ability  Context;
	local StateObjectReference          InteractingUnitRef;
	local XComGameState_Ability         Ability;

	local VisualizationTrack        EmptyTrack;
	local VisualizationTrack        BuildTrack;

	local X2Action_PlaySoundAndFlyOver SoundAndFlyOver;

	History = `XCOMHISTORY;

	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	InteractingUnitRef = Context.InputContext.SourceObject;

	BuildTrack = EmptyTrack;
	BuildTrack.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	BuildTrack.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
	BuildTrack.TrackActor = History.GetVisualizer(InteractingUnitRef.ObjectID);
					
	Ability = XComGameState_Ability(History.GetGameStateForObjectID(Context.InputContext.AbilityRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1));
	SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()));
	SoundAndFlyOver.SetSoundAndFlyOverParameters(None, Ability.GetMyTemplate().LocFlyOverText, '', eColor_Good);
	OutVisualizationTracks.AddItem(BuildTrack);
}


