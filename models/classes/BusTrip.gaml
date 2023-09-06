/**
* Name: BusTrip
* Description: defines the BusTrip species and its related constantes and variables.
* 				A BusTrip agent represents one journey from a start point to a destination.
* Author: Laatabi
*/

model BusTrip

import "BusLine.gaml"

global {
	int BUS_TRIP_ONE_LINE <- 1;
	int BUS_TRIP_TWO_LINE <- 2;
	
	bool transfer_on <- false; // allow ticket transfer between busses of the same trip (when false, promotes 1L-trips over 2L-trips) 
}
	
species BusTrip schedules: [] {
	int bt_type <- BUS_TRIP_ONE_LINE;
	BusStop bt_start_bs <- nil; // the bus stop where the passenger will take the first bus
	list<BusLine> bt_bus_lines <- []; // list of bus lines to take
	list<BusStop> bt_bus_stops <- [];  // for each bus line, bus stop TO LEAVE the bus
	list<int> bt_bus_directions <- []; // list of bus directions to take
	list<int> bt_bus_dists <- [];
	int bt_walk_dist <- 0;
}