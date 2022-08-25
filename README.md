# AdiBags 

[![Gitter](https://badges.gitter.im/AdiAddons/AdiBags.svg)](https://gitter.im/AdiAddons/AdiBags?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

AdiBags is a World of Warcraft addon that displays the contents of your bags in single view, distributed into several sections using smart filters. It is heavily inspired by Nargiddley's Baggins.

Configuration is available through Blizzard addon panel, the `/adibags` chat command, and by configuring "right-click to open options" and right clicking on any blank space in the bag window.

## Features
---

* Automatic filters that partition items into several sections:
  * Blizzard gear managet item sets
  * Junk items
  * Quest items
  * Equipment
  * Auction house category
  * New items
  * Custom filters and seconds
  * Free space aggregation
* Character currencies:
  * Ability to display only the currencies desired
* Character gold/silver/copper display
* Full-text item name searching with highlighting
* Automatic item sorting within each section
* Automatic section layout
* Bag sorting
* Hide unused sections
* ...and more!

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
---
### Guild Bank
AdiBags is an abstraction on top of Blizzard bags, and as such, does not work to make Blizzard bags consistent or sorted. As such, two users of AdiBags accessing the same underlying store, such as a guild bank, may see two different views. For this reason, we've shied away from implementing a Guild Bank for now. However, there is renewed interest in solving this problem overall, so stay tuned for changes in this space.

### Alt Bags and Bank
For the moment, alt bags and banks are not supported. Once we invest a bit more time into our abstraction engine, we may revisit this as an added feature.

### Full Bag Skinning

Limited skinning is available using LibSharedMedia-1.0, however it is not as comprehensive as Masque support. Masque support is on our roadmap, and will eventually be implemented.

### In-Depth Filter Editing

According to my experience with Baggins, comprehensive editor is awful to write as an author and awful to use as an user. Hence I focus on creating filters that have a smart built-in behavior and only a few options. I try to avoid the 20% of features that would require 80% of development effort.

## License
---
AdiBags is licensed under the GNU General Public License version 3.
