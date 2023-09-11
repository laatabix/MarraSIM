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
	
	// defining one simulation step as one minute
	float step <- 1#minute;
	font AFONT0 <- font("Calibri", 16, #bold);
	
	// simulation parameters 
	bool save_data_on <- false; // whether to save simulation data (to /results) or not
	float sim_id;
	
	// stats
	int waiting_people_for_1st <- 0 update: BusStop sum_of(length(each.bs_waiting_people where (each.ind_current_plan_index=0)));
	int waiting_people_for_2nd <- 0 update: BusStop sum_of(length(each.bs_waiting_people where (each.ind_current_plan_index=1)));
	int passengers_on_board <- 0 update: BusVehicle sum_of(length(each.bv_passengers));
	int arrived_people_to_dest <- 0 update: BusStop sum_of(length(each.bs_arrived_people));
	
	//int finished_1L_trips <- 0 update: Individual where !empty(each.ind_used_bts) sum_of length(each.ind_used_bts where (each.bt_type = BUS_TRIP_ONE_LINE));
	//int finished_2L_trips <- 0 update: Individual where !empty(each.ind_used_bts) sum_of length(each.ind_used_bts where (each.bt_type = BUS_TRIP_TWO_LINE));
	int finished_1L_trips <- 0 update: length(Individual where (each.ind_arrived and length(each.ind_used_bts) = 1));
	int finished_2L_trips <- 0 update: length(Individual where (each.ind_arrived and length(each.ind_used_bts) = 2));
	
	float mean_travel_time_1L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_used_bts) = 1) mean_of (each.ind_trip_time);
	float mean_travel_time_2L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_used_bts) = 2) mean_of (each.ind_trip_time);
	
	float mean_waiting_time_1L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_used_bts) = 1) mean_of (sum(each.ind_waiting_times));
	float mean_waiting_time_2L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_used_bts) = 2) mean_of (sum(each.ind_waiting_times));
	
	init {
		write "--+-- START OF INIT --+--" color:#green;
		
		if !save_data_on { // warn when save data is off
			bool data_off_ok <- user_confirm("Confirm","Data saving is off. Do you want to proceed ?");
			if !data_off_ok {
				do die;
			}
		} else {
			sim_id <- machine_time;
			save "cycle,pduzone,w_people,w_time" format: 'text' rewrite: true to: "../results/data_"+sim_id+"/pduzones.csv";
			save "cycle,waiting1st,waiting2nd,onboard,arrived" format: 'text' rewrite: true to: "../results/data_"+sim_id+"/individuals.csv";
			save "cycle,tt1l,tt2l,wt1l,wt2l" format: 'text' rewrite: true to: "../results/data_"+sim_id+"/times.csv";
			save "cycle,bl,outs,rets,outs_board,rets_board,outs_traff,rets_traff,outs_sign,rets_sign,outs_psg,rets_psg"
					format: 'text' rewrite: true to: "../results/data_"+sim_id+"/buslines.csv";
			save "cycle,ind,origin,destin,bttype,idx,bl,dir,dist,walk"
					format: 'text' rewrite: true to: "../results/data_"+sim_id+"/bustrips.csv";	
		}
		
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
		
		matrix dataMatrix <- matrix(csv_file("../includes/csv/bus_lines_stops.csv",true));
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
				if int(dataMatrix[1,i]) = BUS_DIRECTION_OUTGOING {
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
			// neighbors + self represents the waiting BSs where an individual can take or leave a bus during a trip
			bs_neighbors <- (BusStop where (each distance_to self <= BS_NEIGHBORING_DISTANCE)); 
		}
		
		// create bus connection for each line
		write "Creating bus connections ...";
		dataMatrix <- matrix(csv_file("../includes/csv/bus_connections.csv",true));
		loop i from: 0 to: dataMatrix.rows -1 {
			BusLine bl <- BusLine first_with (each.bl_name = dataMatrix[0,i]);
			if bl != nil {
				ask bl {
					do create_bc (BusStop first_with (each.bs_id = int(dataMatrix[2,i])),
						int(dataMatrix[4,i]),
						BusLine first_with (each.bl_name = dataMatrix[1,i]),
						BusStop first_with (each.bs_id = int(dataMatrix[3,i])),
						int(dataMatrix[5,i]), int(dataMatrix[6,i]));
				}
			} else {
				write "Error: nil BusLine while reading bus_connections file!" color: #red;
			}
		}
		
		// creating n_vehicles for each bus line
		write "Creating bus vehicles ...";
		dataMatrix <- matrix(csv_file("../includes/csv/bus_lines_data.csv",true));
		ask BusLine {
			int n_vehicles <- 2;
			if dataMatrix index_of bl_name != nil {
				n_vehicles <- int(dataMatrix[1, int((dataMatrix index_of bl_name).y)]);
				bl_interval_time_m <- int(dataMatrix[4, int((dataMatrix index_of bl_name).y)]);
				bl_com_speed <- float(dataMatrix[7, int((dataMatrix index_of bl_name).y)]) #km/#h;
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
		dataMatrix <- matrix(csv_file("../includes/csv/populations_1000.csv",true));
		loop i from: 0 to: dataMatrix.rows -1 {
			create Individual {
				ind_id <- int(dataMatrix[0,i]);
				ind_origin_zone <- PDUZone first_with (each.zone_id = int(dataMatrix[1,i]));
				ind_destin_zone <- PDUZone first_with (each.zone_id = int(dataMatrix[2,i]));
				ind_origin_bs <- BusStop first_with (each.bs_id = int(dataMatrix[3,i]));
				ind_destin_bs <- BusStop first_with (each.bs_id = int(dataMatrix[4,i]));	
			}
		}
		
		write "Creating travel plans ...";
		dataMatrix <- matrix(csv_file("../includes/csv/travel_plans_1000.csv",true));
		int id_0 <- -1;
		int id_x;
		Individual indiv_x;
		loop i from: 0 to: dataMatrix.rows -1 {
			id_x <-  int(dataMatrix[0,i]);
			if id_x != id_0 {
				id_0 <- id_x;
				indiv_x <- Individual first_with (each.ind_id = id_x);
			}
			create BusTrip {
				bt_type <- int(dataMatrix[1,i]);
				bt_start_bs <- BusStop first_with (each.bs_id = int(dataMatrix[2,i]));
				bt_bus_lines <- [BusLine first_with (each.bl_name = string(dataMatrix[3,i]))];
				bt_bus_stops <- [BusStop first_with (each.bs_id = int(dataMatrix[4,i]))];
				bt_bus_directions <- [int(dataMatrix[5,i])];
				bt_bus_dists <- [int(dataMatrix[6,i])];
				if bt_type = BUS_TRIP_TWO_LINE {
					bt_bus_lines <+ BusLine first_with (each.bl_name = string(dataMatrix[7,i]));
					bt_bus_stops <+ BusStop first_with (each.bs_id = int(dataMatrix[8,i]));
					bt_bus_directions <+ int(dataMatrix[9,i]);
					bt_bus_dists <+ int(dataMatrix[10,i]);
				}
				bt_walk_dist <- int(dataMatrix[11,i]);
				indiv_x.ind_bt_plan <+ self; 	
			}
		}
		
		write "Total population: " + length(Individual);
		write "--+-- END OF INIT --+--" color:#green;
	}
	
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
	
	// update road traffic and/or generate travellers each X minutes
	int Nminutes <- 10; // Nminutes has to be a divider of 1hour to allow updating traffic levels (done by hour)
	reflex going_on when: int(time) mod int(Nminutes#minute) = 0 {
		
		int tt <- int(sim_start_hour) + int(time);
		string hh <- get_time_frag(tt, 1);
		
		if int(hh) = 24 { // midight, end of a day simulation
			do pause;
		}
		
		// Each hour, the traffic levels on roads are updated
		if int(time) mod int(1#hour) = 0 {
			if int(hh) >= 6 and int(hh) <= 23 { // 06:00 - 23:00 range only
				current_affluence <- h_affluence[int(hh)];
				if traffic_on {
					matrix rd_traff_data <- matrix(csv_file("../includes/csv/roads_traffic/" + hh + ".csv",true));
					ask RoadSegment where (each.rs_in_city) {
						rs_traffic_level <- int(rd_traff_data[1,rs_id]);
						rs_col <- G_TRAFF_COLORS[rs_traffic_level];
					}
				}
			} else {
				current_affluence <- 0.0;
				if traffic_on {
					ask RoadSegment where (each.rs_in_city) {
						rs_traffic_level <- G_TRAFF_LEVEL_GREEN;
						rs_col <- G_TRAFF_COLORS[rs_traffic_level];
					}
				}
			}
		}
		
		// each X minutes
		// ask a random number of people (N%) to move and make a program for their trip
		int nn <- int(current_affluence / (60/Nminutes) * length(Individual));
		write formatted_time() + nn + " new people are travelling ...";
		ask nn among (Individual where (!each.ind_moving)) {
			ind_moving <- true;
			ind_waiting_bs <- ind_origin_bs;
			ind_waiting_bs.bs_waiting_people <+ self;
			ind_waiting_times[0] <- int(time);
		}
		write formatted_time()  + "Total people waiting at bus stops : " + length(Individual where (each.ind_moving)) color: #purple;
		
		// update colors of zones
		write "Updating the colors of PDU zones ..";
		ask PDUZone {
			list<int> indicators <- update_color();
			if save_data_on {
				save '' + cycle + ',' + zone_id + ',' + indicators[0] + ',' + indicators[1]
											format: "text" rewrite: false to: "../results/data_"+sim_id+"/pduzones.csv";
			}
		}
		
		// save data if it is on
		if save_data_on {
			save '' + cycle + ',' + waiting_people_for_1st + ',' + waiting_people_for_2nd + ',' +
				passengers_on_board + ',' + arrived_people_to_dest
					format: "text" rewrite: false to: "../results/data_"+sim_id+"/individuals.csv";
					
			save '' + cycle + ',' + mean_travel_time_1L + ',' + mean_travel_time_2L + ',' + 
					mean_waiting_time_1L + ',' + mean_waiting_time_2L
					format: "text" rewrite: false to: "../results/data_"+sim_id+"/times.csv";
						
			ask BusLine {
				list<BusVehicle> bvs <- BusVehicle where (each.bv_line = self);
				list<BusVehicle> outs <- bvs where (each.bv_direction = BUS_DIRECTION_OUTGOING);
				list<BusVehicle> rets <- bvs where (each.bv_direction = BUS_DIRECTION_RETURN);
				
				save '' + cycle + ',' + bl_name + ',' + length(outs) + ',' + length(rets) + ',' +
					outs sum_of length(each.bv_passengers) + ',' + rets sum_of length(each.bv_passengers) + ',' +
					outs sum_of (each.bv_accumulated_traffic_delay) + ',' + rets sum_of (each.bv_accumulated_traffic_delay) + ',' +
					outs sum_of (each.bv_accumulated_signs_delay) + ',' + rets sum_of (each.bv_accumulated_signs_delay) + ',' +
					outs sum_of (each.bv_accumulated_passaging_delay) + ',' + rets sum_of (each.bv_accumulated_passaging_delay)
						format: "text" rewrite: false to: "../results/data_"+sim_id+"/buslines.csv";
			}
			
			ask unsaved_arrivals {
				save '' + cycle + ',' + ind_id + ',' + ind_origin_zone.zone_id + ',' + ind_destin_zone.zone_id + ',' + 
					ind_used_bts[0].bt_type + ',' + 0 + ',' + ind_used_bts[0].bt_bus_lines[0].bl_name + ',' +
					ind_used_bts[0].bt_bus_directions[0] + ',' + ind_used_bts[0].bt_bus_dists[0] + ',' + ind_used_bts[0].bt_walk_dist
							format: "text" rewrite: false to: "../results/data_"+sim_id+"/bustrips.csv";
				if length(ind_used_bts) = 2 {
					save '' + cycle + ',' + ind_id + ',' + ind_used_bts[1].bt_start_bs.bs_zone.zone_id + ',' + 
							last(ind_used_bts[1].bt_bus_stops).bs_zone.zone_id+ ',' +
					ind_used_bts[1].bt_type + ',' + 1 + ',' + last(ind_used_bts[1].bt_bus_lines).bl_name + ',' +
					last(ind_used_bts[1].bt_bus_directions) + ',' + last(ind_used_bts[1].bt_bus_dists) + ',' + ind_used_bts[1].bt_walk_dist
							format: "text" rewrite: false to: "../results/data_"+sim_id+"/bustrips.csv";
				}
			}
			unsaved_arrivals <- [];
		}
	}
	
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
}

experiment MarraSIM type: gui {
	
	parameter "Show Bus Lines" category:"Visualization" var: show_buslines;
	
	parameter "Use Google Traffic" category:"Traffic" var: traffic_on;
	
	parameter "Free Transfer" category:"Bus network" var: transfer_on;
	
	init {
		minimum_cycle_duration <- 0.05;
	}
	
	output {
		//layout #split toolbars: false tabs: false editors: false navigator: false parameters: true tray: false consoles: true;
		
		display Marrakesh type: opengl background: #whitesmoke {
			camera 'default' location: {76609.6582,72520.6097,11625.0305} target: {76609.6582,72520.4068,0.0};
			
			overlay position: {10#px,10#px} size: {100#px,40#px} background: #gray{
	            draw "" + world.formatted_time() at: {20#px, 25#px} font: AFONT0 color: #yellow;
	        }
	       	        	        			
			species District refresh:false;
			species RoadSegment;
			species Building refresh:false;
			species BusLine;
			species BusStop refresh: false;
			species TrafficSignal refresh: false;
			species BusVehicle;
		}
		
		display "Waiting People" type: opengl background: #whitesmoke{
			camera 'default' location: {76609.6582,72520.8497,25375.9837} target: {76609.6582,72520.4068,0.0};
			
			overlay position: {1,0.01} size: {140#px,140#px} background: #gray{
	            draw "Waiting people" at: {20#px, 15#px} font: AFONT0 color: #white;
                
                loop i from: 0 to: length(PDUZ_WP_THRESHOLDS)-1 {
                    draw square(10#px) at: {20#px,(30+(15*i))#px} color: PDUZ_COLORS[i];
                    draw '<' + PDUZ_WP_THRESHOLDS[i] at: {40#px,(33+(15*i))#px} color: #yellow font: AFONT0;
                }
                draw square(10#px) at: {20#px,(30+(15*length(PDUZ_WP_THRESHOLDS)))#px} color: last(PDUZ_COLORS);
                draw '>' + last(PDUZ_WP_THRESHOLDS) at: {40#px,(33+(15*length(PDUZ_WP_THRESHOLDS)))#px} color: #yellow font: AFONT0;
	        }
			
			species PDUZone aspect: waiting_people;
		}
		display "Waiting Time" type: opengl background: #whitesmoke {
			camera 'default' location: {76609.6582,72520.8497,25375.9837} target: {76609.6582,72520.4068,0.0};
			
			overlay position: {1,0.01} size: {140#px,140#px} background: #gray{
	        	draw "Waiting time (m)" at: {20#px, 15#px} font: AFONT0 color: #white;
	        	
	        	 loop i from: 0 to: length(PDUZ_WT_THRESHOLDS)-1 {
                    draw square(10#px) at: {20#px,(30+(15*i))#px} color: PDUZ_COLORS[i];
                    draw '<' + int(PDUZ_WT_THRESHOLDS[i]/60) at: {40#px,(33+(15*i))#px} color: #yellow font: AFONT0;
                }
                draw square(10#px) at: {20#px,(30+(15*length(PDUZ_WT_THRESHOLDS)))#px} color: last(PDUZ_COLORS);
                draw '>' + int(last(PDUZ_WT_THRESHOLDS)/60) at: {40#px,(33+(15*length(PDUZ_WT_THRESHOLDS)))#px} color: #yellow font: AFONT0;
	        }
	        
			species PDUZone aspect: waiting_time;
		}
		
		display Mobility type: java2D background: #whitesmoke {
			chart "Number of Travellers" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0,0} x_label: "Time" {
				data "1st wait" color: #red value: waiting_people_for_1st marker_shape: marker_empty;
				data "Transfer wait" color: #darkred value: waiting_people_for_2nd marker_shape: marker_empty;
				data "On bus" color: #green value: passengers_on_board marker_shape: marker_empty;
				data "Arrived" color: #blue value: arrived_people_to_dest marker_shape: marker_empty;
			}
			chart "Number of Finished trips" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0.5,0} x_label: "Time" {
				data "1-Line" color: #darkgreen value: finished_1L_trips marker_shape: marker_empty;
				data "2-Lines" color: #darkred value: finished_2L_trips marker_shape: marker_empty;
			}
			chart "Mean Travel Time (m)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0,0.34} x_label: "Time" {
				data "1-L trips" color: #darkgreen value: mean_travel_time_1L/1#mn marker_shape: marker_empty;
				data "2-L trips" color: #gamablue value: mean_travel_time_2L/1#mn marker_shape: marker_empty;
			}
			chart "Mean Waiting Time at Bus Stops (m)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0.5,0.34} x_label: "Time" {
				data "1-L trips" color: #darkgreen value: mean_waiting_time_1L/1#mn marker_shape: marker_empty;
				data "2-L trips" color: #gamablue value: mean_waiting_time_2L/1#mn marker_shape: marker_empty;
			}
			chart "Accumulated Delay (m)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0,0.67} x_label: "Time" {
				data "Road traffic" color: #darkred value: BusVehicle sum_of(each.bv_accumulated_traffic_delay)/1#mn marker_shape: marker_empty;
				data "Traffic signs" color: #darkblue value: BusVehicle sum_of(each.bv_accumulated_signs_delay)/1#mn marker_shape: marker_empty;
				data "Passengers" color: #darkviolet value: BusVehicle sum_of(each.bv_accumulated_passaging_delay)/1#mn marker_shape: marker_empty;
			}
			chart "Mean of Bus Speed (km/h)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0.5,0.67} x_label: "Time" {
				data "Theoretical commercial speed" color: #darkgreen value: BusVehicle mean_of(each.bv_line.bl_com_speed) marker_shape: marker_empty;
				data "Actual simulation speed" color: #darkred value: BusVehicle mean_of(each.bv_speed) marker_shape: marker_empty;
			}
		}
	}
}
