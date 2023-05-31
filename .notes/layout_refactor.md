# layout_refactor

## todo
look at LayoutSections and figure out where it's called in containerframe

figure out free bag space position saving bug in grid view

## flow
conceptually, the update flow should be:

* Get all item info
* Mark items as dirty
* Put items in categories
* Draw dirty items
* Sort categoies
* Resize ContainerFrame

goals include

* Acyclic execution of functions
* Refactoring into pure functional objects
* Cycle detector?