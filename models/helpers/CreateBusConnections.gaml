/**
* Name: CreateBusConnections
* Description : this model creates the list of possible bus connections based on available bus lines and bus stops.
* 				The result is stored on a file that is read by the main model.
* Author: Laatabi
* Tags: 
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
				if int(bustopsMatrix[1,i]) = BUS_DIRECTION_OUTGOING {
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
			// neighbors + self represents the waiting BSs where an individual can take or leave a bus during a trip
			bs_neighbors <- (BusStop where (each distance_to self <= BS_NEIGHBORING_DISTANCE)); 
		}
		
		// create bus connection for each bus line
		write "Creating bus connections ...";
		ask BusLine {
			// for each bus stop in the bus line
			loop bs1 over: self.bl_outgoing_bs - self.bl_outgoing_bs[0] {
				// for all stops that are in a circle of 400m around and where there are other bus lines
				if !empty(bs1.bs_neighbors) {
					// get the list of bus lines that pass by these bus stops
					list<BusLine> connected_bls <- bs1.bs_neighbors accumulate (each.bs_bus_lines);
					connected_bls <- remove_duplicates(connected_bls) - self;
					loop cbl over: connected_bls {
						// create a connection between bs1 and its closest bustop that is in
						// the outgoing list of the connected bus
						list<BusStop> inter_bss <- bs1.bs_neighbors inter cbl.bl_outgoing_bs;
						BusStop bs2 <- length(inter_bss) = 1 ? inter_bss[0] : inter_bss closest_to bs1;
						if bs2 != nil and !unnecessary_bc(BUS_DIRECTION_OUTGOING, bs1, cbl, BUS_DIRECTION_OUTGOING, bs2) {
							if !similar_bc_exists (BUS_DIRECTION_OUTGOING, bs1, cbl, BUS_DIRECTION_OUTGOING, bs2) {
								do create_bc(bs1, BUS_DIRECTION_OUTGOING, cbl, bs2, BUS_DIRECTION_OUTGOING,-1);	
							}
						}
						// another connection with the return list of the connected bus
						inter_bss <- bs1.bs_neighbors inter cbl.bl_return_bs;
						bs2 <- length(inter_bss) = 1 ? inter_bss[0] : inter_bss closest_to bs1;
						if bs2 != nil and !unnecessary_bc(BUS_DIRECTION_OUTGOING, bs1, cbl, BUS_DIRECTION_RETURN, bs2) {
							if !similar_bc_exists (BUS_DIRECTION_OUTGOING, bs1, cbl, BUS_DIRECTION_RETURN, bs2) {
								do create_bc(bs1, BUS_DIRECTION_OUTGOING, cbl, bs2, BUS_DIRECTION_RETURN,-1);	
							}
						}
					}
				}
			}
			loop bs1 over: self.bl_return_bs - self.bl_return_bs[0] {
				// for all stops that are in a circle of 400m around and where there are other bus lines
				if !empty(bs1.bs_neighbors) {
					// get the list of bus lines that pass by these bus stops
					list<BusLine> connected_bls <- bs1.bs_neighbors accumulate (each.bs_bus_lines);
					connected_bls <- remove_duplicates(connected_bls) - self;
					loop cbl over: connected_bls {
						// create a connection between bs1 and its closest bustop that is in
						// the outgoing list of the connected bus
						list<BusStop> inter_bss <- bs1.bs_neighbors inter cbl.bl_outgoing_bs;
						BusStop bs2 <- length(inter_bss) = 1 ? inter_bss[0] : inter_bss closest_to bs1;
						if bs2 != nil and !unnecessary_bc(BUS_DIRECTION_RETURN, bs1, cbl, BUS_DIRECTION_OUTGOING, bs2) {
							if !similar_bc_exists (BUS_DIRECTION_RETURN, bs1, cbl, BUS_DIRECTION_OUTGOING, bs2) {
								do create_bc(bs1, BUS_DIRECTION_RETURN, cbl, bs2, BUS_DIRECTION_OUTGOING,-1);	
							}	
						}
						// another connection with the return list of the connected bus
						inter_bss <- bs1.bs_neighbors inter cbl.bl_return_bs;
						bs2 <- length(inter_bss) = 1 ? inter_bss[0] : inter_bss closest_to bs1;
						if bs2 != nil and !unnecessary_bc(BUS_DIRECTION_RETURN, bs1, cbl, BUS_DIRECTION_RETURN, bs2) {
							if !similar_bc_exists (BUS_DIRECTION_RETURN, bs1, cbl, BUS_DIRECTION_RETURN, bs2) {
								do create_bc(bs1, BUS_DIRECTION_RETURN, cbl, bs2, BUS_DIRECTION_RETURN,-1);	
							}
						}
					}
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
		bool rn <- rename_file("../../includes/csv/bus_connections.text","../../includes/csv/bus_connections.csv");
		write "DONE." color: #green;	
	}
}

experiment CreateBusConnections type: gui {}
