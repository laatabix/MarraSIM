/**
* Name: Main file to launch the model.
* The model simulates the public transport traffic in Marrakesh.
* Author: Ahmed Laatabi
* i-Maroc project 
*/

model MarraSIM

import "classes/PDUZone.gaml"
import "classes/Building.gaml"

global {
	
	map<int,string> marrakech_districts <- [1::"Mechouar_Kasbah", 2::"Annakhil", 3::"Guéliz",
											4::"Médina", 5::"Menara", 6::"SYBA"];
	file marrakesh_districts <- shape_file("../includes/gis/marrakesh.shp");
	file marrakesh_pdu <- shape_file("../includes/gis/zonage_pdu.shp");
	file marrakesh_roads <- shape_file("../includes/gis/road_segments.shp");
	file marrakesh_buildings <- shape_file("../includes/gis/buildings.shp");
	file marrakesh_bus_stops <- shape_file("../includes/gis/bus_stops.shp");
	file marrakesh_traffic_lights <- shape_file("../includes/gis/traffic_signals.shp");
	
	// shape of the environment (the convex hull of regional roads shapefile)
	geometry shape <- envelope (marrakesh_roads);
	
	// affluence of passengers every hour starting from midnight (0)
	float current_affluence <- 0.0;
	list<float> h_affluence <- [0.000,0.000,0.000,0.000,0.000,0.000,0.025,0.050,0.100,0.100,0.050,0.050, // [00:00 -> 11:00]
								0.100,0.100,0.025,0.025,0.025,0.050,0.100,0.050,0.050,0.050,0.025,0.025];// [12:00 ->  23:00]
	
	// defining one simulation step as 5 seconds
	float step <- 5#second;
	
	// simulation parameters
	bool traffic_on <- true; // include congestion from Google Traffic
	bool transfer_on <- false; // allow ticket transfer between busses of the same trip
		
	init {
		write "--+-- START OF INIT --+--" color:#green;	
		// create the environment: city, districts, roads, traffic signals
		write "Creating the city environment ...";
		create District from: marrakesh_districts;
		create Building from: marrakesh_buildings;
		create PDUZone from: marrakesh_pdu with: [zone_id::int(get("id")), zone_name::get("label")];
		create RoadSegment from: marrakesh_roads with: [rs_id::int(get("segm_id")), rs_in_city::bool(int(get("city")))];
		road_network <- as_edge_graph(list(RoadSegment));
				
		// creating traffic stops and traffic lights
		create TrafficSignal from: marrakesh_traffic_lights with: [ts_type::get("fclass") = "stop" ? TRAFFIC_STOP_SIGN:TRAFFIC_LIGHT] {
			//the closest road to the traffic signal
			ts_rd_segment <- RoadSegment closest_to self;
			// garantir que le traffic signal est sur une route (touche le polyline de la route)
			location <- ts_rd_segment.shape.points closest_to self;
			ts_rd_segment.rs_traffic_signals <+ self; // this is equivalent to: "add self to: rd.traffic_signals"
		}
		
		// create busses, bus stops, and connections
		write "Creating busses and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [bs_id::int(get("stop_numbe")), bs_name::get("stop_name")]{
			bs_rd_segment <- RoadSegment closest_to self;
			location <- bs_rd_segment.shape.points closest_to self; // to draw the bus stop on a road (accessible to bus)
			bs_district <- first(District overlapping self);
			bs_zone <- first(PDUZone overlapping self);
		}
		
		matrix bustopsMatrix <- matrix(csv_file("../includes/csv/bus_lines_stops.csv",true));
		matrix buslinesMatrix <- matrix(csv_file("../includes/csv/data_lines.csv",true));
		
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
		// calculate distances of each bus line
		ask BusLine {
			loop i from: 0 to: length(bl_outgoing_bs) - 2 {
				bl_outgoing_dists <+ bl_outgoing_bs[i].dist_to_bs(bl_outgoing_bs[i+1]);
			}
			loop i from: 0 to: length(bl_return_bs) - 2 {
				bl_return_dists <+ bl_return_bs[i].dist_to_bs(bl_return_bs[i+1]);
			}
		}
		ask BusStop {
			// neighbors + self represents the waiting BSs where an individual can take or leave a bus during a trip
			bs_neighbors <- (BusStop where (each distance_to self <= 400#m)); 
		}

		// create bus connection for each line
		write "Creating bus connections ...";
		matrix busconnectionsMatrix <- matrix(csv_file("../includes/csv/bus_connections.csv",true));
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
		
		// creating n_vehicles for each bus line
		write "Creating bus vehicles ...";
		ask BusLine {
			int n_vehicles <- 2;
			if buslinesMatrix index_of bl_name != nil {
				n_vehicles <- int(buslinesMatrix[1, int((buslinesMatrix index_of bl_name).y)]);
				bl_interval_time_m <- int(buslinesMatrix[4, int((buslinesMatrix index_of bl_name).y)]);
				bl_comm_speed <- float(buslinesMatrix[7, int((buslinesMatrix index_of bl_name).y)]);
			}
			int i_counter <- 0;
			create BusVehicle number: n_vehicles {
				bv_line <- myself;				
				bv_current_bs <- bv_line.bl_outgoing_bs[0];
				bv_current_bs.bs_current_stopping_buses <+ self;
				bv_next_stop <- bv_current_bs;
				bv_direction <- BUS_DIRECTION_OUTGOING;
				location <- bv_current_bs.location;
				bv_stop_wait_time <- (bv_line.bl_interval_time_m * i_counter) #minute; // next vehicles have a waiting time
				i_counter <- i_counter + 1;
			}	
			ask last (BusVehicle where (each.bv_line = self)) {
				bv_current_bs <- bv_line.bl_return_bs[0];
				bv_current_bs.bs_current_stopping_buses <+ self;
				bv_next_stop <- bv_current_bs;
				bv_direction <- BUS_DIRECTION_RETURN;
				location <- bv_current_bs.location;
				bv_stop_wait_time <- 0.0;
			}		
		}
		
		// create the population of moving individuals between PUDZones
		write "Creating population ...";
		//TODO read pop file here
		
		write "Total population: " + length(Individual);
		write "--+-- END OF INIT --+--" color:#green;
	}
	
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
	
	// update road traffic and/or generate travellers each X minutes
	int Nminutes <- 5;
	reflex going_on when: int(time) mod int(Nminutes#minute) = 0 {
		
		int tt <- int(sim_start_hour) + int(time);
		string hh <- get_time_frag(tt, 1);
		
		if int(hh) = 24 { // midight, end of a day simulation
			do pause;
		}
		
		// Each hour, the traffic levels on roads are updated
		if traffic_on and int(time) mod int(1#hour) = 0 {
			if int(hh) >= 6 and int(hh) <= 23 { // 06:00 - 23:00 range only
				matrix rd_traff_data <- matrix(csv_file("../includes/csv/roads_traffic/" + hh + ".csv",true));
				ask RoadSegment where (each.rs_in_city) {
					rs_traffic_level <- int(rd_traff_data[1,rs_id]);
					rs_col <- G_TRAFF_COLORS[rs_traffic_level];
				}
				current_affluence <- h_affluence[int(hh)];
			} else {
				ask RoadSegment where (each.rs_in_city) {
					rs_traffic_level <- G_TRAFF_LEVEL_GREEN;
					rs_col <- G_TRAFF_COLORS[rs_traffic_level];
				}
				current_affluence <- 0.0;
			}
		}
		
		// each X minutes
		// ask a random number of people (N%) to move and make a program for their trip
		int nn <- int(current_affluence / (60/Nminutes) * length(Individual));
		write formatted_time() + "Computing travel plans for " + nn + " people";
		ask int(current_affluence / (60/Nminutes) * length(Individual)) among
		 		(Individual where (!each.ind_arrived and empty(each.ind_bt_plan))) {
		 	// TODO
			/*do make_plans;
			if !empty(ind_bt_plan) {
				ind_moving <- true;
				ind_waiting_bs <- ind_origin_bs;
				ind_waiting_bs.bs_waiting_people <+ self;
				ind_waiting_time <- int(time);
			} else { // no plan, relocate to find a plan next time
				ind_origin_bs <- one_of(BusStop where (each.bs_zone = ind_origin_zone));
				if ind_origin_bs = nil { // in case of no bus stops in the zone
					ind_origin_bs <- BusStop closest_to ind_origin_zone;
				}
			}*/
			//TODO
		}
		write formatted_time()  + "Total people waiting at bus stops : " + length(Individual where (each.ind_moving)) color: #purple;
		
		// update colors of zones
		write "Updating the colors of PDU zones ..";
		ask PDUZone {
			do update_color;
		}
	}
	
	
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
}

experiment MarraSIM type: gui {
	
	init {
		minimum_cycle_duration <- 0.05;
	}
	
	output {
		layout #split toolbars: false tabs: false editors: false navigator: false parameters: false tray: false;// consoles: false;
		display Marrakesh type: opengl background: #whitesmoke {
			camera 'default' location: {76609.6582,72520.6097,11625.0305} target: {76609.6582,72520.4068,0.0};
			
			overlay position: {10#px,10#px} size: {100#px,40#px} background: #black{
	            draw "" + world.formatted_time() at: {20#px, 25#px} font: font("Calibri", 16, #bold) color: #yellow;
	        }
	        	        			
			species District refresh:false;
			species RoadSegment;
			species Building refresh:false;
			species BusStop refresh: false;
			species TrafficSignal refresh: false;
			species BusVehicle;
		}
		
		display "Waiting People" type: opengl background: #whitesmoke{
			camera 'default' location: {76609.6582,72520.8497,25375.9837} target: {76609.6582,72520.4068,0.0};
			
			species PDUZone aspect: waiting_people;
		}
		display "Waiting Time" type: opengl background: #whitesmoke {
			camera 'default' location: {76609.6582,72520.8497,25375.9837} target: {76609.6582,72520.4068,0.0};
		
			species PDUZone aspect: waiting_time;
		}
		
		display Mobility type: java2D background: #whitesmoke {
			chart "Travellers" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {1,0.5} position: {0,0} x_label: "Time" {
				data "Waiting" color: #red value: BusStop sum_of(length(each.bs_waiting_people where (each.ind_moving))) marker_shape: marker_empty;
				data "On bus" color: #green value: BusVehicle sum_of(length(each.bv_passengers)) marker_shape: marker_empty;
				data "Arrived" color: #blue value: BusStop sum_of(length(each.bs_arrived_people)) marker_shape: marker_empty;
			}
			chart "Finished trips" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {1,0.5} position: {0,0.5} x_label: "Time" {
				data "1-Line" color: #darkgreen value: length(BusTrip where (each.bt_finished and each.bt_type = BUS_TRIP_ONE_LINE))
								marker_shape: marker_empty;
				data "2-Lines" color: #darkred value: length(BusTrip where (each.bt_finished and each.bt_type = BUS_TRIP_TWO_LINE))
							marker_shape: marker_empty;
			}
		}
	}
}
