class X2Ability_EvacAll extends X2Ability config (EvacAll);

enum EvacAllMode
{
	eOneByOne,
	eAllAtOnce,
	eNoAnimations
};

var config EvacAllMode EvacMode;

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

	//Template.AddAbilityEventListener('EvacAllActivated', EvacAllActivated, ELD_OnStateSubmitted);
	
	return Template;
}

simulated function bool IsVIP(XComGameState_Unit UnitState)
{
	local name UnitTemplateName;

	UnitTemplateName = UnitState.GetMyTemplateName();
	switch(UnitTemplateName)
	{
	case 'Soldier_VIP':
	case 'Scientist_VIP':
	case 'Engineer_VIP':
	case 'FriendlyVIPCivilian':
	case 'HostileVIPCivilian':
	case 'CommanderVIP':
	case 'Engineer':
	case 'Scientist':
		return true;
	default:
		return false;
	}
}

simulated function XComGameState EvacAll_BuildGameState( XComGameStateContext Context )
{
	local XComGameStateHistory History;
	local XComGameState_Ability AbilityState;
	local StateObjectReference AbilityRef;
	local XComGameState_Unit GameStateUnit;
	local XComGameState NewGameState;
	local bool TriggerEvent;

	if (EvacMode == eOneByOne)
	{
		DoOldEvacAll(Context);
		return TypicalAbility_BuildGameState(Context);
	}

	History = `XCOMHISTORY;

	TriggerEvent = true;

	NewGameState = History.CreateNewGameState(true, Context);	

	foreach History.IterateByClassType(class'XComGameState_Unit', GameStateUnit)
	{
		if (GameStateUnit.bRemovedFromPlay)
		{
			continue;
		}

		AbilityRef = GameStateUnit.FindAbility('Evac');
		AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(AbilityRef.ObjectID));

		// Unit doesn't have an ability state for evac: ignore em. E.g. we don't need to evac non-VIP civs
		// or enemies.
		if (AbilityState == none) {
			continue;
		}

		if (AbilityState.CanActivateAbility(GameStateUnit) == 'AA_Success')
		{
			DoOneEvac(NewGameState, GameStateUnit, AbilityState, TriggerEvent);
			TriggerEvent = false;
		}
	}

	return NewGameState;
}

simulated function DoOneEvac(XComGameState NewGameState, XComGameState_Unit UnitState, XComGameState_Ability AbilityState, bool TriggerEvent)
{
	local XComGameState_Unit NewUnitState;	

	NewUnitState = XComGameState_Unit(NewGameState.CreateStateObject(UnitState.Class, UnitState.ObjectID));
	if (TriggerEvent)
	{
		`XEVENTMGR.TriggerEvent('EvacActivated', AbilityState, NewUnitState, NewGameState);

	}
	NewUnitState.EvacuateUnit(NewGameState);
	NewGameState.AddStateObject(NewUnitState);
}

simulated function DoOldEvacAll(XComGameStateContext Context)
{
	local XComGameStateHistory History;
	local int i, j;
    local X2TacticalGameRuleset TacticalRules;
    local GameRulesCache_Unit UnitCache;
	local XComGameState_Unit GameStateUnit;
	local XComGameState_Ability AbilityState;
	local StateObjectReference AbilityRef;

	History = `XCOMHISTORY;
	TacticalRules = `TACTICALRULES;

	foreach History.IterateByClassType(class'XComGameState_Unit', GameStateUnit)
	{
		if (GameStateUnit.bRemovedFromPlay)
		{
			continue;
		}

		AbilityRef = GameStateUnit.FindAbility('Evac');
		AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(AbilityRef.ObjectID));

		// Unit doesn't have an ability state for evac: ignore em. E.g. we don't need to evac non-VIP civs
		// or enemies.
		if (AbilityState == none) {
			continue;
		}

		if (AbilityState.CanActivateAbility(GameStateUnit) == 'AA_Success')
		{
			if(TacticalRules.GetGameRulesCache_Unit(GameStateUnit.GetReference(), UnitCache))
			{
				for( i = 0; i < UnitCache.AvailableActions.Length; ++i)
				{
					if( UnitCache.AvailableActions[i].AbilityObjectRef.ObjectID == AbilityRef.ObjectID )
					{
						for( j = 0; j < UnitCache.AvailableActions[i].AvailableTargets.Length; ++j )
                        {
							if( UnitCache.AvailableActions[i].AvailableTargets[j].PrimaryTarget == GameStateUnit.GetReference())
							{
								class'XComGameStateContext_Ability'.static.ActivateAbility(UnitCache.AvailableActions[i], j);
							}
						}
					}
				}
			}
		}
	}
}

