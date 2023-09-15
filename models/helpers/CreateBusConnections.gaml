/**
* Name: CreateBusConnections
* Description : this model creates the list of possible bus connections based on available bus lines and bus stops.
* 				The result is stored in a file to read and use by the main model.
* Authors: Laatabi
* For the i-Maroc project. 
*/

model CreateBusConnections

import "../classes/BusLine.gaml"

global {
	
	file marrakesh_bus_stops <- shape_file("../../includes/gis/bus_stops.shp");
	file marrakesh_roads <- shape_file("../../includes/gis/road_segments.shp");
	matrix bustopsMatrix <- matrix(csv_file("../../includes/csv/bus_lines_stops.csv",true));
	
	geometry shape <- envelope (marrakesh_roads);
	
	init {
		create RoadSegment from: marrakesh_roads;
		road_network <- as_edge_graph(list(RoadSegment));
		write "create RoadSegment .. OK";
		
		create BusStop from: marrakesh_bus_stops with: [bs_id::int(get("stop_numbe")), bs_name::get("stop_name")]{
			bs_rd_segment <- RoadSegment closest_to self;
			location <- bs_rd_segment.shape.points closest_to self;
		}
		write "create BusStop .. OK";
				
		loop i from: 0 to: bustopsMatrix.rows -1 {
			string bus_line_name <- bustopsMatrix[0,i];
			// create the bus line if it does not exist yet
			BusLine current_bl <- first(BusLine where (each.bl_name = bus_line_name));
			if current_bl = nil {
				create BusLine returns: my_busline { bl_name <- bus_line_name; }
				current_bl <- my_busline[0];
			}
			BusStop current_bs <- BusStop first_with (each.bs_id = int(bustopsMatrix[3,i]));
			if current_bs != nil {
				if int(bustopsMatrix[1,i]) = BL_DIRECTION_OUTGOING {
					if length(current_bl.bl_outgoing_bs) != int(bustopsMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_outgoing_bs <+ current_bs;
				} else {
					if length(current_bl.bl_return_bs) != int(bustopsMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_return_bs <+ current_bs;
				}
				// add the BL once only if the stop is in outgoing and return
				if !(current_bs.bs_bus_lines contains current_bl) {
					current_bs.bs_bus_lines <+ current_bl;
				}
			} else {
				write "Error, the bus stop does not exist : " + bustopsMatrix[3,i] + " (" + bustopsMatrix[1,i] +")" color: #red;
				return;
			}
		}
		write "create BusLine .. OK";
		
		write "Linking BusStops to BusLines ..";
		ask BusLine {
			loop i from: 0 to: length(bl_outgoing_bs) - 2 {
				bl_outgoing_dists <+ bl_outgoing_bs[i].dist_to_bs(bl_outgoing_bs[i+1]);
			}
			loop i from: 0 to: length(bl_return_bs) - 2 {
				bl_return_dists <+ bl_return_bs[i].dist_to_bs(bl_return_bs[i+1]);
			}
		}
		
		write "Computing BusStop neighbors ..";
		ask BusStop {
			// self + neighbors represents the waiting BSs where an individual can take or leave a bus during a trip
			bs_neighbors <- (BusStop where (each distance_to self <= BS_NEIGHBORING_DISTANCE)) sort_by (each distance_to self); 
		}
		
		// create bus connection for each bus line
		write "Creating bus connections ...";
		loop i from: 0 to: length(BusLine) - 2 {
			loop j from: i+1 to: length(BusLine) - 1 {
				
				// list of directions of the two bus lines : {out1,out2},{out1,ret2},{ret1,out2},{ret1,ret2}
				list<list<int>> list_dirs <- [[BL_DIRECTION_OUTGOING,BL_DIRECTION_OUTGOING],
											[BL_DIRECTION_OUTGOING,BL_DIRECTION_RETURN],
											[BL_DIRECTION_RETURN,BL_DIRECTION_OUTGOING],
											[BL_DIRECTION_RETURN,BL_DIRECTION_RETURN]];
				
				// list of intersecting bus stops between each pair of directions
				list<list<BusStop>> list_inter_bss <- [BusLine[i].bl_outgoing_bs where
									!empty(each.bs_neighbors inter BusLine[j].bl_outgoing_bs)];
				list_inter_bss <+ BusLine[i].bl_outgoing_bs where !empty(each.bs_neighbors inter BusLine[j].bl_return_bs);
				list_inter_bss <+ BusLine[i].bl_return_bs where !empty(each.bs_neighbors inter BusLine[j].bl_outgoing_bs);
				list_inter_bss <+ BusLine[i].bl_return_bs where !empty(each.bs_neighbors inter BusLine[j].bl_return_bs);

				loop idx from: 0 to: 3 {
					// if there are intersecting bus stops
					if !empty(list_inter_bss[idx]) {
						list<BusStop> current_bss1 <- list_dirs[idx][0] = BL_DIRECTION_OUTGOING ? 
											BusLine[i].bl_outgoing_bs : BusLine[i].bl_return_bs;
						list<BusStop> current_bss2 <- list_dirs[idx][1] = BL_DIRECTION_OUTGOING ? 
											BusLine[j].bl_outgoing_bs : BusLine[j].bl_return_bs;
						
						// take the first intersection as a potential connection
						list<BusStop> bs_to_connect <- [first(list_inter_bss[idx])];
						int last_con_id <- current_bss1 index_of bs_to_connect[0];
							
						loop bs0 over: (list_inter_bss[idx] - first(list_inter_bss[idx])) {
							int tx <- current_bss1 index_of bs0;
							// do not create a connection for consecutive bus stops
							if tx != last_con_id + 1 {
								bs_to_connect <+ bs0;
							}
							last_con_id <- tx;
						}
						
						loop bs0 over: bs_to_connect {
							ask BusLine[i] {
								// get the best (closest) pair if bus stops for this connection
								BusStop bs1 <- current_bss2 contains bs0 ? bs0 :current_bss2 closest_to bs0;
								// closer connection ?
								bs0 <- current_bss1 contains bs1 ? bs1 :current_bss1 closest_to bs1;
								//bs1 <- current_bss2 contains bs0 ? bs0 :current_bss2 closest_to bs0;
								do create_bc(bs0, list_dirs[idx][0], BusLine[j], bs1, list_dirs[idx][1],-1);
							}		
						}
					}
				}
			}			
		}
		
		write "Optimizing bus connections... ";
		ask BusConnection {
			BusStop bs_next <- bc_bus_lines[0].next_bs(bc_bus_directions[0],bc_bus_stops[0]);
			if bs_next != nil {
				// if the connection is better at the next stop, change to the next stop
				int dd <- bs_next.dist_to_bs(bc_bus_stops[1]);
				if dd < bc_connection_distance  {
					bc_bus_stops[0] <- bs_next;
					bc_connection_distance <- dd;
				}
			}
			BusStop bs_prev <- bc_bus_lines[0].previous_bs(bc_bus_directions[0],bc_bus_stops[0]);
			if bs_prev != nil {
				int dd <- bs_prev.dist_to_bs(bc_bus_stops[1]);
				if dd < bc_connection_distance  {
					bc_bus_stops[0] <- bs_prev;
					bc_connection_distance <- dd;
				}
			}
			bs_next <- bc_bus_lines[1].next_bs(bc_bus_directions[1],bc_bus_stops[1]);
			if bs_next != nil {
				int dd <- bs_next.dist_to_bs(bc_bus_stops[0]);
				if dd < bc_connection_distance  {
					bc_bus_stops[1] <- bs_next;
					bc_connection_distance <- dd;
				}
			}
			bs_prev <- bc_bus_lines[1].previous_bs(bc_bus_directions[1],bc_bus_stops[1]);
			if bs_prev != nil {
				int dd <- bs_prev.dist_to_bs(bc_bus_stops[0]);
				if dd < bc_connection_distance  {
					bc_bus_stops[1] <- bs_prev;
					bc_connection_distance <- dd;
				}
			}
		}
		write "Number of created bus connections: " + length(BusConnection);

		write "Saving bus connections to a text file ...";
		bool dl <- delete_file("../../includes/csv/bus_connections.csv");
		save "bl1,bl2,bs1,bs2,dir1,dir2,condist" format: 'text' rewrite: true to: "../../includes/csv/bus_connections.text";
		ask BusConnection {
			save bc_bus_lines[0].bl_name + ',' + bc_bus_lines[1].bl_name + ',' + bc_bus_stops[0].bs_id + ',' + bc_bus_stops[1].bs_id
				+ ',' + bc_bus_directions[0] + ',' + bc_bus_directions[1] + ',' + bc_connection_distance
				format: "text" rewrite: false to: "../../includes/csv/bus_connections.text";	
		}
		bool rn <- rename_file("../../includes/csv/bus_connections.text","../../includes/csv/bus_connections.csv");//*/
		write "DONE." color: #green;	
	}
}

experiment CreateBusConnections type: gui {}
