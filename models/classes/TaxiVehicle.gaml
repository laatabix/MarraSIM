/**
* Name: TaxiVehicle
* Description: defines the BusVehicle species and its related constantes, variables, and methods.
* 				A BusVehicle agent represents one vehicle that serves a bus line.
* Authors: Laatabi
* For the i-Maroc project.
*/

model TaxiVehicle
import "../Params.gaml"
import "Individual.gaml"
import "TrafficSignal.gaml"
import "BusTrip.gaml"
import "TaxiLine.gaml"
import "TaxiRoad.gaml"
import "TaxiStations.gaml"


global {
	
	// speed of taxis in the urban area
	float TV_URBAN_SPEED <- 60#km/#hour;
	// speed of taxis in the suburban area
	float TV_SUBURBAN_SPEED <- 80#km/#hour;
	
	// the mininmum time to take a passenger
	float TV_TIME_TAKE_IND <- 5#second;
	// the mininmum time to drop off a passenger
	float TV_TIME_DROP_IND <- 5#second;
	
	// max load of a taxi vehicle (all people that can get in) when crowded and cannot take more
	int TV_CAPACITY <- 6;
	
	
	// How to decrease vehicle speed based on traffic level [evey value corresponds to a traff level, 0 is unused]
	list<float> TV_SPEED_DIVIDER <- [0,1.0,2.0,3.0,4.0];
}

/*******************************/
/**** TaxiVehicle Species ******/
/*****************************/

species TaxiVehicle skills: [moving] {
	TaxiLine tv_line;
	int tv_current_direction;
	
	float tv_actual_speed;
	int tv_capacity <- TV_CAPACITY;
	float tv_stop_wait_time <- -1.0;
	bool tv_in_city <- true;
	bool tv_in_move <- false;
	 
	//image_file tv_icon <- image_file("../../includes/img/Gtaxi.jpeg");
	
	TrafficSignal Tv_current_traff_sign <- nil; // when the vehicle stops at a traffic signal
	TaxiRoad tv_current_rd_segment <- nil;
	TaxiStations tv_station<- nil;
	list<Individual> Tv_passengers <- [];
	
//		 reflex choose_path when: tv_current_rd_segment = nil {
//        tv_current_rd_segment <- any_location_in(one_of(TaxiRoadSegment));
//        
// 
//    }

	
	reflex drive when: tv_current_rd_segment != nil {
//		// if the taxi has to wait
//		if tv_stop_wait_time > 0 {
//			tv_stop_wait_time <- tv_stop_wait_time - step;
//			return;
//		}
//		// if the waiting time is over
//		if tv_stop_wait_time = 0 {
//			
//			tv_stop_wait_time <- -1.0;
//			tv_in_move <- true;
//		}
//		// the current road segment of the bus
		tv_current_rd_segment <- TaxiRoad(current_edge);
		
		
		
		if tv_current_rd_segment != nil {

			//tv_in_city <- tv_current_rd_segment.trs_in_city;
			// a taxi moves with the commercial speed inside Marrakesh, and TV_SUBURBAN_SPEED outside;
			if tv_in_city {
				
			
					tv_actual_speed <- TV_URBAN_SPEED;
				
			}
			// the bus is not in the city
			else {
				tv_actual_speed <- TV_SUBURBAN_SPEED;
			}	
		}
		// move
		do goto on: taxi_road_network target: any_location_in (one_of (TaxiRoad)) speed: tv_actual_speed;
	
	}
	
		aspect default {
		draw rectangle(100, 50)  color:#red ;
		
	}
	

	
	//

}

/*** end of species definition ***/