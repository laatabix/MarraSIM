/**
* Name: Individual
* Description: defines the Individual species and its related constantes, variables, and methods.
* 				An Individual agent represents one person that travel using a bus or a Grand Taxi between
* 				an origin and a destination.
* Authors: Laatabi
* For the i-Maroc project. 
*/

model Individual

import "PDUZone.gaml"

global {
	
	// time to wait for 1L-trips before taking a 2L-trip when transfer is off
	int IND_WAITING_TIME_FOR_1L_TRIPS <- int(1#hour);
	
	// a list of arrivals for data saving
	list<Individual> unsaved_arrivals <- [];
	
}

/*******************************/
/***** Individual Species *****/
/*****************************/

species Individual parallel: true {
	int ind_id;
	PDUZone ind_origin_zone;
	PDUZone ind_destin_zone;
	BusStop ind_origin_bs;
	BusStop ind_destin_bs;
	bool ind_moving <- false;
	bool ind_arrived <- false;
	list<int> ind_waiting_times <- [0,0];
	int ind_trip_time <- 0;
	
	BusStop ind_waiting_bs; // bus stop where the individual is waiting
	list<BusTrip> ind_available_bt <- []; // list of available (possible) bus trips to take between origin and distination
	BusTrip ind_current_bt <- nil; // current bus trip taken by the individual
	int ind_current_plan_index <- 0; // the index of the current trip during a multi-trip journey : 0: first trip, 1: second trip 
	list<BusTrip> ind_actual_journey <- []; // the journey contains the list of taken bus trips
	
	// compute plans for all bus stops of BS_NEIGHBORING_DISTANCE (all neighbors) around origin and destination bus stops
	action make_plans {
		
		// 1-line trips
		loop obs over: ind_origin_bs.bs_neighbors {
			loop dbs over: ind_destin_bs.bs_neighbors {
				loop bl over: obs.bs_bus_lines inter dbs.bs_bus_lines {
					int direc <- bl.can_link_2bs(obs,dbs);
					// don't build another 1L-trip with the same bus line and same bus stop
					if direc != -1 and !similar_bt_exists(bl, direc, nil){
						do build_trip (BUS_TRIP_SINGLE_LINE,bl, obs, dbs, direc);
					}
				}
			}	
		}
		
		// busses with 1L trip
		list<BusLine> one_l_bus <- ind_available_bt collect each.bt_bus_line;
		
		// 2-line trips	
		loop obs over: ind_origin_bs.bs_neighbors {
			loop dbs over: ind_destin_bs.bs_neighbors {
				loop bc over: (obs.bs_bus_lines accumulate (each.bl_outgoing_connections  + each.bl_return_connections)) inter
							(dbs.bs_bus_lines accumulate (each.bl_outgoing_connections + each.bl_return_connections)) {
					
					// do not construct 2L trips with a bus than can do 1L trip
					if empty(one_l_bus inter bc.bc_bus_lines){
						
						// if the first connected bus (first bus in the BusConnection) is at the origin (of the individual)
						if bc.bc_bus_lines[0] in obs.bs_bus_lines {
							int direc1 <- bc.bc_bus_lines[0].can_link_2bs(obs, bc.bc_bus_stops[0]);
							int direc2 <- bc.bc_bus_lines[1].can_link_2bs(bc.bc_bus_stops[1], dbs);
							
							if direc1 != -1 and direc2 != -1 {
								if !similar_bt_exists(bc.bc_bus_lines[0], direc1, bc.bc_bus_stops[0]) {
									do build_trip (BUS_TRIP_1ST_LINE,bc.bc_bus_lines[0], obs, bc.bc_bus_stops[0], direc1);
								}
								if !similar_bt_exists(bc.bc_bus_lines[1], direc2, dbs) {
									do build_trip (BUS_TRIP_2ND_LINE,bc.bc_bus_lines[1], bc.bc_bus_stops[1], dbs, direc2);
								}	
							}
						}
						
						// if the first connected bus is at the destination
						else if bc.bc_bus_lines[1] in obs.bs_bus_lines {
							int direc1 <- bc.bc_bus_lines[1].can_link_2bs(obs, bc.bc_bus_stops[1]);
							int direc2 <- bc.bc_bus_lines[0].can_link_2bs(bc.bc_bus_stops[0], dbs);
							
							if direc1 != -1 and direc2 != -1 {
								if !similar_bt_exists(bc.bc_bus_lines[1], direc1, bc.bc_bus_stops[1]) {
									do build_trip (BUS_TRIP_1ST_LINE,bc.bc_bus_lines[1], obs, bc.bc_bus_stops[1], direc1);
								}
								if !similar_bt_exists(bc.bc_bus_lines[0], direc2, dbs) {
									do build_trip (BUS_TRIP_2ND_LINE,bc.bc_bus_lines[0], bc.bc_bus_stops[0], dbs, direc2);
								}	
							}
						}	
					}
				}	
			}	
		}			
	}
	
	// create a bus trip
	action build_trip (int bttype, BusLine bsl, BusStop o_bst, BusStop d_bst, int dir) {
		int o_ix;	int	d_ix;
		list<int> distances <- [];
		
		if dir = BL_DIRECTION_OUTGOING {
			o_ix <- bsl.bl_outgoing_bs index_of o_bst;
			d_ix <- bsl.bl_outgoing_bs index_of d_bst;
			distances <- bsl.bl_outgoing_dists;
		} else {
			o_ix <- bsl.bl_return_bs index_of o_bst;
			d_ix <- bsl.bl_return_bs index_of d_bst;
			distances <- bsl.bl_return_dists;
		}
		
		create BusTrip {
			bt_type <- bttype;
			bt_start_bs <- o_bst;
			bt_bus_line <- bsl;
			bt_end_bs <- d_bst;
			bt_bus_direction <- dir;
			bt_bus_distance <- sum(distances[o_ix::d_ix+1]); // compute the distance between origin and destination
			// compute the walking distance between actual origin and the start of the trip 
			// 			 					and between the end of the trip and the actual destination
			bt_walk_distance <- myself.ind_origin_bs.dist_to_bs(o_bst) +
							myself.ind_destin_bs.dist_to_bs(d_bst);
			myself.ind_available_bt <+ self;
		}
	}
	
	// test if a similar trip already exists
	bool similar_bt_exists (BusLine bl, int dir, BusStop bs) {
		return !empty(ind_available_bt where (each.bt_bus_line = bl and each.bt_bus_direction = dir and (bs = nil or each.bt_end_bs = bs)));
	}
}

/*** end of species definition ***/