simulated function EvacAll_BuildVisualization(XComGameState VisualizeGameState, out array<VisualizationTrack> OutVisualizationTracks)
{
	local XComGameStateHistory          History;
	local XComGameState_Unit            GameStateUnit;
	local VisualizationTrack            EmptyTrack;
	local VisualizationTrack            BuildTrack;
	local X2Action_PlaySoundAndFlyOver  SoundAndFlyover;
	local X2Action_SendInterTrackMessage MessageAction;
	local name                          nUnitTemplateName;
	local bool                          bIsVIP;
	local bool                          bNeedVIPVoiceover;
	local XComGameState_Unit            SoldierToPlayVoiceover;
	local array<XComGameState_Unit>     HumanPlayersUnits;
	local XComGameState_Effect          CarryEffect;

	// Insta-vac if the user has requested no anims, and if we're doing
	// old-style one-by-one this is handled by normal evac action sequence.
	if (EvacMode == eNoAnimations || EvacMode == eOneByOne) 
	{
		EvacAll_BuildEmptyVisualization(VisualizeGameState, OutVisualizationTracks);
		return;
	}

	History = `XCOMHISTORY;

	//Decide on which VO cue to play, and which unit says it
	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', GameStateUnit)
	{
		if (!GameStateUnit.bRemovedFromPlay)
			continue;

		nUnitTemplateName = GameStateUnit.GetMyTemplateName();
		switch(nUnitTemplateName)
		{
		case 'Soldier_VIP':
		case 'Scientist_VIP':
		case 'Engineer_VIP':
		case 'FriendlyVIPCivilian':
		case 'HostileVIPCivilian':
		case 'CommanderVIP':
		case 'Engineer':
		case 'Scientist':
			bIsVIP = true;
			break;
		default:
			bIsVIP = false;
		}

		if (bIsVIP)
		{
			bNeedVIPVoiceover = true;
		}
		else
		{
			if (SoldierToPlayVoiceover == None)
				SoldierToPlayVoiceover = GameStateUnit;
		}
	}

	//Build tracks for each evacuating unit
	foreach VisualizeGameState.IterateByClassType(class'XComGameState_Unit', GameStateUnit)
	{
		if (!GameStateUnit.bRemovedFromPlay)
			continue;

		//Start their track
		BuildTrack = EmptyTrack;
		BuildTrack.StateObject_OldState = History.GetGameStateForObjectID(GameStateUnit.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
		BuildTrack.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(GameStateUnit.ObjectID);
		BuildTrack.TrackActor = History.GetVisualizer(GameStateUnit.ObjectID);

		//Add this potential flyover (does this still exist in the game?)
		class'XComGameState_Unit'.static.SetUpBuildTrackForSoldierRelationship(BuildTrack, VisualizeGameState, GameStateUnit.ObjectID);

		//Play the VO if this is the soldier we picked for it
		if (SoldierToPlayVoiceover == GameStateUnit)
		{
			SoundAndFlyOver = X2Action_PlaySoundAndFlyover(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()));
			if (bNeedVIPVoiceover)
			{
				SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'VIPRescueComplete', eColor_Good);
				bNeedVIPVoiceover = false;
			}
			else
			{
				SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'EVAC', eColor_Good);
			}
		}

		//Note: AFFECTED BY effect state (being carried)
		CarryEffect = XComGameState_Unit(BuildTrack.StateObject_OldState).GetUnitAffectedByEffectState(class'X2AbilityTemplateManager'.default.BeingCarriedEffectName);
		if (CarryEffect != None)
		{
			class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()); //Being carried - just wait for message
		}
		else
		{
			class'X2Action_DelayedEvac'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()); //Not being carried - rope out
		}
			
		//Note: APPLYING effect state (carrying another)
		CarryEffect = XComGameState_Unit(BuildTrack.StateObject_OldState).GetUnitApplyingEffectState(class'X2AbilityTemplateManager'.default.BeingCarriedEffectName); 
		if (CarryEffect != None)
		{
			//Carrying someone - send a message to them when we're done roping out
			MessageAction = X2Action_SendInterTrackMessage(class'X2Action_SendInterTrackMessage'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()));
			MessageAction.SendTrackMessageToRef = CarryEffect.ApplyEffectParameters.TargetStateObjectRef;
		}
			
		//Hide the pawn explicitly now - in case the vis block doesn't complete immediately to trigger an update
		class'X2Action_RemoveUnit'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext());

		//Add track to vis block
		OutVisualizationTracks.AddItem(BuildTrack);
	}

	//If a VIP evacuated alone, we may need to pick an (arbitrary) other soldier on the squad to say the VO line about it.
	if (bNeedVIPVoiceover)
	{
		XGBattle_SP(`BATTLE).GetHumanPlayer().GetUnits(HumanPlayersUnits);
		foreach HumanPlayersUnits(GameStateUnit)
		{
			if (GameStateUnit.IsSoldier() && !GameStateUnit.IsDead() && !GameStateUnit.bRemovedFromPlay)
			{
				BuildTrack = EmptyTrack;
				BuildTrack.StateObject_OldState = History.GetGameStateForObjectID(GameStateUnit.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
				BuildTrack.StateObject_NewState = BuildTrack.StateObject_OldState;
				BuildTrack.TrackActor = History.GetVisualizer(GameStateUnit.ObjectID);

				SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()));
				SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", 'VIPRescueComplete', eColor_Good);

				OutVisualizationTracks.AddItem(BuildTrack);
				break;
			}
		}
	}
}


function EvacAll_BuildEmptyVisualization(XComGameState VisualizeGameState, out array<VisualizationTrack> OutVisualizationTracks)
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
