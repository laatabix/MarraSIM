/**
* Name: BusVehicle
* Description: defines the BusVehicle species and its related constantes, variables, and methods.
* 				A BusVehicle agent represents one vehicle that serves a bus line.
* Authors: Laatabi
* For the i-Maroc project.
*/

model BusVehicle
import "../Params.gaml"
import "Individual.gaml"
import "TrafficSignal.gaml"
import "BusTrip.gaml"

global {
	
	// speed of busses in the urban area
	float BV_URBAN_SPEED <- 30#km/#hour;
	// speed of busses in the suburban area
	float BV_SUBURBAN_SPEED <- 60#km/#hour;
	// the minimum wait time at bus stops
	float BV_MIN_WAIT_TIME_BS <- 30#second;
	// the mininmum time to take a passenger
	float BV_TIME_TAKE_IND <- 10#second;
	// the mininmum time to drop off a passenger
	float BV_TIME_DROP_IND <- 5#second;
	
	// max load of a bus vehicle (all people that can get in) when crowded and cannot take more
	int BV_MAX_CAPACITY <- 75;
	
	// How to decrease vehicle speed based on traffic level [evey value corresponds to a traff level, 0 is unused]
	list<float> BV_SPEED_DIVIDER <- [0,1.0,2.0,3.0,4.0];
}

/*******************************/
/**** BusVehicle Species ******/
/*****************************/

