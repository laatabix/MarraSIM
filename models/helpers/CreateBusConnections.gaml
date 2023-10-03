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
		
		/* MAIN SHARED CODE */
		
		// create the environment: city, districts, roads, traffic signals
		write "Creating the city environment ...";
		create RoadSegment from: marrakesh_roads with: [rs_id::int(get("segm_id")), rs_in_city::bool(int(get("city")))]{
			if rs_in_city {
				rs_zone <- first(PDUZone overlapping self);	
			}
		}
		road_network <- as_edge_graph(list(RoadSegment));

		// create busses, bus stops, and connections
		write "Creating busses and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [bs_id::int(get("stop_numbe")), bs_name::get("stop_name"),bs_is_brt::int(get("BRT")) = 1]{
			bs_rd_segment <- RoadSegment closest_to self;
			location <- bs_rd_segment.shape.points closest_to self; // to draw the bus stop on a road (accessible to bus)
			bs_district <- first(District overlapping self);
			bs_zone <- first(PDUZone overlapping self);
			// affect the closest zone to nearby bus stops
			if bs_zone = nil {
				PDUZone pdz <- PDUZone closest_to self;
				if self distance_to pdz <= BS_NEIGHBORING_DISTANCE {
					bs_zone <- pdz;
				}
			}
		}
		
		matrix dataMatrix <- matrix(csv_file("../../includes/csv/bus_lines_stops.csv",true));
		loop i from: 0 to: dataMatrix.rows -1 {
			string bus_line_name <- dataMatrix[0,i];
			// create the bus line if it does not exist yet
			BusLine current_bl <- first(BusLine where (each.bl_name = bus_line_name));
			
			if current_bl = nil {
				create BusLine returns: my_busline { bl_name <- bus_line_name; }
				current_bl <- my_busline[0];
			}
			BusStop current_bs <- BusStop first_with (each.bs_id = int(dataMatrix[3,i]));
			if current_bs != nil {
				if int(dataMatrix[1,i]) = BL_DIRECTION_OUTGOING {
					if length(current_bl.bl_outgoing_bs) != int(dataMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_outgoing_bs <+ current_bs;
				} else {
					if length(current_bl.bl_return_bs) != int(dataMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_return_bs <+ current_bs;
				}
				// add the BL once only if the stop is in outgoing and return
				if !(current_bs.bs_bus_lines contains current_bl) {
					current_bs.bs_bus_lines <+ current_bl;
				}
			} else {
				write "Error, the bus stop does not exist : " + dataMatrix[3,i] + " (" + dataMatrix[1,i] +")" color: #red;
				return;
			}
		}
		
		// calculate distances of each bus line
		geometry geom;
		ask BusLine {
			loop i from: 0 to: length(bl_outgoing_bs) - 2 {
				try {
					geom <- path_between(road_network, bl_outgoing_bs[i], bl_outgoing_bs[i+1]).shape;
				} catch {
					geom <- path_to(bl_outgoing_bs[i], bl_outgoing_bs[i+1]).shape;
				}
				bl_outgoing_dists <+ geom.perimeter;
				bl_shape <- bl_shape + geom;
			}
			loop i from: 0 to: length(bl_return_bs) - 2 {
				try {
					geom <- path_between(road_network, bl_return_bs[i], bl_return_bs[i+1]).shape;
				} catch {
					geom <- path_to(bl_return_bs[i], bl_return_bs[i+1]).shape;
				}
				bl_return_dists <+ geom.perimeter;
				bl_shape <- bl_shape + geom;
			}
			first(bl_outgoing_bs).bs_depart_or_terminus <- true;
			last(bl_outgoing_bs).bs_depart_or_terminus <- true;
			first(bl_return_bs).bs_depart_or_terminus <- true;
			last(bl_return_bs).bs_depart_or_terminus <- true;
		}
		ask BusStop {
			// self + neighbors represents the waiting BSs where an individual can take or leave a bus during a trip
			bs_neighbors <- (BusStop where (each distance_to self <= BS_NEIGHBORING_DISTANCE)) sort_by (each distance_to self); 
		}
		
		
		/* SPECIFIC WORK CODE */
		
		
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
		string conn_ss <- "bl1,bl2,bs1,bs2,dir1,dir2,condist" + "\n";
		
		ask BusConnection {
			conn_ss <- conn_ss + bc_bus_lines[0].bl_name + ',' + bc_bus_lines[1].bl_name + ',' + bc_bus_stops[0].bs_id + ',' + bc_bus_stops[1].bs_id
				+ ',' + bc_bus_directions[0] + ',' + bc_bus_directions[1] + ',' + bc_connection_distance + '\n';	
		}
		
		bool dl <- delete_file("../../includes/csv/bus_connections.csv");
		save conn_ss format: 'text' rewrite: true to: "../../includes/csv/bus_connections.text";
		bool rn <- rename_file("../../includes/csv/bus_connections.text","../../includes/csv/bus_connections.csv");
		
		write "DONE." color: #green;	
	}
}

experiment CreateBusConnections type: gui {}
