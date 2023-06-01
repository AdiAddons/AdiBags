# layout_refactor

## todo
look at LayoutSections and figure out where it's called in containerframe

figure out free bag space position saving bug in grid view

fork CallbackHandler into our own module

## flow
conceptually, the update flow should be:

* Get all item info
* Mark items as dirty
* Put dirty items in categories
* Draw dirty items
* Sort categoies
* Resize ContainerFrame

goals include

* Acyclic execution of functions
* Refactoring into pure functional objects
* Cycle detector?

## Steps
* bags.lua:90 is the entry point for bags rendering
  * Write a full function trace, line by line (ugh)
* widgets are created on the container frame during first open

## execution flow for drawing (bag open)
bags.lua:90

