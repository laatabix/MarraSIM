/**
* Name: TrafficSignal
* Description: defines the TrafficSignal species and its related constantes and variables.
* 				A TrafficSignal agent represents a traffic light or a stop sign.
* Author: Laatabi
*/

model TrafficSignal

import "RoadSegment.gaml"

global {
	int TRAFFIC_STOP_SIGN <- 0;
	int TRAFFIC_LIGHT <- 3;
}

species TrafficSignal schedules: [] {
	int ts_type; // may be a traffic light or a stop sign
	RoadSegment ts_rd_segment; // the road segment where the traffic signal is located
	
	aspect default {
		draw square(10#meter) color: #orange border: #black;
	}
}