species BusVehicle skills: [moving] {
	BusLine bv_line;
	int bv_current_direction;
	BusStop bv_current_bs;
	BusStop bv_next_bs;
	float bv_actual_speed;
	float bv_stop_wait_time <- -1.0;
	bool bv_in_city <- true;
	bool bv_in_move <- false;
	//geometry shape <- rectangle(50#meter,25#meter);
	image_file bv_icon <- image_file("../../includes/img/bus.png");
	
	TrafficSignal bv_current_traff_sign <- nil; // when the vehicle stops at a traffic signal
	RoadSegment bv_current_rd_segment <- nil;
	list<Individual> bv_passengers <- [];
	map<BusStop,float> bv_time_table <- [];
		
	// stats
	float bv_accumulated_traffic_delay <- 0.0;
	float bv_accumulated_signs_delay <- 0.0;
	float bv_accumulated_passaging_delay <- 0.0;
	
	reflex drive {
		// if the bus has to wait
		if bv_stop_wait_time > 0 {
			bv_stop_wait_time <- bv_stop_wait_time - step;
			return;
		}
		// if the waiting time is over
		if bv_stop_wait_time = 0 {
			bv_current_bs.bs_current_stopping_buses >- self;
			bv_stop_wait_time <- -1.0;
			bv_in_move <- true;
		}
		// the current road segment of the bus
		bv_current_rd_segment <- RoadSegment(current_edge);
		
		// the bus has reached its next bus stop
		if location overlaps (10#meter around bv_next_bs.location) {
			bv_stop_wait_time <- BV_MIN_WAIT_TIME_BS;
		 	bv_in_move <- false;
			bv_current_bs <- bv_next_bs;
			bv_current_bs.bs_current_stopping_buses <+ self;
			
			// first outgoing stop : filling timetable of outgoing
			// second condition to prevent null when last out bs = first return bs
			if bv_current_bs = first(bv_line.bl_outgoing_bs) and bv_current_direction = BL_DIRECTION_OUTGOING {
				bv_time_table <- [bv_line.bl_outgoing_bs[0]::time];
				loop i from: 1 to: length(bv_line.bl_outgoing_bs)-1 {
					bv_time_table <+ bv_line.bl_outgoing_bs[i] :: bv_time_table at bv_line.bl_outgoing_bs[i-1] +
								(bv_line.bl_outgoing_dists[i-1] / bv_line.bl_com_speed) + BV_MIN_WAIT_TIME_BS;
				}
			}
			// first return stop : filling timetable of return 
			// second condition to prevent null when last out bs = first return bs
			else if bv_current_bs = first(bv_line.bl_return_bs) and bv_current_direction = BL_DIRECTION_RETURN {
				bv_time_table <- [bv_line.bl_return_bs[0]::time];
				loop i from: 1 to: length(bv_line.bl_return_bs)-1 {
					bv_time_table <+ bv_line.bl_return_bs[i] :: bv_time_table at bv_line.bl_return_bs[i-1] +
								(bv_line.bl_return_dists[i-1] / bv_line.bl_com_speed) + BV_MIN_WAIT_TIME_BS;
				}
			}	
								
			// the bus is in a bus stop inside the city
			if bv_in_city {
				// add the delay for this bus
				ask bv_current_bs {
					float del <- time - (myself.bv_time_table at self);
					if bs_bv_delays at myself = nil {
						bs_bv_delays <+ myself::del; 
					} else {
						bs_bv_delays[myself] <- bs_bv_delays[myself] + del; 
					}
				}
				
				// drop off all passengers who have arrived to their destination
				int nn <- 0; int mm <- 0;
				ask bv_passengers where (each.ind_current_bt.bt_end_bs = bv_current_bs) {
					// add the actual BusTrip to the journey 
					ind_actual_journey <+ ind_current_bt;
					
					if ind_current_bt.bt_type != BUS_TRIP_1ST_LINE { // the passenger has arrived
						myself.bv_current_bs.bs_arrived_people <+ self;
						ind_trip_times[ind_current_plan_index] <- int(time - ind_trip_times[ind_current_plan_index]);
						ind_arrived <- true;
						ind_moving <- false;
						nn <- nn + 1;
						unsaved_arrivals <+ self;
					}
					else { // the passenger is making a connection (transfert)
						if myself.bv_current_bs != ind_current_bt.bt_end_bs {
							write "ERROR in connecting at " + myself.bv_current_bs.bs_name + " by " + myself.bv_line.bl_name color:#red;
						} else {
							ind_trip_times[ind_current_plan_index] <- int(time - ind_trip_times[ind_current_plan_index]);
							ind_waiting_bs <- myself.bv_current_bs;
							ind_waiting_bs.bs_waiting_people <+ self;
							ind_current_plan_index <- ind_current_plan_index + 1;
							ind_waiting_times[ind_current_plan_index] <- int(time);
							mm <- mm + 1;
						}
					}
					myself.bv_passengers >- self;					
					myself.bv_stop_wait_time <- myself.bv_stop_wait_time + BV_TIME_DROP_IND;
					myself.bv_accumulated_passaging_delay <- myself.bv_accumulated_passaging_delay + BV_TIME_DROP_IND;
					if myself.bv_current_bs.bs_zone != nil {
						myself.bv_current_bs.bs_zone.pduz_accumulated_passaging_delay <- 
								myself.bv_current_bs.bs_zone.pduz_accumulated_passaging_delay + BV_TIME_DROP_IND;
					}
				}
				if nn > 0 {
					write world.formatted_time() + bv_line.bl_name  + ' (' + bv_current_direction + ') is dropping ' + (nn + mm) + ' people at ' + bv_current_bs.bs_name color: #blue;
					if mm > 0 {
						write '  -> Among them, ' + mm + " are connecting" color: #darkblue;
					}
					write '  -> ' + length(bv_passengers) + " people are on board" color: #darkorange;
				}

				// take the maximum number of passengers
				int n_individs <- BV_MAX_CAPACITY - length(bv_passengers);
				if n_individs > 0 {
					// list of possible waiting passengers to take
					list<Individual> waiting_inds <- bv_current_bs.bs_neighbors accumulate (each.bs_waiting_people
									// if the individual is waiting at the next bs, leave it
									where (bv_line.next_bs(bv_current_direction, bv_current_bs) = nil or
										each.ind_waiting_bs distance_to bv_current_bs <
											each.ind_waiting_bs distance_to bv_line.next_bs(bv_current_direction, bv_current_bs)
									// if the individual has a BT that can be served from here by this BV
									and !empty(each.ind_available_bt where (each.bt_bus_line = self.bv_line
										and each.bt_bus_direction = self.bv_current_direction
										and each.bt_start_bs in self.bv_current_bs.bs_neighbors)))); 

					if !empty (waiting_inds) {
						waiting_inds <- waiting_inds where( (each.ind_current_plan_index = 0 and
										!empty(each.ind_available_bt where (each.bt_bus_line = bv_line
											and each.bt_bus_direction = bv_current_direction
											and each.bt_start_bs in self.bv_current_bs.bs_neighbors
											and each.bt_type != BUS_TRIP_2ND_LINE))))
									+
									 waiting_inds where( (each.ind_current_plan_index = 1 and
									 	!empty(each.ind_available_bt where (each.bt_bus_line = bv_line
									 		and each.bt_bus_direction = bv_current_direction
									 		and each.bt_start_bs in self.bv_current_bs.bs_neighbors
									 		and each.bt_type = BUS_TRIP_2ND_LINE))));	
					}
					
					// individual that can walk by here for 1L trip
					list<BusStop> my_bus_stops <- bv_current_direction = BL_DIRECTION_OUTGOING ? bv_line.bl_outgoing_bs : bv_line.bl_return_bs; 
					list<BusStop> bv_all_neighbs <- remove_duplicates(bv_current_bs.bs_neighbors accumulate each.bs_neighbors)
																	- bv_current_bs.bs_neighbors;
					bv_all_neighbs <- bv_all_neighbs where (!(my_bus_stops contains each) and 
												(my_bus_stops closest_to each) = bv_current_bs);
					waiting_inds <- waiting_inds + (bv_all_neighbs accumulate each.bs_waiting_people
								where (each.ind_current_plan_index = 0 and !empty(each.ind_available_bt
									where (each.bt_type = BUS_TRIP_SINGLE_LINE and each.bt_bus_line = bv_line
									and each.bt_bus_direction = bv_current_direction
									and each.bt_start_bs in bv_current_bs.bs_neighbors))));
								
					if !empty (waiting_inds) {
						
						/** filter individuals based on active strategies */
						
						/***** transfer *****/			
						// if transfer is off, remove individuals with 2L-trip that can still wait for a 1L-trip
						if !transfer_on {
							// first, retrieve individuals with no 1L trips on this bus (the bus can only transfer them)
							list<Individual> inds_to_remove <- (waiting_inds where (each.ind_current_plan_index = 0 and
								empty(each.ind_available_bt where (each.bt_bus_line = bv_line
									and each.bt_bus_direction = bv_current_direction
									//and each.bt_start_bs in self.bv_current_bs.bs_neighbors
									and each.bt_type = BUS_TRIP_SINGLE_LINE))));
												
							// see if these individuals can do a 1L-trip on another bus
							if !empty(inds_to_remove) {
								// individuals with 1L trip on other busses and who can still wait for 1L trip
								inds_to_remove <- (inds_to_remove where (int(time - each.ind_waiting_times[0]) < IND_WAITING_TIME_FOR_1L_TRIPS
									and !empty(each.ind_available_bt where (each.bt_bus_line != bv_line
											//and each.bt_start_bs in self.bv_current_bs.bs_neighbors
											and each.bt_type = BUS_TRIP_SINGLE_LINE))));
								// remove
								waiting_inds <- waiting_inds - inds_to_remove;
							}
						}
						
						/***** time tables *****/
						// if passengers have information about time tables of bus lines, remove individuals that can do
						// a better trip on another line 					
						if time_tables_on {
							//write "-----------VVV " + self + "BL " + bv_line.bl_name + " BS " + bv_current_bs + " : " + bv_current_bs.bs_name;
							list<Individual> inds_to_remove <- [];
							loop indiv over: waiting_inds {
								// can this bus takes indiv to his destination
								// at first consider only trips that arrive to final destination = SINGLE and 2ND trips 
								list<BusTrip> btps <- indiv.ind_available_bt where (each.bt_bus_line = self.bv_line
											and each.bt_bus_direction = self.bv_current_direction
										and ((indiv.ind_current_plan_index = 0 and each.bt_type = BUS_TRIP_SINGLE_LINE)
												or (indiv.ind_current_plan_index = 1 and each.bt_type = BUS_TRIP_2ND_LINE
													and each.bt_start_bs in self.bv_current_bs.bs_neighbors)));
								// then if not found, consider 1ST trips
								if empty (btps) and indiv.ind_current_plan_index = 0 { // if no 1L or 2L-2nd are found, then maybe 2L-1st
									btps <- indiv.ind_available_bt where (each.bt_bus_line = self.bv_line
											and each.bt_bus_direction = self.bv_current_direction
										and (indiv.ind_current_plan_index = 0 and each.bt_type = BUS_TRIP_1ST_LINE
													and each.bt_start_bs in self.bv_current_bs.bs_neighbors) );
								}
								
								if !empty(btps) {
									// time to arrive to destination using this bus
									BusTrip bestbt <- btps where (each.bt_type != BUS_TRIP_1ST_LINE and
												each.bt_end_bs in bv_time_table.keys) with_min_of (bv_time_table at each.bt_end_bs);
									int mydist <- 0;
									if bestbt = nil {
										// time to arrive to the best correspondance
										list res_l <- best_correspondance(btps where (each.bt_type = BUS_TRIP_1ST_LINE and
																	each.bt_end_bs in bv_time_table.keys),
															indiv.ind_available_bt where (each.bt_type = BUS_TRIP_2ND_LINE));
										bestbt <- BusTrip(res_l[0]);
										mydist <- int(res_l[1]);
									}
									//write "indiv " + indiv + " This veh bestbt " + bestbt;
									float time_to_dest_this <- bv_time_table at bestbt.bt_end_bs;
									//write "time_to_dest_this " + time_to_dest_this;
									
									// theoretical arrival time not reached yet
									if time_to_dest_this > bv_time_table at self.bv_current_bs {
										
										float min_time_to_dest_others <- #max_float;
										// trips using other lines
										
										list<BusTrip> other_btps <- indiv.ind_available_bt where (each.bt_bus_line != self.bv_line
													and ((indiv.ind_current_plan_index = 0 and each.bt_type = BUS_TRIP_SINGLE_LINE)
													or (indiv.ind_current_plan_index = 1 and each.bt_type = BUS_TRIP_2ND_LINE
													and each.bt_start_bs in self.bv_current_bs.bs_neighbors)));
										// check fro 2L-1st
										if empty (other_btps) {
											other_btps <- indiv.ind_available_bt where (each.bt_bus_line != self.bv_line
													and indiv.ind_current_plan_index = 0 and each.bt_type = BUS_TRIP_1ST_LINE
													and each.bt_start_bs in self.bv_current_bs.bs_neighbors);
										}
										
										loop bt over: other_btps {
											// other busses that can serve this trip
											list<BusVehicle> bvs <- BusVehicle where (each.bv_line = bt.bt_bus_line and
												each.bv_current_direction = bt.bt_bus_direction and !empty(each.bv_time_table)
												and bt.bt_end_bs in each.bv_time_table.keys);
											if !empty(bvs) {
												// only bus vehicles who did not reach this bus stop yet
												if bt.bt_bus_direction = BL_DIRECTION_OUTGOING {
													bvs <- bvs where (each.bv_line.bl_outgoing_bs index_of each.bv_current_bs < 
														each.bv_line.bl_outgoing_bs index_of bt.bt_start_bs);
												} else {
													bvs <- bvs where (each.bv_line.bl_return_bs index_of each.bv_current_bs < 
														each.bv_line.bl_return_bs index_of bt.bt_start_bs);
												}
												if !empty(bvs) {
													BusVehicle bv <- bvs with_min_of (each.bv_time_table at bt.bt_end_bs);
													float tt <- bv.bv_time_table at bt.bt_end_bs;
													// min(bvs where (bt.bt_end_bs in each.bv_time_table.keys) accumulate (each.bv_time_table at bt.bt_end_bs));
													
													if (tt > bv.bv_time_table at self.bv_current_bs) and tt < min_time_to_dest_others {
														if bt.bt_type = BUS_TRIP_1ST_LINE {
															list<BusTrip> mytrps <- indiv.ind_available_bt where (each.bt_type = BUS_TRIP_2ND_LINE
																					and bt.bt_end_bs in each.bt_start_bs.bs_neighbors);
															if !empty(mytrps) {
																int ddist <- int(((mytrps mean_of (each.bt_bus_distance + each.bt_walk_distance))/length(mytrps))
																			+ bt.bt_bus_distance + bt.bt_walk_distance);
																if ddist < mydist {
																	min_time_to_dest_others <- tt;
																	//write "btttt 11111111st " + bt + " :: " + tt + " BV " + bv + ": " +bv.bv_line.bl_name;
																}	
															}
														} else {
															min_time_to_dest_others <- tt;
															//write "btttSSSSSINGLE or 222222222ndddd " + bt + " :: " + tt+ " BV " + bv + ": " +bv.bv_line.bl_name;
														}
													}
												}	
											}
										}
										if min_time_to_dest_others < time_to_dest_this {
											//write "remove iind " + indiv + " :: " + min_time_to_dest_others;
											inds_to_remove <+ indiv;
										}	
									}
								}
							}
							// remove
							waiting_inds <- waiting_inds - inds_to_remove;
						}

						/*******/
						nn <- 0;				
						ask n_individs among waiting_inds {
							// available bus trips with this bus line and direction
							list<BusTrip> my_bus_trips <- ind_available_bt where (each.bt_bus_line = myself.bv_line
										and each.bt_bus_direction = myself.bv_current_direction
										and each.bt_start_bs in myself.bv_current_bs.bs_neighbors);
							if !empty(my_bus_trips) {
								// the individual was waiting for a first ride
								if ind_current_plan_index = 0 {
									// best option (minimum distance) for 1L trip
									BusTrip best1L <- my_bus_trips where (each.bt_type = BUS_TRIP_SINGLE_LINE)
												with_min_of (each.bt_bus_distance + each.bt_walk_distance);
									
									if best1L != nil {
										ind_current_bt <- best1L;
									} else {
										// choose 1st trip as the one with destination is where 2nd trips have the minimum trip time									
										ind_current_bt <- BusTrip(first(myself.best_correspondance(
														my_bus_trips where (each.bt_type = BUS_TRIP_1ST_LINE),
														ind_available_bt where (each.bt_type = BUS_TRIP_2ND_LINE))));
									}				
																				
								} else {
									// the individual is making a second ride
									ind_current_bt <- my_bus_trips where (each.bt_type = BUS_TRIP_2ND_LINE)
													with_min_of (each.bt_bus_distance + each.bt_walk_distance);
								}
								// a trip has been picked
								if ind_current_bt !=nil {
									nn <- nn + 1;
									myself.bv_passengers <+ self;
									ind_waiting_bs.bs_waiting_people >- self;
									ind_waiting_bs <- nil;
									ind_waiting_times[ind_current_plan_index] <- int(time - ind_waiting_times[ind_current_plan_index]);
									ind_trip_times[ind_current_plan_index] <- int(time);	
									myself.bv_stop_wait_time <- myself.bv_stop_wait_time + BV_TIME_TAKE_IND;
									myself.bv_accumulated_passaging_delay <- myself.bv_accumulated_passaging_delay + BV_TIME_TAKE_IND;
									if myself.bv_current_bs.bs_zone != nil {
										myself.bv_current_bs.bs_zone.pduz_accumulated_passaging_delay <- 
												myself.bv_current_bs.bs_zone.pduz_accumulated_passaging_delay + BV_TIME_TAKE_IND;
									}
								} else {
									write "ERROR in finding bus trip !" color: #red;
								}	
							}
						}
						if nn > 0 {
							write world.formatted_time() + bv_line.bl_name  + ' (' + bv_current_direction + ') is taking ' + nn + ' people at ' + bv_current_bs.bs_name color: #darkgreen;
							write '  -> Passengers : ' + length(bv_passengers) + " people are on board" color: #darkorange;
						}
					}	
				} // save BV overload
				else if save_data_on {
					save '' + cycle + ',' + int(self) + ',' + bv_line.bl_name + ','  + bv_current_bs.bs_id + ',' + bv_current_bs.bs_zone.pduz_code
						format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/full_bus_vehicles.csv";
				}
			}
			// to know the next stop
			if bv_current_direction = BL_DIRECTION_OUTGOING { // outgoing
				if bv_current_bs = last(bv_line.bl_outgoing_bs) { // last outgoing stop
					bv_current_direction <- BL_DIRECTION_RETURN;
					bv_next_bs <- bv_line.bl_return_bs[0];
				} else {
					bv_next_bs <- bv_line.bl_outgoing_bs[(bv_line.bl_outgoing_bs index_of bv_next_bs) + 1];
				}
			} else { // return
				if bv_current_bs = last(bv_line.bl_return_bs) { // last return stop
					bv_current_direction <- BL_DIRECTION_OUTGOING;
					bv_next_bs <- bv_line.bl_outgoing_bs[0];
				} else {
					bv_next_bs <- bv_line.bl_return_bs[(bv_line.bl_return_bs index_of bv_next_bs) + 1];
				}
			}
			return;
		} else {
			// the bus is in a traffic signal
			if bv_current_traff_sign = nil {
				if bv_current_rd_segment != nil and !empty((bv_current_rd_segment).rs_traffic_signals) {				
					TrafficSignal ts <- bv_current_rd_segment.rs_traffic_signals closest_to self;
					float stop_prob <- ts.ts_type = TRAFFIC_STOP_SIGN ? 1 : TS_PROBA_STOP_TRAFF_LIGHT;
					// if th stopping condition is true (flip) and the bus is 10 meters around a traffic signal
					if location overlaps (10#meter around (ts)) and flip (stop_prob)  {
						// a BRT stops less than an ordinary bus
						bv_stop_wait_time <- bv_line.bl_is_brt ? TS_BRT_STOP_WAIT_TIME : TS_BUS_STOP_WAIT_TIME;
						bv_accumulated_signs_delay <- bv_accumulated_signs_delay + bv_stop_wait_time;
						if bv_current_rd_segment.rs_zone != nil {
							bv_current_rd_segment.rs_zone.pduz_accumulated_signs_delay <- 
									bv_current_rd_segment.rs_zone.pduz_accumulated_signs_delay + bv_stop_wait_time;
						}
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
			// a bus moves with the commercial speed inside Marrakesh, and BV_SUBURBAN_SPEED outside;
			if bv_in_city {
				// if it is not a BRT
				if traffic_on and !bv_line.bl_is_brt {
					// only non BRT busses are impacted by traffic level
					bv_actual_speed <- bv_line.bl_com_speed / BV_SPEED_DIVIDER[bv_current_rd_segment.rs_traffic_level];
					if bv_actual_speed < bv_line.bl_com_speed {
						float traff_del <- ((bv_line.bl_com_speed - bv_actual_speed)/bv_line.bl_com_speed)*step;
						bv_accumulated_traffic_delay <- bv_accumulated_traffic_delay + traff_del;
						if bv_current_rd_segment.rs_zone != nil {
							bv_current_rd_segment.rs_zone.pduz_accumulated_traffic_delay <- 
									bv_current_rd_segment.rs_zone.pduz_accumulated_traffic_delay + traff_del;
						}
					}
				} else {
					bv_actual_speed <- bv_line.bl_com_speed;
				}
			}
			// the bus is not in the city
			else {
				bv_actual_speed <- BV_SUBURBAN_SPEED;
			}	
		}
		// move
		do goto on: road_network target: bv_next_bs speed: bv_actual_speed;
	}
	
	//
	aspect default {
		draw bv_icon size: {50#meter,25#meter} rotate: heading;
		//draw "" + bv_line.bl_name anchor: #center font: font("Calibri", 10, #bold) color: #black;
	}
	
	list best_correspondance (list<BusTrip> firsts, list<BusTrip> seconds){
		int min_dist <- #max_int;
		int ddst <- #max_int;
		BusTrip best_bt <- nil;

		loop trip1 over: firsts {
			list<BusTrip> mysecs <- seconds where (trip1.bt_end_bs in each.bt_start_bs.bs_neighbors);
			if !empty(mysecs) {
				ddst <- int(((mysecs mean_of (each.bt_bus_distance + each.bt_walk_distance))/length(mysecs))
							+ trip1.bt_bus_distance + trip1.bt_walk_distance);
				if ddst < min_dist {
					min_dist <- ddst;
					best_bt <- trip1;
				}	
			}
		}
		return [best_bt,min_dist];
	}
}

/*** end of species definition ***/