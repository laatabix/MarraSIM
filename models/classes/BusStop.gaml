/**
* Name: BusStop
* Description: defines the BusStop species and its related constantes and variables.
* 				A BusStop agent one location where buses can take or drop off people.
* Author: Laatabi
*/

model BusStop

import "BusVehicle.gaml"
import "District.gaml"

global {
	// All bus stops around this distance can be used to take/leave a bus or transfer between busses
	float BS_NEIGHBORING_DISTANCE <- 500#m;
}

species BusStop schedules: [] parallel: true{
	int bs_id;
	string bs_name;
	list<BusLine> bs_bus_lines;
	list<BusVehicle> bs_current_stopping_buses;
	District bs_district;
	PDUZone bs_zone;
	RoadSegment bs_rd_segment;
	list<Individual> bs_waiting_people <- [];
	list<Individual> bs_arrived_people <- [];
	list<BusStop> bs_neighbors <- []; // bus stops at a distance of 400m
	bool depart_or_terminus <- false;

	//calculate distance between two bus stops
	int dist_to_bs (BusStop bs2) {
		try {
			return int(path_between(road_network, self, bs2).shape.perimeter);
		} catch {
			return self.location = bs2.location ? 0 : #max_int;
		}
	}
	
	aspect default {
		if !(show_buslines and depart_or_terminus) {
			draw square(30#meter) color: #gamablue;
			draw square(15#meter) color: #gold;
		}	
	}
}
