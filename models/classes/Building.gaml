/**
* Name: Building
* Description: defines the Building species and its related constantes, variables, and methods.
* 			A Building agent represents one urban building.
* 			In this version, building are used only for visualization purpose and do not intervene in any model behavior.
* Authors: Laatabi
* For the i-Maroc project.
*/

model Building

global {}

/*******************************/
/******* Building Species *****/
/*****************************/

species Building schedules: []{
	
	aspect default {
		draw shape color: #gray border: #darkgray;
	}
	
}

/*** end of species definition ***/