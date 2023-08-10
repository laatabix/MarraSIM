/**
* Name: Building
* Description: defines the Building species and its related constantes and variables.
* 				A Building agent represents one urban building.
* 				In this version, building are used only for visualization purposes and do not
* 				intervene in any model behavior.
* Author: Laatabi
*/

model Building

species Building schedules: []{
	aspect default {
		draw shape color: #gray border: #darkgray;
	}
}