//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_EvacAll.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_EvacAll extends X2DownloadableContentInfo config(EvacAll);

// Configurable list of character template names to give the EvacAll ability.
var config array<Name> CharacterTemplates;

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the 
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{}

// Add the evac all ability to all appropriate character templates.
static event OnPostTemplatesCreated()
{
    local X2CharacterTemplateManager CharacterTemplateManager;
    local X2CharacterTemplate CharTemplate;
    local array<X2DataTemplate> DataTemplates;
    local X2DataTemplate Template, DiffTemplate;
    local Name TemplateName;

    CharacterTemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

    foreach CharacterTemplateManager.IterateTemplates(Template, None)
    {
        CharacterTemplateManager.FindDataTemplateAllDifficulties(Template.DataName, DataTemplates);
        foreach DataTemplates(DiffTemplate)
        {
            CharTemplate = X2CharacterTemplate(DiffTemplate);
            if (CharTemplate.Abilities.Find('Evac') >= 0)
            {
                `Log("Adding EvacAll ability to template " $ CharTemplate.DataName);
                CharTemplate.Abilities.AddItem('EvacAll');
            }
        }
    }

    // Also check the config list for additional templates (in case someone really wants to give them
    // evac all without evac?
    foreach default.CharacterTemplates(TemplateName)
    {
        CharacterTemplateManager.FindDataTemplateAllDifficulties(TemplateName, DataTemplates);
        foreach DataTemplates(DiffTemplate)
        {
            CharTemplate = X2CharacterTemplate(DiffTemplate);
            if (CharTemplate != none && CharTemplate.Abilities.Find('EvacAll') < 0)
                CharTemplate.Abilities.AddItem('EvacAll');
            else
                `Log("Failed to locate character template " $ TemplateName);
        }
    }
}
