/**
* Name: BusVehicle
* Description: defines the BusVehicle species and its related constantes and variables.
* 				A BusVehicle agent represents one bus.
* Author: Laatabi
*/

model BusVehicle

import "TrafficSignal.gaml"
import "Individual.gaml"
import "BusTrip.gaml"

species BusVehicle skills: [moving] {
	BusLine bv_line;
	int bv_direction;
	BusStop bv_current_bs;
	BusStop bv_next_stop;
	float bv_speed;
	float bv_stop_wait_time <- -1.0;
	bool bv_in_city <- true;
	int bv_max_capacity <- 100;
	float bv_com_speed <- 30 #km/#hour;
	bool bv_in_move <- false;
	geometry shape <- rectangle(50#meter,25#meter);
	TrafficSignal bv_current_traff_sign <- nil;
	RoadSegment bv_current_rd_segment <- nil;
	list<Individual> bv_passengers <- [];
	
	float bv_accumulated_traffic_delay <- 0.0;
	float bv_accumulated_signs_delay <- 0.0;
	float bv_accumulated_passaging_delay <- 0.0;
	
	reflex drive {
		// if the bus has to wait
		if bv_stop_wait_time > 0 {
			bv_stop_wait_time <- bv_stop_wait_time - step;
			return;
		}
		 bv_current_rd_segment <- RoadSegment(current_edge);
		if bv_stop_wait_time = 0 {
			bv_current_bs.bs_current_stopping_buses >- self;
			bv_stop_wait_time <- -1.0;
			bv_in_move <- true;
		}
		
		// the bus has reached a bus stop
		if location = bv_next_stop.location {
		 	bv_stop_wait_time <- 30#second;
		 	bv_in_move <- false;
			bv_current_bs <- bv_next_stop;
			bv_current_bs.bs_current_stopping_buses <+ self;
			
			if bv_in_city {
				
				// drop off all passengers who have arrived to their destination
				int nn <- 0; int mm <- 0;
				ask bv_passengers where (bv_current_bs = each.ind_actual_bt.bt_bus_stops[each.ind_current_plan_index]) {
					// add the actual BusTrip to the list of used bus trips
					ind_used_bts <+ ind_actual_bt;
					
					if myself.bv_current_bs = last(ind_actual_bt.bt_bus_stops) { // arrived
						myself.bv_current_bs.bs_arrived_people <+ self;
						ind_trip_time <- int(time - ind_trip_time);
						ind_arrived <- true;
						ind_moving <- false;
						nn <- nn + 1;
						unsaved_arrivals <+ self;
					} 
					else { // connection
						if myself.bv_current_bs != ind_actual_bt.bt_bus_stops[0] {
							write "ERROR in connecting at " + myself.bv_current_bs.bs_name + " by " + myself.bv_line.bl_name color:#red;
						} else {
							ind_waiting_bs <- myself.bv_current_bs;
							ind_waiting_bs.bs_waiting_people <+ self;
							ind_current_plan_index <- ind_current_plan_index + 1;
							mm <- mm + 1;
						}
					}
					myself.bv_passengers >- self;					
					myself.bv_stop_wait_time <- myself.bv_stop_wait_time + 5#second;
					myself.bv_accumulated_passaging_delay <- myself.bv_accumulated_passaging_delay + #second;
				}
				if nn > 0 {
					write world.formatted_time() + bv_line.bl_name  + ' (' + bv_direction + ') is dropping ' + (nn + mm) + ' people at ' + bv_current_bs.bs_name color: #blue;
					if mm > 0 {
						write '  -> Among them, ' + mm + " are connecting" color: #darkblue;
					}
					write '  -> ' + length(bv_passengers) + " people are on board" color: #darkorange;
				}
				
				// take the maximum number of passengers
				int n_individs <- bv_max_capacity - length(bv_passengers);
				// list of possible waiting passengers to take
				list<Individual> waiting_inds <- bv_current_bs.bs_neighbors where !empty(each.bs_waiting_people where
								each.ind_moving) accumulate each.bs_waiting_people;
								
				waiting_inds <- (waiting_inds where (each.ind_current_plan_index = 0 and !empty(each.ind_bt_plan
						where (each.bt_bus_lines[0] = bv_line and each.bt_bus_directions[0] = bv_direction))))
					+
						(waiting_inds where (each.ind_current_plan_index = 1 and !empty(each.ind_bt_plan where
					(each.bt_type= BUS_TRIP_TWO_LINE and each.bt_bus_lines[1] = bv_line and each.bt_bus_directions[1] = bv_direction))));
				
				// if transfer is on, remove individuals with 2L-trip that can still wait for a 1L-trip
				if transfer_on {
					waiting_inds <- waiting_inds - (waiting_inds where (each.ind_current_plan_index = 0 and
						!empty(each.ind_bt_plan where (each.bt_bus_lines[0] = bv_line and each.bt_bus_directions[0] = bv_direction
						and each.bt_type= BUS_TRIP_ONE_LINE)) and int(time - each.ind_waiting_time) < IND_WAITING_TIME_FOR_1L_TRIPS));
				}
				
				nn <- 0;				
				ask n_individs among waiting_inds {
					// the individual was waiting for a first ride
					if ind_current_plan_index = 0 {
						ind_actual_bt <- ind_bt_plan first_with (each.bt_bus_lines[0] = myself.bv_line
										and each.bt_bus_directions[0] = myself.bv_direction);	
					} else {
						// the individual is making a second ride
						ind_actual_bt <- ind_bt_plan where (each.bt_type= BUS_TRIP_TWO_LINE) first_with 
							(each.bt_bus_lines[1] = myself.bv_line and
							each.bt_bus_directions[1] = myself.bv_direction);	
					}
					if ind_actual_bt !=nil {
						nn <- nn + 1;
						myself.bv_passengers <+ self;
						ind_waiting_bs.bs_waiting_people >- self;
						ind_waiting_bs <- nil;
						ind_waiting_time <- int(time - ind_waiting_time);
						ind_trip_time <- int(time);
						myself.bv_stop_wait_time <- myself.bv_stop_wait_time + 5#second;
						myself.bv_accumulated_passaging_delay <- myself.bv_accumulated_passaging_delay + #second;
					} else {
						write "ERROR in finding bus trip !" color: #red;
					}
				}
				if nn > 0 {
					write world.formatted_time() + bv_line.bl_name  + ' (' + bv_direction + ') is taking ' + nn + ' people at ' + bv_current_bs.bs_name color: #darkgreen;
					write '  -> Passengers : ' + length(bv_passengers) + " people are on board" color: #darkorange;
				}
			}
			// to know the next stop
			if bv_direction = BUS_DIRECTION_OUTGOING { // outgoing
				if bv_current_bs = last(bv_line.bl_outgoing_bs) { // last stop
					bv_direction <- BUS_DIRECTION_RETURN;
					bv_next_stop <- bv_line.bl_return_bs[0];
				} else {
					bv_next_stop <- bv_line.bl_outgoing_bs[(bv_line.bl_outgoing_bs index_of bv_next_stop) + 1];
				}
			} else { // return
				if bv_current_bs = last(bv_line.bl_return_bs) { // last stop
					bv_direction <- BUS_DIRECTION_OUTGOING;
					bv_next_stop <- bv_line.bl_outgoing_bs[0];
				} else {
					bv_next_stop <- bv_line.bl_return_bs[(bv_line.bl_return_bs index_of bv_next_stop) + 1];
				}
			}
			return;
			
		} else {
			// the bus is in a traffic signal
			if bv_current_traff_sign = nil {
				if bv_current_rd_segment != nil and !empty((bv_current_rd_segment).rs_traffic_signals) {				
					TrafficSignal ts <- bv_current_rd_segment.rs_traffic_signals closest_to self;
					float stop_prob <- ts.ts_type = TRAFFIC_STOP_SIGN ? 1 : 0.5;
					// if th stopping condition is true (flip) and the bus is 10 meters around a traffic signal
					if flip (stop_prob) and 10#meter around (ts) overlaps location {
						bv_stop_wait_time <- TS_STOP_WAIT_TIME;
						bv_accumulated_signs_delay <- bv_accumulated_signs_delay + TS_STOP_WAIT_TIME;
						bv_current_traff_sign <- ts;
					 	bv_in_move <- false;
					 	return;
					}
				}	
			} else {
				bv_current_traff_sign <- nil;
			}
		}
		if bv_current_rd_segment != nil {
			bv_in_city <- bv_current_rd_segment.rs_in_city;
			// a bus moves with the commercial speed inside Marrakesh, and 50 km/h outside;
			if bv_in_city {
				if traffic_on {
					bv_speed <- bv_com_speed / bv_current_rd_segment.rs_traffic_level;
					bv_accumulated_traffic_delay <- bv_accumulated_traffic_delay + bv_current_rd_segment.rs_traffic_level;
	
				} else {
					bv_speed <- bv_com_speed;
				}
			} else {
				bv_speed <- 50 #km/#hour;
			}	
		}
		do goto on: road_network target: bv_next_stop speed: bv_speed;
	}
	
	aspect default {
		draw shape color: rgb("#feb29a") border: #black rotate: heading;
	}
}
