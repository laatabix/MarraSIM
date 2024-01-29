/**
* Name: TrafficSignal
* Description: defines the TrafficSignal species and its related constantes, variables, and methods.
* 				A TrafficSignal agent represents a traffic light or a stop sign.
* Authors: Laatabi
* For the i-Maroc project.
*/

model TrafficSignal

import "RoadSegment.gaml"

global {
	// types of a traffic signal
	int TRAFFIC_STOP_SIGN <- 0;
	int TRAFFIC_LIGHT <- 3;
	
	// time to stop at a stop sign or on red traffic light
	float TS_BUS_STOP_WAIT_TIME <- 30#second;
	float TS_BRT_STOP_WAIT_TIME <- 10#second;
	// probability to stop on a traffic light
	float TS_PROBA_STOP_TRAFF_LIGHT <- 0.5;
}

/*******************************/
/**** TrafficSignal Species ***/
/*****************************/

species TrafficSignal schedules: [] {
	
	int ts_type; // may be a traffic light or a stop sign
	RoadSegment ts_rd_segment; // the road segment where the traffic signal is located
	
	aspect default {
		draw square(10#meter) color: #orange border: #black;
	}
}

/*** end of species definition ***/
