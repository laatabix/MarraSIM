/**
* Name: CreatePopulationTravelPlans
* Description : this model creates the population and the possible bus trips for each individual.
* 				The result is stored in a file to read and use by the main model.
* Authors: Laatabi
* For the i-Maroc project. 
*/

model CreatePopulationTravelPlans

import "../classes/BusLine.gaml"

global {
	
	file marrakesh_districts <- shape_file("../../includes/gis/marrakesh.shp");
	file marrakesh_pdu <- shape_file("../../includes/gis/zonage_pdu.shp");
	file marrakesh_roads <- shape_file("../../includes/gis/road_segments.shp");
	file marrakesh_bus_stops <- shape_file("../../includes/gis/bus_stops.shp");
	geometry shape <- envelope (marrakesh_roads);
	
	init {
		create District from: marrakesh_districts;
		create PDUZone from: marrakesh_pdu with: [pduz_code::int(get("id")), pduz_name::get("label")];
		write "create districts and zones .. OK";
		
		create RoadSegment from: marrakesh_roads;
		road_network <- as_edge_graph(list(RoadSegment));
		write "create RoadSegment .. OK";
		
		write "Creating busses and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [bs_id::int(get("stop_numbe")), bs_name::get("stop_name")]{
			bs_rd_segment <- RoadSegment closest_to self;
			location <- bs_rd_segment.shape.points closest_to self; // to draw the bus stop on a road (accessible to bus)
			bs_district <- first(District overlapping self);
			bs_zone <- first(PDUZone overlapping self);
			// if its in the city and did not overlap a PDU zone, affect the closest one
			// the two shapefiles boundaries of districts and PDU are not completely identical !
			if bs_zone = nil and bs_district != nil {
				bs_zone <- PDUZone closest_to self;
			}
		}
		write "create BusStop .. OK";
		
		matrix bustopsMatrix <- matrix(csv_file("../../includes/csv/bus_lines_stops.csv",true));
		
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
		
		write "Creating bus connections ...";
		matrix busconnectionsMatrix <- matrix(csv_file("../../includes/csv/bus_connections.csv",true));
		loop i from: 0 to: busconnectionsMatrix.rows -1 {
			BusLine bl <- BusLine first_with (each.bl_name = busconnectionsMatrix[0,i]);
			if bl != nil {
				ask bl {
					do create_bc (BusStop first_with (each.bs_id = int(busconnectionsMatrix[2,i])),
						int(busconnectionsMatrix[4,i]),
						BusLine first_with (each.bl_name = busconnectionsMatrix[1,i]),
						BusStop first_with (each.bs_id = int(busconnectionsMatrix[3,i])),
						int(busconnectionsMatrix[5,i]), int(busconnectionsMatrix[6,i]));
				}
			} else {
				write "Error: nil BusLine while reading bus_connections file!" color: #red;
			}
		}
		
		write "Creating population ...";
		matrix<int> ODMatrix <- matrix<int>(csv_file("../../includes/csv/ODMatrix.csv",false));
		loop i from: 0 to: ODMatrix.rows -1 {
			PDUZone o_zone <- PDUZone first_with (each.pduz_code = i+1);
			list<BusStop> obstops <- BusStop where (each.bs_zone = o_zone);
			loop j from: 0 to: ODMatrix.columns -1{
				PDUZone d_zone <- PDUZone first_with (each.pduz_code = j+1);
				list<BusStop> dbstops <- BusStop where (each.bs_zone = d_zone);
				create Individual number: ODMatrix[j,i]{
					ind_id <- int(self);
					ind_origin_zone <- o_zone;
					ind_destin_zone <- d_zone;
					ind_origin_bs <- one_of(obstops);
					if ind_origin_bs = nil { // in case of no bus stops in the zone
						ind_origin_bs <- BusStop closest_to ind_origin_zone;
					}
					ind_destin_bs <- one_of(dbstops);
					if ind_destin_bs = nil {
						ind_destin_bs <- BusStop closest_to ind_destin_zone;
					}
				}
			}	
		}
		write "Total population: " + length(Individual);
		
		write "Creating travel plans ..";
		ask Individual {
			// if another individual with the same origin and destination bus stops has already a planning, just copy it
			Individual ind <- first(Individual where (!empty(each.ind_available_bt) and
							each.ind_origin_bs = self.ind_origin_bs and each.ind_destin_bs = self.ind_destin_bs));
			if ind != nil {
				self.ind_available_bt <- copy (ind.ind_available_bt);	
			} else { // else, compute
				do make_plans;
			}
			write ind_id;
		}
		write "1 - Population with a plan : " + length(Individual where !empty(each.ind_available_bt));	
		
		write "Recomputing planning for individuals without plans..";
		ask Individual where empty(each.ind_available_bt) {
			Individual ind <- one_of(Individual where (!empty(each.ind_available_bt) and
							each.ind_origin_zone = self.ind_origin_zone and each.ind_destin_zone = self.ind_destin_zone));
			if ind = nil {
				ind <- one_of(Individual where (!empty(each.ind_available_bt)));
			}
			if ind != nil {
				self.ind_origin_zone <- ind.ind_origin_zone;
				self.ind_origin_bs <- ind.ind_origin_bs;
				self.ind_destin_zone <- ind.ind_destin_zone;
				self.ind_destin_bs <- ind.ind_destin_bs;
				self.ind_available_bt <- copy(ind.ind_available_bt);	
			} else {
				do die;
			}
		}
		write "2 - Population with a plan : " + length(Individual where !empty(each.ind_available_bt));
		
		write "Saving populations and travel plans to text files ...";
		bool dl <- delete_file("../../includes/csv/populations.csv");
		dl <- delete_file("../../includes/csv/travel_plans.csv");
		save "ind,ozone,dzone,obs,dbs" format: 'text' rewrite: true to: "../../includes/csv/populations.text";
		save "ind,type,start,bl1,bs1,dir1,dist1,bl2,bs2,dir2,dist2,walk" format: 'text' rewrite: true to: "../../includes/csv/travel_plans.text";
		
		ask Individual {
			save '' + ind_id + ',' + ind_origin_zone.pduz_code + ',' + ind_destin_zone.pduz_code + ',' + 
							ind_origin_bs.bs_id + ',' + ind_destin_bs.bs_id
					format: "text" rewrite: false to: "../../includes/csv/populations.text";
			
			loop bt over: ind_available_bt {
				save '' + ind_id + ',' + bt.bt_type + ',' + bt.bt_start_bs.bs_id + ',' + bt.bt_bus_line.bl_name + ',' +
						bt.bt_end_bs.bs_id + ',' + bt.bt_bus_direction + ',' + bt.bt_bus_distance + ',' + bt.bt_walk_distance
						format: "text" rewrite: false to: "../../includes/csv/travel_plans.text";
			}	
		}
		
		bool rn <- rename_file("../../includes/csv/populations.text","../../includes/csv/populations.csv");
		rn <- rename_file("../../includes/csv/travel_plans.text","../../includes/csv/travel_plans.csv");	
		
		write "DONE." color: #green;
	}
}

experiment CreatePopulationTravelPlans type: gui {}

