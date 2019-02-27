# World Borders [0.3] - Minetest Mod
Tested on minetest versions 0.4.17.1 and 5.0.0-dev, using minetest_game.  If you are unfamiliar with minetest, get started at https://www.minetest.net/

**Legends of the Edges**

It is said that if you dig deep enough into the crust of the earth, you'll eventually find a stone so hard that it is unbreakable by conventional means.  It is also said that if, somehow, you managed to get through this layer, you may be lucky enough to gaze upon the impenetrable mantle itself.

I think its just a rumor, but I have seen the edge of the world.

At the edge of the world stands a barrier who's extent, from the depths of the earth and beyond the clouds above, belies reason; its origin a mystery.  Such a feat of engineering could not have been the result of any technology known to the world.  While it is a sight to behold, don't plan on continuing your journey beyond it.  No one has yet managed to breach its unconventional substance, at least not for any really meaningful distance.

## Description
The World Borders mod adds two major things to minetest.  

The first you may have seen before in such mods as [bedrock] and [bedrock2]. I've combined some ideas / code from these two and added some user settings.  This part of the mod adds "deepstone", which is an extremely hard rock that replaces stone near the bottom of the world.  Deepstone is, by default, unbreakable except perhaps by advanced tools, tnt, or mining lasers (see [technic]).  Underneath this, you'll find mantlestone, an unbreakable layer of stone that represents the lower border of the world.  Mantlestone resembles the bedrock you may be familiar with.

The second thing you'll find is out near the world edges (where mapgen ends - currently 31km from the center).  This is a gigantic barrier structure extending into the sky as well as the ground that will prevent further movement beyond its confines.

## Download / Usage
Download the zipped mod here: 

https://github.com/argyle77/borders/archive/master.zip.

Unzip this file into your mods directory.  For earlier versions of minetest, you may need to rename the unzipped directory to "borders".  

Alternately, you can clone the repository into your mods directory using git with a command like: 

`git clone --depth 1 https://github.com/argyle77/borders.git`

Browse the source code at https://github.com/argyle77/borders.
  
**Don't forget to enable the mod for your world!**

This mod is best used in new worlds, or worlds who's borders haven't been reached yet.  World Borders mod is in alpha and has not yet been extensively tested, especially for its interactions with other mods, so use caution.  It may be best to give it a try on a test world first.  Please report any difficulties, bugs, or suggestions you may have.

I would not generally recommend using this mod in conjunction with [bedrock] or [bedrock2] because it is meant to provide / replace the functionality of these mods.  However, if you do use them together, you can disable the mantlestone and deepstone portions of this mod in the settings.  I have not yet personally tested the interactions between these mods.

For further help installing minetest mods, see: https://dev.minetest.net/Installing_Mods

## Required Dependencies

**[default]** - The default mod from minetest_game (https://github.com/minetest/minetest_game) - Some nodes from [default] are referenced, and some of the barrier textures are provided by it.

## Optional Dependencies
**[doc]** - In-game help mod (https://forum.minetest.net/viewtopic.php?t=15912)

**[mesecons_mvps]** - From the Mesecons mod (http://mesecons.net/) - Prevents pistons from affecting barrier blocks.

**[intllib]** - Internationalization library mod (https://forum.minetest.net/viewtopic.php?id=4929) - For future translations.

**[caverealms]** - Underground Realms mod (https://forum.minetest.net/viewtopic.php?f=9&t=9522) - Provides minimal interoperation by causing caverealms to load first.

**[magma_conduits]** - Magma conduits and volcanoes mod (https://forum.minetest.net/viewtopic.php?t=20188&p=338973) - Provides minimal interoperation by causing magma_conduits to load first.

If you have a mod that seems to interfere with the borders provided by this mod, especially mods containing mapgen elements, you may find that adding that mod to the dependency lists of this mod may resolve (or ameliorate) your issue.  I'd be interested in hearing about any problems you may find.

## Settings
There are many variables that can be set with regards to these borders.  The setbacks from the bottom and edges of the worlds are adjustable, the thickness of the mantle and the deepstone, the hardness of the deepstone, and several parameters that affect how the mantlestone is generated.  Mantlestone and world-edge barriers can be independently enabled / disabled.  The world-edge barrier texture can be selected.  See Settings -> All / Advanced Settings -> Mods -> borders for more in-depth descriptions of these.  Alternatively, see settingtypes.txt.

## Credits
This mod, especially the mantlestone bits, owes a great deal to those who created the original works on which it was based.  LICENSE.md is probably the definitive resource for these credits, but briefly:

Thank you to celeron55 (Perttu Ahola), kwolekr (Ryan Kwolek), paramat, Wuzzy, Calinou (Hugo Locurcio), jn (Jonathan Neuschäfer	), VanessaE (Vanessa Dannenberg), and help on IRC from rubenwardy, GreenDimond, sofar, and Emerald2.

## Note
This is a work in progress.  Suggestions, bug reports, and complaints are always welcome (vitriol will be ignored).  Thank you.