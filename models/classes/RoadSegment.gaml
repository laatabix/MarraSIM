/**
* Name: RoadSegment
* Description: defines the RoadSegment species and its related constantes, variables, and methods.
* 				A RoadSegment agent represents one segment of the road network.
* Authors: Laatabi
* For the i-Maroc project.
*/

model RoadSegment

import "BusLine.gaml"

global {
	
	// the four traffic levels of Google Traffic 
	int G_TRAFF_LEVEL_GREEN <- 1;
	int G_TRAFF_LEVEL_ORANGE <- 2;
	int G_TRAFF_LEVEL_RED <- 3;
	int G_TRAFF_LEVEL_DARKRED <- 4;
	// the color of each traffic level
	list<rgb> G_TRAFF_COLORS <- [#transparent, #green, #orange, #red, #darkred]; // index 0 is unused
	
	// max allowed traffic level to simulate limiting congestion.
	int G_TRAFF_LEVEL_MAX <- G_TRAFF_LEVEL_DARKRED;
	
	// the road network of the city and its suburbs
	graph road_network;
}

/*******************************/
/***** RoadSegment Species ****/
/*****************************/

species RoadSegment schedules: [] parallel: true {
	int rs_id;
	rgb rs_col <- #green;
	PDUZone rs_zone <- nil;
	int rs_traffic_level <- G_TRAFF_LEVEL_GREEN; // current traffic level of the road segment
	bool rs_in_city <- true; // is it urban or suburban (only city roads are considered in Google Traffic data.
						    // Subrban roads have always a normal "green" traffic level).
	list<TrafficSignal> rs_traffic_signals <- []; // list of traffic signals located on the road segment
	
	aspect default {
		if !show_buslines {
			draw (shape+5#meter) color: rs_col;
		}
	}
}





/*** end of species definition ***/
