 	/**
* Name: Main
* Description: this is the main file to launch the MarraSIM model.
* 			The model simulates the public transport traffic in Marrakesh.
* 			The current version of the model includes the bus network.
* 			The Grand Taxi network will be included in the next version.
* 
* Authors: Laatabi
* For the i-Maroc project. 
*/

model MarraSIM
import "classes/PDUZone.gaml"
import "classes/Building.gaml"
import "classes/TaxiVehicle.gaml"
import "classes/TaxiRoad.gaml"
import "classes/TaxiStations.gaml"


global {

	// shapefiles of the model environment
	file marrakesh_districts <- shape_file("../includes/gis/marrakesh.shp"); // administrative districts
	file marrakesh_pdu <- shape_file("../includes/gis/zonage_pdu.shp"); // PDU (Plan de Déplacement Urbain) zoning
	file marrakesh_roads <- shape_file("../includes/gis/road_segments.shp"); // road network
	file marrakesh_buildings <- shape_file("../includes/gis/buildings.shp"); // buildings
	file marrakesh_bus_stops <- shape_file("../includes/gis/bus_stops.shp"); // bus stops
	file marrakesh_traffic_signals <- shape_file("../includes/gis/traffic_signals.shp"); // traffic signals (stop signs and traffic lights)
	file marrakesh_GrandTaxis_roads <- shape_file("../includes/gis/taxi_roads.shp"); // Grand Taxis trajectory
	file marrakesh_GrandTaxis_stations <- shape_file("../includes/gis/Taxi_Stations.shp"); // Grand Taxis stations
	
	// shape of the environment (the convex hull of regional roads shapefile)
	geometry shape <- envelope (marrakesh_roads);
	
	
	// affluence of passengers every hour starting from midnight (0). These data are based on assumption and may not be accurate 
	float current_affluence <- 0.0;
	list<float> h_affluence <- [0.000,0.000,0.000,0.000,0.000,0.000,0.025,0.050,0.100,0.100,0.050,0.050, // [00:00 -> 11:00]
								0.100,0.100,0.050,0.050,0.050,0.050,0.100,0.050,0.025,0.025,0.025,0.000];// [12:00 ->  23:00]
	
	// simulation parameters
	float step <- 10#second;// defining one simulation step as X seconds
	font AFONT0 <- font("Calibri", 16, #bold);
	
	// stats and displayed graphs
	int waiting_people_for_1st <- 0 update: BusStop sum_of(length(each.bs_waiting_people where (each.ind_current_plan_index=0)));
	int waiting_people_for_2nd <- 0 update: BusStop sum_of(length(each.bs_waiting_people where (each.ind_current_plan_index=1)));
	int passengers_on_board <- 0 update: BusVehicle sum_of(length(each.bv_passengers));
	int arrived_people_to_dest <- 0 update: BusStop sum_of(length(each.bs_arrived_people));
	
	int finished_1L_journeys <- 0 update: length(Individual where (each.ind_arrived and length(each.ind_actual_journey) = 1));
	int finished_2L_journeys <- 0 update: length(Individual where (each.ind_arrived and length(each.ind_actual_journey) = 2));
	
	float mean_travel_time_1L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_actual_journey) = 1)
						mean_of (each.ind_times[0][2] - each.ind_times[0][1]);
	float mean_travel_time_2L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_actual_journey) = 2)
						mean_of ( (each.ind_times[0][2] - each.ind_times[0][1]) + (each.ind_times[1][2] - each.ind_times[1][1]) );
	
	float mean_waiting_time_1L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_actual_journey) = 1)
						mean_of (each.ind_times[0][1] - each.ind_times[0][0]);
	float mean_waiting_time_2L <- 0.0 update: Individual where (each.ind_arrived and length(each.ind_actual_journey) = 2)
						mean_of ( (each.ind_times[0][1] - each.ind_times[0][0]) + (each.ind_times[1][1] - each.ind_times[1][0]) );
	
	/*******************************************************************************************************************************/
	
	/*******************************/
	/******** Initialization *******/
	/*****************************/
	init {
		
			
	
		write "--+-- START OF INIT --+--" color: #green;
		
		if !save_data_on { // warn when save data is off
			bool data_off_ok <- user_confirm("Confirm","Data saving is off. Do you want to proceed ?");
			if !data_off_ok {
				do die;
			}
		} else {
			sim_id <- machine_time;
			save 'traffic_on = ' + traffic_on + '\n' +
					'transfer_on = ' + transfer_on + '\n' + 
					'time_tables_on = ' + time_tables_on
				format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/params.txt";
			
			save "cycle,pduzone,w_people,w_time,bus_del,traf_del,pass_del,sign_del" 
					format: 'text' rewrite: true to: "../outputs/data_"+sim_id+"/pduzones.csv";
			save "cycle,waiting1st,waiting2nd,onboard,arrived" 
					format: 'text' rewrite: true to: "../outputs/data_"+sim_id+"/individuals.csv";
			save "cycle,tt1l,tt2l,wt1l,wt2l"
					format: 'text' rewrite: true to: "../outputs/data_"+sim_id+"/times.csv";
			save "cycle,bl,outs,rets,outs_board,rets_board,traff,sign,psg"
					format: 'text' rewrite: true to: "../outputs/data_"+sim_id+"/buslines.csv";
			save "cycle,ind,origin,destin,bttype,bl,dir,dist,walk,wait,board,arrival"
					format: 'text' rewrite: true to: "../outputs/data_"+sim_id+"/bustrips.csv";
			save "cycle,bv,bl,capa,bs,zone"
					format: 'text' rewrite: true to: "../outputs/data_"+sim_id+"/full_bus_vehicles.csv";
		}

		
		// create the environment: city, districts, roads, traffic signals
		write "Creating the city environment ...";
		create District from: marrakesh_districts with: [dist_code::int(get("ID")), dist_name::get("NAME")];
		create Building from: marrakesh_buildings;
		create PDUZone from: marrakesh_pdu with: [pduz_code::int(get("id")), pduz_name::get("label")];
		create RoadSegment from: marrakesh_roads with: [rs_id::int(get("segm_id"))]{
			rs_zone <- first(PDUZone overlapping self);
			rs_in_city <- rs_zone != nil;
		}
		road_network <- as_edge_graph(list(RoadSegment));
		//-----------
		write "Creating Grand Taxi Roads";
		create TaxiRoad from: marrakesh_GrandTaxis_roads with: [trs_id::int(get("id"))]{
		trs_zone <- first(PDUZone overlapping self);
			trs_in_city <- trs_in_city != nil;
		
		
//			loop i from: 0 to: trs_id{
//				int tn_vehicule <- TL_DEFAULT_NUMBER_OF_VEHICLES;
//				create TaxiVehicle {
//						tv_line <- myself;				
//						
//				}
//				
//			}
		}
		taxi_road_network <- as_edge_graph(list(TaxiRoad));
//		{
//			location <- any_location_in (one_of (Taxi_road));
//		}
		//road_network <- as_edge_graph(list(Taxi_road));		
				
		//----------------		
		// creating traffic stops and traffic lights
		create TrafficSignal from: marrakesh_traffic_signals with: [ts_type::get("fclass") = "stop" ? TRAFFIC_STOP_SIGN:TRAFFIC_LIGHT] {
			//the closest road to the traffic signal
			ts_rd_segment <- RoadSegment closest_to self;
			// garantir que le traffic signal est sur une route (touche le polyline de la route)
			location <- ts_rd_segment.shape.points closest_to self;
			ts_rd_segment.rs_traffic_signals <+ self; // this is equivalent to: "add self to: rd.traffic_signals"
		}
		
		// create busses, bus stops, and connections
		write "Creating busses and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [bs_id::int(get("stop_numbe")), bs_name::get("stop_name"),bs_is_brt::int(get("BRT")) = 1]{
			bs_rd_segment <- RoadSegment closest_to self;
			//write "bs_rd_segment"+bs_rd_segment;
			location <- bs_rd_segment.shape.points closest_to self; // to draw the bus stop on a road (accessible to bus)
			bs_district <- first(District overlapping self);
			bs_zone <- first(PDUZone overlapping self);
		}
		
		
		// create taxi stations
		write "Creating taxi stations ...";
		create TaxiStations from: marrakesh_GrandTaxis_stations with: [taxi_station_id::int(get("id")), taxi_station_name::get("nom"),taxi_station_direction::int(get("vertex_par"))]{
//			taxi_rd_segment <- TaxiRoadSegment closest_to(self);
//			write "taxi_rd_segment: "+TaxiRoadSegment closest_to self;
//			location <- taxi_rd_segment.shape.points closest_to self; // to draw the taxi stop on a road (accessible to taxi)
			//write "location"+location;
//			ts_district <- first(District overlapping self);
//			ts_zone <- first(PDUZone overlapping self);
		    taxi_rd_segment <- TaxiRoad closest_to self;
			write "taxi_rd_segment"+taxi_rd_segment;
			location <- taxi_rd_segment.shape.points closest_to self; // to draw the bus stop on a road (accessible to bus)
			ts_district <- first(District overlapping self);
			ts_zone <- first(PDUZone overlapping self);

		}
		

		//--------------
				matrix TaxidataMatrix <- matrix(csv_file("../includes/csv/grand_taxi_lines/Taxi_Stations.csv",true));
		loop i from: 0 to: TaxidataMatrix.rows -1 {
		//	write "TaxidataMatrix.rows: "+TaxidataMatrix.rows;
			//write "TaxidataMatrix: "+TaxidataMatrix;
			string taxi_line_name <- TaxidataMatrix[0,i];
			//write "taxi_line_name: "+taxi_line_name;
			
				// create the taxi line if it does not exist yet
				
				//write "taxi_line_name"+taxi_line_name;
				TaxiLine current_tl <- first(TaxiLine where (each.tl_name = taxi_line_name));
				//write "current_tl"+current_tl;
				if current_tl = nil {
					create TaxiLine returns: my_taxiline { tl_name <- taxi_line_name; }
					current_tl <- my_taxiline[0];
					//write "current_tl :"+current_tl;
				}
				TaxiStations current_ts <- TaxiStations first_with (each.taxi_station_id = int(TaxidataMatrix[3,i]));
				//write "current_ts"+current_ts+"int(TaxidataMatrix[3,i])"+int(TaxidataMatrix[3,i]);
				if current_ts != nil {
					if int(TaxidataMatrix[2,i]) = TL_DIRECTION_OUTGOING {
					current_tl.tl_outgoing_ts <+ current_ts;
						if length(current_tl.tl_outgoing_ts) != int(TaxidataMatrix[3,i]) {
							//write "length(current_tl.tl_outgoing_ts)"+current_tl.tl_outgoing_ts;
							//write "int(TaxidataMatrix[3,i]"+int(TaxidataMatrix[3,i]);
							write "Error in order of Taxi stations Outgoing!" color: #red;
						}
						//current_tl.tl_outgoing_ts <+ current_ts;
						//write "current_tl.tl_outgoing_ts"+current_tl.tl_outgoing_ts;
					} else {
						//write "length(current_tl.tl_return_ts)"+length(current_tl.tl_return_ts);
						//write "int(TaxidataMatrix[3,i]"+int(TaxidataMatrix[3,i]);
						current_tl.tl_return_ts <+ current_ts;
						//write "current_tl.tl_return_ts "+current_tl.tl_return_ts ;
						//write "param : "+length(current_tl.tl_return_ts)+"param 2:"+length(TaxidataMatrix[3,i]);
						if length(current_tl.tl_return_ts) != length(TaxidataMatrix[3,i]) {
							write "Error in order of taxi stations returns!" color: #red;
						}
						
					}
					// add the TL once only if the stop is in outgoing and return
					if !(current_ts.t_lines contains current_tl) {
						current_ts.t_lines <+ current_tl;
					}
				} else {
					write "Error, the taxi stations does not exist : " + TaxidataMatrix[1,i] + " (" + TaxidataMatrix[2,i] +")" color: #red;
					//return;
				}	
			
		}
		
		
		
		
		//----------------
		
		matrix dataMatrix <- matrix(csv_file("../includes/csv/bus_lines/bus_lines_stops.csv",true));
		loop i from: 0 to: dataMatrix.rows -1 { // CL
			string bus_line_name <- dataMatrix[0,i];
			//write "bus_line_name:"+bus_line_name;
			if !(bus_line_name in ["L40","L41","L332","L19","BRT1"]) { 
				// create the bus line if it does not exist yet
				
				BusLine current_bl <- first(BusLine where (each.bl_name = bus_line_name));
				//write "current_bl"+current_bl;
				if current_bl = nil {
					create BusLine returns: my_busline {
						bl_name <- bus_line_name;
					}
					current_bl <- my_busline[0];
					
				}
				BusStop current_bs <- BusStop first_with (each.bs_id = int(dataMatrix[3,i]));
				//write "current_bs"+current_bs;
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
		}
		//---------------------
				 
	
		ask TaxiLine {

			first(tl_outgoing_ts).ts_depart_or_terminus <- true;
			last(tl_outgoing_ts).ts_depart_or_terminus <- true;
			first(tl_return_ts).ts_depart_or_terminus <- true;
			last(tl_return_ts).ts_depart_or_terminus <- true;
		}

		
		
		
		
		//-----------------------
		// calculate distances of each bus line
		geometry geom;
		ask BusLine {
			loop i from: 0 to: length(bl_outgoing_bs) - 2 {
				try {
					geom <- path_between(road_network, bl_outgoing_bs[i], bl_outgoing_bs[i+1]).shape;
				} catch {
					write "Line "+bl_name + " (OUTGOING): road segment is nil between " +  bl_outgoing_bs[i].bs_name + " :: " + bl_outgoing_bs[i+1].bs_name color:#red;
					geom <- path_to(bl_outgoing_bs[i], bl_outgoing_bs[i+1]).shape;
				}
				bl_outgoing_dists <+ geom.perimeter;
				bl_shape <- bl_shape + geom;
			}
			
			loop i from: 0 to: length(bl_return_bs) - 2 {
				try {
					geom <- path_between(road_network, bl_return_bs[i], bl_return_bs[i+1]).shape;
				} catch {
					write "Line "+ bl_name + " (RETURN): road segment is nil between " +  bl_return_bs[i].bs_name + " :: " + bl_return_bs[i+1].bs_name color:#red;
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
			bs_neighbors <- (BusStop where (each.bs_zone != nil and each distance_to self <= BS_NEIGHBORING_DISTANCE)) sort_by (each distance_to self); 
		}
				
		/*****/
		//-------------------------------
//				// creating n_vehicles for each bus line
		write "Creating grand taxi vehicles ...";
		dataMatrix <- matrix(csv_file("../includes/csv/grand_taxi_lines/taxi_lines_data.csv",true));
		ask TaxiLine {
			int n_vehicles <- TL_DEFAULT_NUMBER_OF_VEHICLES;
			//write "dataMatrix index_of tl_name"+dataMatrix index_of tl_name;
//			if dataMatrix index_of tl_name != nil {
//				n_vehicles <- int(dataMatrix[1, int((dataMatrix index_of bl_name).y)]);
//				bl_interval_time_m <- float(dataMatrix[4, int((dataMatrix index_of bl_name).y)]) #minute;
//				//bl_com_speed <- float(dataMatrix[7, int((dataMatrix index_of bl_name).y)]) #km/#h;
//				n_large_vehicles <- int(dataMatrix[8, int((dataMatrix index_of bl_name).y)]);
//				bl_is_brt <- int(dataMatrix[9, int((dataMatrix index_of bl_name).y)]) = 1;
//			}
//			if !bl_is_brt or use_brt_lines { 
//				loop i from: 0 to: (n_vehicles/2)-1 {
//					create BusVehicle {
//						bv_line <- myself;				
//						bv_current_bs <- bv_line.bl_outgoing_bs[0];
//						bv_current_bs.bs_current_stopping_buses <+ self;
//						bv_next_bs <- bv_current_bs;
//						bv_current_direction <- BL_DIRECTION_OUTGOING;
//						location <- bv_current_bs.location;
//						bv_stop_wait_time <- (bv_line.bl_interval_time_m * i); // next vehicles have a waiting time
//					}
////					create TaxiVehicle {
////						tv_line <- myself;				
////						
////					}
//				}
//				loop i from: 0 to: (n_vehicles/2)-1 {
//					create BusVehicle {
//						bv_line <- myself;				
//						bv_current_bs <- bv_line.bl_return_bs[0];
//						bv_current_bs.bs_current_stopping_buses <+ self;
//						bv_next_bs <- bv_current_bs;
//						bv_current_direction <- BL_DIRECTION_RETURN;
//						location <- bv_current_bs.location;
//						bv_stop_wait_time <- (bv_line.bl_interval_time_m * i); // next vehicles have a waiting time
//					}	
////					create TaxiVehicle {
////						tv_line <- myself;				
////						
////					}
//				}
//			}
//			ask n_large_vehicles among BusVehicle where (each.bv_line = self) {
//				bv_capacity <- BV_CAPACITY_LARGE;
//			}
		}
		
		
		
		//---------------------------------

		// creating n_vehicles for each bus line
		write "Creating bus vehicles ...";
		dataMatrix <- matrix(csv_file("../includes/csv/bus_lines/bus_lines_data.csv",true));
		ask BusLine {
			int n_vehicles <- BL_DEFAULT_NUMBER_OF_VEHICLES;
			int n_large_vehicles <- 0;
			
			if dataMatrix index_of bl_name != nil {
				n_vehicles <- int(dataMatrix[1, int((dataMatrix index_of bl_name).y)]);
				bl_interval_time_m <- float(dataMatrix[4, int((dataMatrix index_of bl_name).y)]) #minute;
				//bl_com_speed <- float(dataMatrix[7, int((dataMatrix index_of bl_name).y)]) #km/#h;
				n_large_vehicles <- int(dataMatrix[8, int((dataMatrix index_of bl_name).y)]);
				bl_is_brt <- int(dataMatrix[9, int((dataMatrix index_of bl_name).y)]) = 1;
			}
			if !bl_is_brt or use_brt_lines { 
				loop i from: 0 to: (n_vehicles/2)-1 {
					create BusVehicle {
						bv_line <- myself;				
						bv_current_bs <- bv_line.bl_outgoing_bs[0];
						bv_current_bs.bs_current_stopping_buses <+ self;
						bv_next_bs <- bv_current_bs;
						bv_current_direction <- BL_DIRECTION_OUTGOING;
						location <- bv_current_bs.location;
						bv_stop_wait_time <- (bv_line.bl_interval_time_m * i); // next vehicles have a waiting time
					}
//					create TaxiVehicle {
//						tv_line <- myself;				
//						
//					}
				}
				loop i from: 0 to: (n_vehicles/2)-1 {
					create BusVehicle {
						bv_line <- myself;				
						bv_current_bs <- bv_line.bl_return_bs[0];
						bv_current_bs.bs_current_stopping_buses <+ self;
						bv_next_bs <- bv_current_bs;
						bv_current_direction <- BL_DIRECTION_RETURN;
						location <- bv_current_bs.location;
						bv_stop_wait_time <- (bv_line.bl_interval_time_m * i); // next vehicles have a waiting time
					}	
//					create TaxiVehicle {
//						tv_line <- myself;				
//						
//					}
				}
			}
			ask n_large_vehicles among BusVehicle where (each.bv_line = self) {
				bv_capacity <- BV_CAPACITY_LARGE;
			}
		}
		
		// create the population of moving individuals between PUDZones
		/*write "Creating population ...";
		dataMatrix <- matrix(csv_file("../includes/csv/population/populations_5000.csv",true));
		loop i from: 0 to: dataMatrix.rows -1 {
			create Individual {
				ind_id <- int(dataMatrix[0,i]);
				ind_origin_zone <- PDUZone first_with (each.pduz_code = int(dataMatrix[1,i]));
				ind_destin_zone <- PDUZone first_with (each.pduz_code = int(dataMatrix[2,i]));
				ind_origin_bs <- BusStop first_with (each.bs_id = int(dataMatrix[3,i]));
				ind_destin_bs <- BusStop first_with (each.bs_id = int(dataMatrix[4,i]));					
			}
		}
		
		write "Creating travel plans ...";
		dataMatrix <- matrix(csv_file("../includes/csv/population/travel_plans_5000.csv",true));
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
				bt_bus_line <- BusLine first_with (each.bl_name = string(dataMatrix[3,i]));
				bt_end_bs <- BusStop first_with (each.bs_id = int(dataMatrix[4,i]));
				bt_bus_direction <- int(dataMatrix[5,i]);
				bt_bus_distance <- int(dataMatrix[6,i]);
				bt_walk_distance <- int(dataMatrix[7,i]);
				indiv_x.ind_available_bt <+ self;	
			}
		}
		*/		
		write "Total population: " + length(Individual);
		write "--+-- END OF INIT --+--" color:#green;
	}
	
	/*** end of init definition ***/
	
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
	
	int Nminutes <- 10; // Nminutes has to be a divider of 1hour to allow updating traffic levels (a file for each hour)
	
	// update road traffic and/or generate travellers each X minutes
	reflex going_on when: int(time) mod int(Nminutes#minute) = 0 {
		
		int tt <- int(SIM_START_HOUR) + int(time);
		string hh <- get_time_frag(tt, 1);
		
		if int(hh) = 24 { // midight, end of a day simulation
			do pause;
		}
		
		// Each hour, the traffic levels of roads are updated
		if int(time) mod int(1#hour) = 0 {
			if int(hh) >= 6 and int(hh) <= 23 { // 06:00 - 23:00 range only
				current_affluence <- h_affluence[int(hh)];
				if traffic_on {
					matrix rd_traff_data <- matrix(csv_file("../includes/csv/roads_traffic/" + hh + ".csv",true));
					ask RoadSegment where (each.rs_in_city) {
						rs_traffic_level <- min([int(rd_traff_data[1,rs_id]), G_TRAFF_LEVEL_MAX]);
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
		
		// remove people that waited enough
		ask BusStop accumulate each.bs_waiting_people where ( 
				(each.ind_current_plan_index = 0 and int(time - each.ind_times[0][0]) >= IND_MAX_WAITING_TIME) or
				(each.ind_current_plan_index = 1 and int(time - each.ind_times[1][0]) >= IND_MAX_WAITING_TIME)) {
			
			ind_times[ind_current_plan_index] <+ int(time); // time when left
			ind_left <- true;
			ind_moving <- false;
			ind_waiting_bs.bs_waiting_people >- self;
			unsaved_arrivals <+ self;	
		}
		
		// ask a random number of people (N%) to travel 
		int nn <- int(current_affluence / (60/Nminutes) * length(Individual));
		if nn > 0 {
			write formatted_time() + nn + " new people are travelling ...";
			ask nn among (Individual where !(each.ind_moving or each.ind_arrived or each.ind_left)) {
				ind_moving <- true;
				ind_waiting_bs <- ind_origin_bs;
				ind_waiting_bs.bs_waiting_people <+ self;
				ind_times <+ [int(time)]; // waiting time, first trip
			}	
		}
		write formatted_time()  + "Total people waiting at bus stops : " + BusStop sum_of length(each.bs_waiting_people) color: #purple;
		
		// update colors of zones
		write "Updating the colors of PDU zones ..";
		ask PDUZone {
			list<int> indicators <- update_color(); // waiting times and people
			if save_data_on {
				save '' + cycle + ',' + pduz_code + ',' + indicators[0] + ',' + indicators[1] + ',' + indicators[2] + ',' +
					pduz_accumulated_traffic_delay + ',' + pduz_accumulated_passaging_delay + ',' + pduz_accumulated_signs_delay 
									format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/pduzones.csv";
			}
		}
		
		// save data if it is on
		if save_data_on {
			save '' + cycle + ',' + waiting_people_for_1st + ',' + waiting_people_for_2nd + ',' +
				passengers_on_board + ',' + arrived_people_to_dest
					format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/individuals.csv";
					
			save '' + cycle + ',' + mean_travel_time_1L + ',' + mean_travel_time_2L + ',' + 
					mean_waiting_time_1L + ',' + mean_waiting_time_2L
					format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/times.csv";
						
			ask BusLine {
				list<BusVehicle> bvs <- BusVehicle where (each.bv_line = self);
				list<BusVehicle> outs <- bvs where (each.bv_current_direction = BL_DIRECTION_OUTGOING);
				list<BusVehicle> rets <- bvs where (each.bv_current_direction = BL_DIRECTION_RETURN);
				
				save '' + cycle + ',' + bl_name + ',' + length(outs) + ',' + length(rets) + ',' +
					outs sum_of length(each.bv_passengers) + ',' + rets sum_of length(each.bv_passengers) + ',' +
					bvs sum_of (each.bv_accumulated_traffic_delay) + ',' +
					bvs sum_of (each.bv_accumulated_signs_delay) + ',' +
					bvs sum_of (each.bv_accumulated_passaging_delay)
						format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/buslines.csv";
			}
			
			ask unsaved_arrivals {
				if !empty(ind_actual_journey) {
					loop i from: 0 to: length(ind_actual_journey) - 1 {
						int startzone <- ind_actual_journey[i].bt_start_bs.bs_zone.pduz_code;
						int endzone <- ind_actual_journey[i].bt_end_bs.bs_zone.pduz_code;
	
						save '' + cycle + ',' + ind_id + ',' + startzone + ',' + endzone + ',' + 
								ind_actual_journey[i].bt_type + ',' + ind_actual_journey[i].bt_bus_line.bl_name + ',' +
								ind_actual_journey[i].bt_bus_direction + ',' + ind_actual_journey[i].bt_bus_distance + ',' +
								ind_actual_journey[i].bt_walk_distance + ',' + 
								ind_times[i][0] + ',' + ind_times[i][1] + ',' + ind_times[i][2]
							format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/bustrips.csv";		
					}	
				}
				if ind_left {
					save '' + cycle + ',' + ind_id + ',' + ind_waiting_bs.bs_zone.pduz_code + ',' + -1 + ',' + 
							-1 + ',' + -1 + ',' + -1 + ',' + -1 + ',' + -1 + ',' + 
							ind_times[ind_current_plan_index][0] + ',' + ind_times[ind_current_plan_index][1] + ',' + -1
						format: "text" rewrite: false to: "../outputs/data_"+sim_id+"/bustrips.csv";
					ind_waiting_bs <- nil;
				}
			}
			unsaved_arrivals <- [];
		}
	}
	
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
}
//species Taxi_road  {
//	rgb color <- #orange ;
//	aspect base {
//		draw shape color: color ;
//	}
//}
experiment MarraSIM type: gui {
	
	category "Simulation" expanded: false color: #gamablue; 
	category "Road Traffic" expanded: false color: #orange; 
	category "Bus network" expanded: true color: #purple; 
	
	parameter "Show Bus Lines" category:"Simulation" var: show_buslines;
	parameter "Show BRT Lines" category:"Simulation" var: show_brt_lines;
	text "Save data parameter is " + save_data_on category:"Simulation" color: #darkred font: font("Tahoma",10,#bold);
	parameter "Use Google Traffic" category:"Road Traffic" var: traffic_on;
	text "Max traffic level is " + G_TRAFF_LEVEL_MAX category:"Road Traffic" color: #darkred font: font("Tahoma",10,#bold);
	parameter "Free Transfer" category:"Bus network" var: transfer_on;
	parameter "Time tables" category:"Bus network" var: time_tables_on;
	text "Use BRT parameter is " + use_brt_lines category:"Bus network" color: #darkred font: font("Tahoma",10,#bold);
	
	init {
		minimum_cycle_duration <- 0.0;
	}
	
	output {
				 
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
			species TaxiVehicle;
			species TaxiRoad;
			species TaxiStations  ;
		}
		//----------------------------------------------------------------------------------------------------------------//
		display "Total Waiting People" type: opengl background: #whitesmoke{
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
		//----------------------------------------------------------------------------------------------------------------//
		display "Mean Waiting Time" type: opengl background: #whitesmoke {
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
		//----------------------------------------------------------------------------------------------------------------//
		display "Mean Bus Delays" type: opengl background: #whitesmoke {
			camera 'default' location: {76609.6582,72520.8497,25375.9837} target: {76609.6582,72520.4068,0.0};
			
			overlay position: {1,0.01} size: {140#px,140#px} background: #gray{
	        	draw "Bus delay (m)" at: {20#px, 15#px} font: AFONT0 color: #white;
	        	
	        	 loop i from: 0 to: length(PDUZ_WT_THRESHOLDS)-1 {
                    draw square(10#px) at: {20#px,(30+(15*i))#px} color: PDUZ_COLORS[i];
                    draw '<' + int(PDUZ_WT_THRESHOLDS[i]/60) at: {40#px,(33+(15*i))#px} color: #yellow font: AFONT0;
                }
                draw square(10#px) at: {20#px,(30+(15*length(PDUZ_WT_THRESHOLDS)))#px} color: last(PDUZ_COLORS);
                draw '>' + int(last(PDUZ_WT_THRESHOLDS)/60) at: {40#px,(33+(15*length(PDUZ_WT_THRESHOLDS)))#px} color: #yellow font: AFONT0;
	        }
	        
			species PDUZone aspect: bus_delay;
		}
		//----------------------------------------------------------------------------------------------------------------//
		display Mobility type: java2D background: #whitesmoke {
			chart "Number of Travellers" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0,0} x_label: "Time" {
				data "1st wait" color: #red value: waiting_people_for_1st marker_shape: marker_empty;
				data "Transfer wait" color: #darkred value: waiting_people_for_2nd marker_shape: marker_empty;
				data "On bus" color: #green value: passengers_on_board marker_shape: marker_empty;
				data "Arrived" color: #blue value: arrived_people_to_dest marker_shape: marker_empty;
			}
			chart "Number of Finished Journeys" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0.5,0} x_label: "Time" {
				data "1-Line" color: #darkgreen value: finished_1L_journeys marker_shape: marker_empty;
				data "2-Lines" color: #darkred value: finished_2L_journeys marker_shape: marker_empty;
			}
			chart "Mean Travelling Time (m)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0,0.34} x_label: "Time" {
				data "Finished 1-L" color: #darkgreen value: mean_travel_time_1L/1#minute marker_shape: marker_empty;
				data "Finished 2-L" color: #darkred value: mean_travel_time_2L/1#minute marker_shape: marker_empty;
			}
			chart "Mean Waiting Time at Bus Stops (m)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0.5,0.34} x_label: "Time" {
				data "Finished 1-L" color: #darkgreen value: mean_waiting_time_1L/1#minute marker_shape: marker_empty;
				data "Finished 2-L" color: #darkred value: mean_waiting_time_2L/1#minute marker_shape: marker_empty;
			}
			chart "Mean Accumulated Delay (m)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0,0.67} x_label: "Time" {
				data "Road traffic" color: #darkred value: BusVehicle mean_of(each.bv_accumulated_traffic_delay)/1#minute marker_shape: marker_empty;
				data "Traffic signs" color: #darkblue value: BusVehicle mean_of(each.bv_accumulated_signs_delay)/1#minute marker_shape: marker_empty;
				data "Passengers" color: #darkviolet value: BusVehicle mean_of(each.bv_accumulated_passaging_delay)/1#minute marker_shape: marker_empty;
			}
			chart "Mean of Bus Speed (km/h)" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {0.5,0.33} position: {0.5,0.67} x_label: "Time" {
				data "Theoretical commercial speed" color: #darkgreen value: BusVehicle mean_of(each.bv_line.bl_com_speed) marker_shape: marker_empty;
				data "Actual simulation speed" color: #darkred value: BusVehicle mean_of(each.bv_actual_speed) marker_shape: marker_empty;
			}
		}
	}
}
