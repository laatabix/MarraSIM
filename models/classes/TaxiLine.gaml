/**
* Name: BusLine
* Description: defines the BusLine species and its related constantes, variables, and methods.
* 				A BusLine agent represents an outgoing-return path of a bus.
* Authors: Laatabi
* For the i-Maroc project.
*/

model TaxiLine


import "TaxiVehicle.gaml"

global {
	// the default number of vehicles in each line
	int TL_DEFAULT_NUMBER_OF_VEHICLES <- 20;
	//the default interva time between vehicles
	float TL_DEFAULT_INTERVAL_TIME <- rnd(10.0,40.0);
	
	int TL_DIRECTION_OUTGOING <- 1;
	int TL_DIRECTION_RETURN <- 2;

}

/*******************************/
/******* TaxiLine Species ******/
/*****************************/

species TaxiLine schedules: [] parallel: true {
     string tl_name;
	float Tl_interval_time_m <- TL_DEFAULT_INTERVAL_TIME; // theoretical interval time between taxis of the line
	float tl_com_speed <- TV_URBAN_SPEED; // average speed while considering the traffic constraints
	list<TaxiStations> tl_outgoing_ts <- []; // list of taxi stops on an outgoing path
	list<TaxiStations> tl_return_ts <- []; // taxi stops on the return path
	rgb tl_color <- #yellow;
	geometry tl_shape;
	


	

	

	
	
	aspect default {
		if (show_Taxilines =true) {
			draw (tl_shape+7.5#meter) color: tl_color;
			
		}
	}
	
}



/*** end of species definition ***/
