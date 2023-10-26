# minigolf-standalone

A quick gamemode pulled out of gmt/touhou-towers that can be run on its own. I
have not played entirely through the gamemode, but I've played a few holes.

Example command to start the server (you will also need the materials/maps/etc
content that can be found in related addons):

```
srcds.exe -console -game "garrysmod" +gamemode minigolf +map gmt_minigolf_garden05
```

With the directory structure as an example

```
garrysmod
|- addons
   |- minigolf
      |- gamemodes (this project)
```

Alternatively, you can run it from the game itself if you put this in the same
folder structure

```
gamemode minigolf
map gmt_minigolf_moon01
```

The only changes are in the commit:
[30575a5](https://github.com/touhou-towers/gmt-minigolf-standalone/commit/5fc064eac8c53676344bbf65a590077a0a54caa0)
