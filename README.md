# World Borders - Minetest Mod
Tested on minetest versions 0.4.17.1 and 5.0.0-dev, using minetest_game.  If you are unfamiliar with minetest, get started at https://www.minetest.net/

**Legends of the Edges**

It is said that if you dig deep enough into the crust of the earth, you'll eventually find a stone so hard that it is unbreakable by conventional means.  It is also said that if, somehow, you managed to get through this layer, you may be lucky enough to gaze upon the impenetrable mantle itself.

I think its just a rumor, but I have seen the edge of the world.

At the edge of the world stands a barrier who's extent, from the depths of the earth and beyond the clouds above, belies reason; its origin a mystery.  Such a feat of engineering could not have been the result of any technology known to the world.  While it is a sight to behold, don't plan on continuing your journey beyond it.  No one has yet managed to breach its unconventional substance, at least not for any really meaningful distance.

## Download / Usage
Download the zipped mod here: 

https://github.com/argyle77/borders/archive/master.zip.

Unzip this file into your mods directory.  For earlier versions of minetest, you may need to rename the unzipped directory to "borders".  

Alternately, you can clone the repository into your mods directory using git with a command like: 

`git clone --depth 1 https://github.com/argyle77/borders.git`

Browse the source code at https://github.com/argyle77/borders.
  
**Don't forget to enable the mod for your world!**

This mod is best used in new worlds, or worlds who's borders haven't been reached yet.  This mod is in alpha and has not yet been extensively tested, so use caution.  It may be best to give it a try on a test world first.  Please report any difficulties, bugs, or suggestions you may run across.

I would not generally recommend using this mod in conjunction with [bedrock] or [bedrock2] as it is meant to provide / replace the functionalities of these mods.  However, if you do use them together, I'd suggest disabling the mantlestone / deepstone portion of this mod in the settings.  I have not personally tested the interactions between these mods.

For further help installing minetest mods, see: https://dev.minetest.net/Installing_Mods

## Description
The World Borders mod adds two major things to minetest.  

The first you may have seen before in such mods as [bedrock] and [bedrock2]. I've combined some ideas / code from these two and added some user settings.  This part of the mod adds "deepstone", which is an extremely hard rock that replaces stone near the bottom of the world.  Deepstone is, by default, unbreakable except perhaps by advanced tools, tnt, or mining lasers (see [technic]).  Underneath this, you'll find mantlestone, an unbreakable layer of stone that represents the lower border of the world.  Mantlestone resembles the bedrock you may be familiar with.

The second thing you'll find is out near the world edges, which currently exist approximately 31km from the origin.  This is a gigantic fence-like structure extending into the sky as well as the ground that will prevent further movement beyond its confines.

## Dependencies
The default mod from Minetest_game is a required dependency.  Optional dependencies include doc, mesecons_mvps, intllib, 
doc, and caverealms.  Some of these optional dependencies exist to provide a minimal interoperation without a particularly
in-depth interaction.  If you have a mod that seems to interfere with the borders provided by this mod, especially mods containing mapgen elements, you may find that adding that mod to the dependency lists of this mod may resolve (or ameliorate) your issue.  I'd be interested in hearing about your issues / solutions.

## Settings
There are many variables that can be set with regards to these borders.  The setbacks from the bottom and edges of the worlds are adjustable, the thickness of the mantle and the deepstone, the hardness of the deepstone, and several parameters that effect how the mantlestone is generated.  Mantlestone and world-edge barriers can be independently enabled / disabled.  See Settings -> All / Advanced Settings -> Mods -> borders for more in-depth descriptions of these.  Alternatively, see settingtypes.txt.

## Credits
This mod, especially the mantlestone bits, owes a great deal to those who created the original works on which it was based.  LICENSE.md is probably the definitive resource for these credits, but briefly:

Thank you to celeron55 (Perttu Ahola), kwolekr (Ryan Kwolek), paramat, Calinou, jn, VanessaE (Vanessa Dannenberg), and help from rubenwardy, GreenDimond, sofar, and Emerald2.

## Note
This is a work in progress.  Suggestions, bug reports, and complaints are always welcome (vitriol will be ignored).  Thank you.