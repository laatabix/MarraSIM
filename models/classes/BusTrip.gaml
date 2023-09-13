/**
* Name: BusTrip
* Description: defines the BusTrip species and its related constantes, variables, and methods.
* 				A BusTrip agent represents one journey from a start point to a destination.
* Author: Laatabi
*/

model BusTrip

import "BusLine.gaml"

global {
	int BUS_TRIP_SINGLE_LINE <- 1;
	int BUS_TRIP_1ST_LINE <- 2;
	int BUS_TRIP_2ND_LINE <- 3;
	
	bool transfer_on <- false; // allow ticket transfer between busses of the same trip (when false, promotes 1L-trips over 2L-trips) 
}
	
species BusTrip schedules: [] {
	int bt_type <- BUS_TRIP_SINGLE_LINE;
	BusStop bt_start_bs <- nil; // the bus stop where the passenger will take the bus
	BusLine bt_bus_line <- []; // the bus line to take
	BusStop bt_end_bs <- [];  // the bus stop whete TO LEAVE the bus
	int bt_bus_direction <- []; // the bus direction to take
	int bt_bus_distance <- []; // the traveled distance on the bus
	int bt_walk_distance <- 0; // the walked distance to reach the start bus stop
}