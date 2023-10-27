/**
* Name: BusStop
* Description: defines the BusStop species and its related constantes, variables, and methods.
* 				A BusStop agent represents a location where buses can take or drop off people.
* Authors: Laatabi
* For the i-Maroc project.
*/

model BusStop

import "BusVehicle.gaml"
import "District.gaml"

global {
	
	// All bus stops around this distance can be used to take/leave a bus or transfer between busses
	float BS_NEIGHBORING_DISTANCE <- 500#m;
}

/*******************************/
/******* BusStop Species ******/
/*****************************/

species BusStop schedules: [] parallel: true{
	int bs_id;
	string bs_name;
	bool bs_depart_or_terminus <- false;
	bool bs_is_brt <- false; // if the bus stop belongs to a BRT line
	list<BusStop> bs_neighbors <- []; // bus stops at a distance of BS_NEIGHBORING_DISTANCE
	District bs_district;
	PDUZone bs_zone;
	RoadSegment bs_rd_segment;
	
	list<BusLine> bs_bus_lines <- []; // list of bus lines using the bus stop
	list<Individual> bs_waiting_people <- []; // list of people currently waiting at the bus stop
	list<Individual> bs_arrived_people <- []; // list of people that ended their trips at the bus stop
	list<BusVehicle> bs_current_stopping_buses; // list of current busses that are stopping at the bus stop
	
	map<BusVehicle,float> bs_bv_delays <- [];
	
	//calculate distance between two bus stops
	int dist_to_bs (BusStop bs2) {
		try {
			return int(path_between(road_network, self, bs2).shape.perimeter);
		} catch {
			//write "Exception while computing distance between " + self.bs_name + " and " + bs2.bs_name color: #red;
			return self.location = bs2.location ? 0 : int(self distance_to bs2);
		}
	}
	
	aspect default {
		if !(show_buslines and bs_depart_or_terminus) {
			draw square(30#meter) color: #gamablue;
			draw square(15#meter) color: #gold;
		}	
	}
}

/*** end of species definition ***/