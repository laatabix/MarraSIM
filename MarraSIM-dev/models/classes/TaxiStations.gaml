/**
* Name: BusStop
* Description: defines the BusStop species and its related constantes, variables, and methods.
* 				A BusStop agent represents a location where buses can take or drop off people.
* Authors: Laatabi
* For the i-Maroc project.
*/

model TaxiStations

import "TaxiVehicle.gaml"
import "District.gaml"

global {

}

/*******************************/
/******* TaxiStaions Species ******/
/*****************************/

species TaxiStations schedules: [] parallel: true{
	int taxi_station_id;
	int taxi_station_direction;
	string taxi_station_name;
	bool ts_depart_or_terminus <- false;
	TaxiRoadSegment taxi_rd_segment;

	District ts_district;
	PDUZone ts_zone;
	
	
	list<TaxiLine> t_lines <- []; // list of taxi lines using the taxi station
	
	list<TaxiVehicle> t_current_stopping_taxis; // list of current taxis that are stopping at the taxi station
	
	
	
	
	
	aspect default {
		if !( ts_depart_or_terminus) {
			draw square(90#meter) color: #orange;
			
		}	
	}
}

/*** end of species definition ***/