class UIScreenListener_TacticalHUD_EvacAll extends UIScreenListener;

// Workaround to add the evac all ability to each xcom unit. Loop over all units on tactical UI load and
// add the ability to each one that doesn't already have it.
event OnInit(UIScreen Screen)
{
	local XComGameState_Unit UnitState, NewUnitState;
	local XComGameState_Ability AbilityState;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate AbilityTemplate;
	local XComGameState NewGameState;
	local StateObjectReference StateObjectRef;
	local bool hasAbility;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate('EvacAll');

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		HasAbility = false;

		// Only add to XCom
		if( UnitState.GetTeam() == eTeam_XCom)
		{
			foreach UnitState.Abilities(StateObjectRef) 
			{
				AbilityState = XComGameState_Ability(`XCOMHISTORY.GetGameStateForObjectID(StateObjectRef.ObjectID));

				// If the unit already has this ability, don't add a new one.
				if (AbilityState.GetMyTemplateName() == 'EvacAll')
				{
					HasAbility = true;
					break;
				}
			}

			if (HasAbility) 
				continue;

			// Construct a new unit game state that has the ability
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
	}
}

defaultProperties
{
    ScreenClass = UITacticalHUD
}