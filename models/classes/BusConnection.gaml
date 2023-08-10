/**
* Name: BusConnection
* Description: defines the BusConnection species and its related constantes and variables.
* 				A BusConnection agent represents a possible connection between two bus lines
* 				on the same bus stop or usig two beighboring bus stops.
* Author: Laatabi
*/

model BusConnection

import "BusStop.gaml"

species BusConnection schedules: []{
	list<BusLine> bc_bus_lines <- []; // list of connected bus lines
	list<BusStop> bc_bus_stops <- []; // 1st bs: leave the 1st bl | 2nd bs : take the 2nd bl
	list<int> bc_bus_directions <- []; // list of directions of bus lines
	int bc_connection_distance; // distance between connected bus stops
}