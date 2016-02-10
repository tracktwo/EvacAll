Evac All for XCOM2 

Workshop link: http://steamcommunity.com/sharedfiles/filedetails/?id=618669868
Nexus link: http://nexusmods.com/xcom2/mods/99

== Description ==

This mod adds an "Evac All" ability to soldier ability bars when they are
in an active evac zone. Clicking this button will evac all soldiers 
currently in the evac zone instead of needing to click the evac button
on each individual soldier. 

Soldiers not in the evac zone will remain, exactly as before - this mod
doesn't add any gameplay change, it's purely an interface change.

Evac animation style is configurable through an XComEvacAll.ini config
file.

== Installation ==

For manual installation, unzip the installation package into your XCOM2\XComGame\Mods folder 
(create the Mods folder if it doesn't exist).

== Configuration ==

Animation style of the evac can be configured through the XComEvacAll.ini file found
in the Config folder in the mod package. When installing through the Steam Workshop,
it can be found in the steamapps\workshop\content\268500\618669868\Config folder.

This file contains one configurable option: EvacMode, which can have one of three
values:

eAllAtOnce (Default) - All units in the zone will evac simultaneously, each performing
their rope out animation at slightly staggered times.

eOneByOne - Units will evac one by one, with each soldier waiting for the previous
soldier to complete their animation.

eNoAnimations - All units will instantly evac and disappear without playing any animations.
