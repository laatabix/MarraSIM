/**
* Name: Individual
* Description: defines the Individual species and its related constantes and variables.
* 				An Individual agent represents one person.
* Author: Laatabi
*/

model Individual

import "PDUZone.gaml"

species Individual parallel: true {
	int ind_id;
	PDUZone ind_origin_zone;
	PDUZone ind_destin_zone;
	BusStop ind_origin_bs;
	BusStop ind_destin_bs;
	BusStop ind_waiting_bs;
	list<BusTrip> ind_bt_plan <- [];
	bool ind_moving <- false;
	bool ind_arrived <- false;
	int ind_waiting_time <- 0;
	int ind_trip_time <- 0;
	BusTrip ind_actual_bt <- nil;
	int ind_current_plan_index <- 0;
	list<BusTrip> ind_finished_bt <- [];
	
	BusStop tmp_start_bs;
	BusLine tmp_bl;
	int tmp_dir;
	BusStop tmp_bs;
	int tmp_dist;
		
	action make_plans {
		// compute plans for all bus stops of 400m around origin and destination bus stops
		// 1-line trips

		loop obs over: ind_origin_bs.bs_neighbors {
			loop dbs over: ind_destin_bs.bs_neighbors {
				loop bl over: obs.bs_bus_lines inter dbs.bs_bus_lines {
					// don't build another 1L-trip with the same bus line and same bus stop
					int direc <- bl.can_link_2bs(obs,dbs);
					if direc != -1 and !similar_bt_exists(BUS_TRIP_ONE_LINE, [bl], [dbs]){
						do build_1L_trip (bl, obs, dbs, direc);
					}
				}
			}	
		}

		// 2-lines trips
		loop obs over: ind_origin_bs.bs_neighbors {
			loop dbs over: ind_destin_bs.bs_neighbors {
				loop bc over: (obs.bs_bus_lines accumulate (each.bl_outgoing_connections  + each.bl_return_connections)) inter
							(dbs.bs_bus_lines accumulate (each.bl_outgoing_connections + each.bl_return_connections)) {
					// don't build a 2L-trip with a bus line that can do 1L-trip
					// don't build another 2L-trip with the same two bus lines
					if !similar_bt_exists(BUS_TRIP_ONE_LINE, bc.bc_bus_lines, []) {					
						// if the first connected bus is at the origin
						if bc.bc_bus_lines[0] in obs.bs_bus_lines and 
							!similar_bt_exists(BUS_TRIP_TWO_LINE, bc.bc_bus_lines, [bc.bc_bus_stops[0],dbs]) {
							if bc.bc_bus_lines[0].can_link_2bs(obs, bc.bc_bus_stops[0]) != -1 and build_2L_trip (bc, 0, obs, bc.bc_bus_stops[0], 1)
								and bc.bc_bus_lines[1].can_link_2bs(bc.bc_bus_stops[1], dbs) != -1 {
								do build_2L_trip (bc, 1, bc.bc_bus_stops[1], dbs, 2);								
							}
						}
						// if the first connected bus is at the destination
						else if !similar_bt_exists(BUS_TRIP_TWO_LINE, bc.bc_bus_lines, [bc.bc_bus_stops[1],dbs]) {
							if bc.bc_bus_lines[1].can_link_2bs(obs,bc.bc_bus_stops[1]) != -1 and build_2L_trip (bc, 1, obs, bc.bc_bus_stops[1], 1) 
								and bc.bc_bus_lines[0].can_link_2bs(bc.bc_bus_stops[0], dbs) != -1 {
								do build_2L_trip (bc, 0, bc.bc_bus_stops[0], dbs, 2);
							}
						}
					}
				}
			}
		}
	}
			
	bool build_1L_trip (BusLine bsl, BusStop o_bst, BusStop d_bst, int dir) {
		int o_ix;	int	d_ix;
		list<int> distances <- [];
		
		if dir = BUS_DIRECTION_OUTGOING {
			o_ix <- bsl.bl_outgoing_bs index_of o_bst;
			d_ix <- bsl.bl_outgoing_bs index_of d_bst;
			distances <- bsl.bl_outgoing_dists;
		} else {
			o_ix <- bsl.bl_return_bs index_of o_bst;
			d_ix <- bsl.bl_return_bs index_of d_bst;
			distances <- bsl.bl_return_dists;
		}
		
		create BusTrip {
			bt_start_bs <- o_bst;
			bt_bus_lines <- [bsl];
			bt_bus_stops <- [d_bst];
			bt_bus_directions <- [dir];
			bt_bus_dists <- [sum(distances[o_ix::d_ix+1])];
			bt_walk_dist <- myself.ind_origin_bs.dist_to_bs(o_bst) +
							myself.ind_destin_bs.dist_to_bs(d_bst);
			myself.ind_bt_plan <+ self;
		}
		return true;	
	}
	
	bool build_2L_trip (BusConnection bc, int indx_bsl, BusStop o_bst, BusStop d_bst, int ligne) {
		BusLine bsl <- bc.bc_bus_lines[indx_bsl];
		int o_ix;	int	d_ix;
		list<int> distances <- [];
		
		if bc.bc_bus_directions[indx_bsl] = BUS_DIRECTION_OUTGOING {
			o_ix <- bsl.bl_outgoing_bs index_of o_bst;
			d_ix <- bsl.bl_outgoing_bs index_of d_bst;
			distances <- bsl.bl_outgoing_dists;
		} else {
			o_ix <- bsl.bl_return_bs index_of o_bst;
			d_ix <- bsl.bl_return_bs index_of d_bst;
			distances <- bsl.bl_return_dists;
		}
		
		if ligne = 1 {  // first line
			tmp_start_bs <- o_bst;
			tmp_bl <- bsl;
			tmp_dir <- bc.bc_bus_directions[indx_bsl];
			tmp_bs <- d_bst;
			tmp_dist <- sum(distances[o_ix::d_ix+1]);
			return true;	
		} else { // second line
			create BusTrip {
				bt_start_bs <- myself.tmp_start_bs;
				bt_type <- BUS_TRIP_TWO_LINE;
				bt_bus_lines <- [myself.tmp_bl, bsl];
				bt_bus_directions <- [myself.tmp_dir, bc.bc_bus_directions[indx_bsl]];
				bt_bus_stops <- [myself.tmp_bs, d_bst];
				bt_bus_dists <- [myself.tmp_dist, sum(distances[o_ix::d_ix+1])];
				bt_walk_dist <- myself.ind_origin_bs.dist_to_bs(bt_start_bs) + 
								bc.bc_connection_distance + myself.ind_destin_bs.dist_to_bs(d_bst);
				myself.ind_bt_plan <+ self;
			}
			return true;	
		}
	}
	
	// test if a similar trip already exists
	bool similar_bt_exists (int ttype, list<BusLine> bls, list<BusStop> bss) {
		if ttype = BUS_TRIP_ONE_LINE {
			// 1-L trips
			return !empty(ind_bt_plan where (each.bt_type = BUS_TRIP_ONE_LINE and each.bt_bus_lines[0] in bls
							and (empty(bss) or each.bt_bus_stops[0] = bss[0])));
		} else {
			// 2-L trips
			return !empty(ind_bt_plan where (each.bt_type = BUS_TRIP_TWO_LINE and each.bt_bus_lines contains_all bls
							and each.bt_bus_stops contains_all bss));
		}
	}
}