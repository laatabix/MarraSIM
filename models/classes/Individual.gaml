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
	int IND_WAITING_TIME_FOR_1L_TRIPS <- int(30#minute);
		
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
	list<int> ind_trip_times <- [0,0];
	
	BusStop ind_waiting_bs <- nil; // bus stop where the individual is waiting
	list<BusTrip> ind_available_bt <- []; // list of available (possible) bus trips to take between origin and distination
	BusTrip ind_current_bt <- nil; // current bus trip taken by the individual
	int ind_current_plan_index <- 0; // the index of the current trip during a multi-trip journey : 0: first trip, 1: second trip 
	list<BusTrip> ind_actual_journey <- []; // the journey contains the list of taken bus trips
	
	// compute plans for all bus stops of BS_NEIGHBORING_DISTANCE (all neighbors) around origin and destination bus stops
	action make_plans {
		// 1-line trips
		loop obs over: ind_origin_bs.bs_neighbors {
			loop dbs over: ind_destin_bs.bs_neighbors - obs {
				loop bl over: obs.bs_bus_lines inter dbs.bs_bus_lines {
					int direc <- bl.can_link_2bs(obs,dbs);
					// don't build another 1L-trip with the same bus line and same bus stop
					if direc != -1 and !similar_bt_exists(bl, direc, nil, nil){
						int walk1 <- int(ind_origin_bs distance_to obs);
						int walk2 <- int(dbs distance_to ind_destin_bs);
						if walk1 <= BS_NEIGHBORING_DISTANCE and walk2 <= BS_NEIGHBORING_DISTANCE{
							do build_trip (BUS_TRIP_SINGLE_LINE, bl, obs, dbs, direc, walk1+walk2);	
						}
					}
				}
			}	
		}
		
		// busses with 1L trip
		list<BusLine> one_l_bus <- remove_duplicates(ind_available_bt collect each.bt_bus_line);
		
		loop bl1 over: remove_duplicates(ind_origin_bs.bs_neighbors accumulate each.bs_bus_lines) - one_l_bus {
			loop bl2 over: remove_duplicates(ind_destin_bs.bs_neighbors accumulate each.bs_bus_lines) - ([bl1] + one_l_bus) {				
				
				BusStop obs <- nil; BusStop dbs <- nil;
				int index_of_bl1; int index_of_bl2;
				
				loop bc over: bl1.bl_connections where (each.bc_bus_lines contains bl2){
					// just to locate the busline in the connection
					index_of_bl1 <- bc.bc_bus_lines index_of bl1;
					index_of_bl2 <- bc.bc_bus_lines index_of bl2;
					
					// better approximate o et d
					if bc.bc_bus_directions [index_of_bl1] = BL_DIRECTION_OUTGOING {
						obs <- closer(bl1.bl_outgoing_bs, ind_origin_bs);
					} else {
						obs <- closer(bl1.bl_return_bs, ind_origin_bs);
					}
					if bc.bc_bus_directions [index_of_bl2] = BL_DIRECTION_OUTGOING {
						dbs <- closer(bl2.bl_outgoing_bs, ind_destin_bs);
					} else {
						dbs <- closer(bl2.bl_return_bs, ind_destin_bs);
					}
					
					int direc1 <- bl1.can_link_2bs(obs, bc.bc_bus_stops[index_of_bl1]);
					int direc2 <- bl2.can_link_2bs(bc.bc_bus_stops[index_of_bl2], dbs);
					
					// only connections with the right directions
					if direc1 != -1 and direc2 != -1 and
						direc1 = bc.bc_bus_directions [index_of_bl1] and direc2 =  bc.bc_bus_directions [index_of_bl2] {
						
						int walk1 <- int(ind_origin_bs distance_to obs);
						int walk2 <- int(dbs distance_to ind_destin_bs);
						int ride1 <- int(obs distance_to bc.bc_bus_stops[index_of_bl1]);
						int ride2 <- int(bc.bc_bus_stops[index_of_bl2] distance_to dbs);
						
						if walk1 <= BS_NEIGHBORING_DISTANCE and walk2 <= BS_NEIGHBORING_DISTANCE
							and (ride1 > BS_NEIGHBORING_DISTANCE or ride2 > BS_NEIGHBORING_DISTANCE) {
							
							// when one of the two rides is less than BS_NEIGHBORING_DISTANCE, take a walk !
							if ride1 <= BS_NEIGHBORING_DISTANCE {
								if !similar_bt_exists(bc.bc_bus_lines[index_of_bl2], bc.bc_bus_directions[index_of_bl2],
														bc.bc_bus_stops[index_of_bl2], dbs) {	
									walk1 <- int(ind_origin_bs distance_to bc.bc_bus_stops[index_of_bl2]);
									do build_trip (BUS_TRIP_SINGLE_LINE, bc.bc_bus_lines[index_of_bl2], bc.bc_bus_stops[index_of_bl2],
												dbs, bc.bc_bus_directions[index_of_bl2],
												walk1 + walk2);				
								}
							} else if ride2 <= BS_NEIGHBORING_DISTANCE {
								if !similar_bt_exists(bc.bc_bus_lines[index_of_bl1], bc.bc_bus_directions[index_of_bl1], obs,
														bc.bc_bus_stops[index_of_bl1]) {
									walk2 <- int(bc.bc_bus_stops[index_of_bl1] distance_to ind_destin_bs);
									do build_trip (BUS_TRIP_SINGLE_LINE, bc.bc_bus_lines[index_of_bl1], obs,
												bc.bc_bus_stops[index_of_bl1], bc.bc_bus_directions[index_of_bl1],
												walk1 + walk2);				
								}
							}
							// both rides are long, make a double-trip journey
							else { 
								if !similar_bt_exists(bc.bc_bus_lines[index_of_bl1], bc.bc_bus_directions[index_of_bl1], obs,
														bc.bc_bus_stops[index_of_bl1]) {
									do build_trip (BUS_TRIP_1ST_LINE, bc.bc_bus_lines[index_of_bl1], obs,
													bc.bc_bus_stops[index_of_bl1], bc.bc_bus_directions[index_of_bl1],
													// we add the 1/2 of connection distance to the first walking distance
													walk1 + int(bc.bc_connection_distance/2));		
								}
								if !similar_bt_exists(bc.bc_bus_lines[index_of_bl2], bc.bc_bus_directions[index_of_bl2],
														bc.bc_bus_stops[index_of_bl2], dbs) {			
									do build_trip (BUS_TRIP_2ND_LINE, bc.bc_bus_lines[index_of_bl2], bc.bc_bus_stops[index_of_bl2],
													dbs, bc.bc_bus_directions[index_of_bl2],
													// the other half to the second trip walking distance
													walk2 + int(bc.bc_connection_distance/2));			
								}	
							}	
						}
					}
				}
			}	
		}	
	}
	
	BusStop closer (list<BusStop> lisa, BusStop bs){
		return lisa contains bs ? bs : lisa closest_to bs;
	}
	
	// create a bus trip
	action build_trip (int bttype, BusLine bsl, BusStop o_bst, BusStop d_bst, int dir, int walk_dis) {
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
			bt_walk_distance <- walk_dis;
			myself.ind_available_bt <+ self;
		}
	}
	
	// test if a similar trip already exists
	bool similar_bt_exists (BusLine bl, int dir, BusStop obs, BusStop dbs) {
		return !empty(ind_available_bt where (each.bt_bus_line = bl and each.bt_bus_direction = dir
			and (obs = nil or each.bt_start_bs = obs) and (dbs = nil or each.bt_end_bs = dbs)));
	}
}

/*** end of species definition ***/