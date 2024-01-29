/**
* Name: BusConnection
* Description: defines the BusConnection species and its related constantes, variables, and methods.
* 				A BusConnection agent represents a possible connection between two bus lines on the same bus stop
* 				or usig two beighboring bus stops.
* Authors: Laatabi
* For the i-Maroc project.
*/

model BusConnection

import "BusStop.gaml"

/*******************************/
/**** BusConnection Species ***/
/*****************************/

species BusConnection schedules: []{
	list<BusLine> bc_bus_lines <- []; // list of connected bus lines
	list<BusStop> bc_bus_stops <- []; // 1st bus stop: leave the 1st bus line | 2nd bus stop : take the 2nd bus line
	list<int> bc_bus_directions <- []; // list of directions of bus lines
	int bc_connection_distance; // distance between connected bus stops
}

/*** end of species definition ***/