# AdiBags 

[![Discord Banner 2](https://discordapp.com/api/guilds/1063213796845428876/widget.png?style=banner2)](https://discord.gg/a6DQuK8hV7)

AdiBags is a World of Warcraft addon that displays the contents of your bags in single view, distributed into several sections using smart filters. It is heavily inspired by Nargiddley's Baggins.

Configuration is available through Blizzard addon panel, the `/adibags` chat command, and by configuring "right-click to open options" and right clicking on any blank space in the bag window.

## Main Features

### Filter Partitions
AdiBags will automatically filter and group items into partitions so that all like-items are always grouped together. AdiBags tries to make sure there are intelligent defaults that require little-to-no out of the box configuration for item grouping. The partitions them selves are laid out automatically as well, with no human interaction. The result is a beautiful item and bag experience, right from the start!
<p align="center">
  <span><img width="570" height="625" src="https://i.imgur.com/PyCfmcR.gif"></span>
  <br>
  <i>Automatic filters based on Auction House categories, gear sets, and more!</i>
</p>

### Character Currencies
AdiBags supports in-frame display of currencies. The specific currencies to display can be configured in the options panel, and currency display supports a dynamic layout that grows to
the number of columns configured.
<p align="center">
  <span><img width="417" height="160" src="https://i.imgur.com/dXICYfR.gif"></span>
  <br>
  <i>Currencies viewable directly in your bags.</i>
</p>

### Full-text Item Searching
AdiBags has built-in support for item searching based on item names. Results are highlighted directly in the bag frame so they can be utilized right away.
<p align="center">
  <span><img width="417" height="160" src="https://i.imgur.com/9Vc98w8.gif"></span>
  <br>
  <i>Items fade away when they don't match a search term.</i>
</p>


## Modules

Users can write their own modules that integrate with AdiBags to extend the AddOn's functionality. There are two modules for AdiBags written by the authors:
* [AdiBags_Outfitter](https://www.curseforge.com/wow/addons/adibags_outfitter)
  * Add filters for the excellent [Outfitter](https://www.curseforge.com/wow/addons/outfitter) addon item sets
* [AdiBags_PT3Filter](https://www.curseforge.com/wow/addons/adibags-pt3filter)
  * Add filters based on [LibPeriodicTable-3.1](https://www.curseforge.com/wow/addons/libperiodictable-3-1) categories

 Feel free to submit your own modules in this readme!

## Tips & Tricks

* Custom item sections can be created using the "manual filter" option in the configuration panel. Items can then be dragged and dropped on section titles to reassign that item permanently to that section.


## Known Issues, Bugs, and Feature Requests

We welcome all bug reports and feature requests, though we can't promise every single feature will be implemented. Please report any issues or feature requests via GitHub issues.

We highly suggest installing both [BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber) and [BugSack](https://www.curseforge.com/wow/addons/bugsack) in order to capture bugs in AdiBags. These bug messages should then be used in any bug reports filed through GitHub issues.

## Roadmap and Future Thoughts

### Guild Bank
AdiBags is an abstraction on top of Blizzard bags, and does not work to make Blizzard bags consistent or sorted. Due to this abstraction, two users of AdiBags accessing the same underlying store, such as a guild bank, may see two different views. For this reason, we've shied away from implementing a Guild Bank for now. However, there is renewed interest in solving this problem overall, so stay tuned for changes in this space.

### Alt Bags and Bank
For the moment, alt bags and banks are not supported. Once we invest a bit more time into our abstraction engine, we may revisit this as an added feature.

### In-Depth Filter Editing

There are no plans to add a fully featured, scriptable, or logic/waterfall based filtering engine at this time.

## License
AdiBags is licensed under the GNU General Public License version 3.
