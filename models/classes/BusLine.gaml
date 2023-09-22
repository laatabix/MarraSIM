/**
* Name: BusLine
* Description: defines the BusLine species and its related constantes, variables, and methods.
* 				A BusLine agent represents an outgoing-return path of a bus.
* Authors: Laatabi
* For the i-Maroc project.
*/

model BusLine

import "BusConnection.gaml"

global {
	
	int BL_DIRECTION_OUTGOING <- 1;
	int BL_DIRECTION_RETURN <- 2;
	// colors to color bus lines when displayed
	list<rgb> BL_COLORS <- [#darkblue,#darkcyan,#darkgoldenrod,#darkgray,#darkkhaki,#darkmagenta,#darkolivegreen,#darkorchid,
								#darksalmon,#darkseagreen,#darkslateblue,#darkslategray,#darkturquoise,#darkviolet];
	// display or not buslines (instead of roads with traffic levels)
	bool show_buslines <- false;
	//font LFONT0 <- font("Arial", 5, #bold);
	
	// whether BRT lines are activated or not
	bool use_brt_lines <- false;
	bool show_brt_lines <- false; // display or not BRT lines
}

/*******************************/
/******* BusLine Species ******/
/*****************************/

species BusLine schedules: [] parallel: true {
	string bl_name;
	bool bl_is_brt <- false;
	int bl_interval_time_m <- -1; // theoretical interval time between buses of the line
	float bl_com_speed <- 30 #km/#h; // average speed while considering the traffic constraints
	list<BusStop> bl_outgoing_bs <- []; // list of bus stops on an outgoing path
	list<BusStop> bl_return_bs <- []; // bus stops on the return path
	list<int> bl_outgoing_dists <- []; // computed distances between two successive bus stops on the outoging path
	list<int> bl_return_dists <- []; // distances on the return path
	list<BusConnection> bl_outgoing_connections <- [];
	list<BusConnection> bl_return_connections <- [];
	rgb bl_color <- one_of(BL_COLORS);
	geometry bl_shape;
	
	// create a bus connection with the bus line passed in arguments
	action create_bc (BusStop bs1, int dir1, BusLine bl2, BusStop bs2, int dir2, int cd) {
		create BusConnection {
			bc_bus_lines <- [myself, bl2];
			bc_bus_stops <-[bs1,bs2];
			bc_bus_directions <- [dir1,dir2];
			bc_connection_distance <- cd = -1 ? bc_bus_stops[0].dist_to_bs(bc_bus_stops[1]) : cd;
			if dir1 = BL_DIRECTION_OUTGOING {
				myself.bl_outgoing_connections <+ self;
			} else {
				myself.bl_return_connections <+ self;
			}
			if dir2 = BL_DIRECTION_OUTGOING {
				bl2.bl_outgoing_connections <+ self;
			} else {
				bl2.bl_return_connections <+ self;
			}
		}
	}
	
	// test whether the line can link two bus stops or not
	int can_link_2bs (BusStop obs, BusStop dbs) {
		int o_ix <- bl_outgoing_bs index_of obs;
		int d_ix <- bl_outgoing_bs index_of dbs;
		
		if o_ix != -1 and d_ix != -1 and o_ix < d_ix {
			return BL_DIRECTION_OUTGOING;
		} else {
			o_ix <- bl_return_bs index_of obs;
			d_ix <- bl_return_bs index_of dbs;
			if o_ix != -1 and d_ix != -1 and o_ix < d_ix {
				return BL_DIRECTION_RETURN;
			}
		}
		return -1;
	}
	
	// return the previous bus stop given the direction and another bus stop
	BusStop previous_bs (int dir, BusStop bs) {
		if dir = BL_DIRECTION_OUTGOING {
			int indx <- bl_outgoing_bs index_of bs;
			return indx > 0 ? bl_outgoing_bs[indx-1] : nil;
		} else {
			int indx <- bl_return_bs index_of bs;
			return indx > 0 ? bl_return_bs[indx-1] : nil;
		}
	}
	
	// return the next bus stop given the direction and another bus stop
	BusStop next_bs (int dir, BusStop bs) {
		if dir = BL_DIRECTION_OUTGOING {
			int indx <- bl_outgoing_bs index_of bs;
			return indx < length(bl_outgoing_bs)-1 ? bl_outgoing_bs[indx+1] : nil;
		} else {
			int indx <- bl_return_bs index_of bs;
			return indx < length(bl_return_bs)-1 ? bl_return_bs[indx+1] : nil;
		}
	}
	
	aspect default {
		if (show_buslines and !bl_is_brt) or (bl_is_brt and show_brt_lines) {
			draw (bl_shape+7.5#meter) color: bl_color;
			draw circle(25#m) color: #white border:bl_color at: first(bl_outgoing_bs).location;
			//draw ""+bl_name color: bl_color anchor:#center font:LFONT0 at: first(bl_outgoing_bs).location;
			draw circle(25#m) color: #white border:bl_color at: last(bl_outgoing_bs).location;
			//draw ""+bl_name color: bl_color anchor:#center font:LFONT0 at: last(bl_outgoing_bs).location;
			draw circle(25#m) color: #white border:bl_color at: first(bl_return_bs).location;
			//draw ""+bl_name color: bl_color anchor:#center font:LFONT0 at: first(bl_return_bs).location;
			draw circle(25#m) color: #white border:bl_color at: last(bl_return_bs).location;
			//draw ""+bl_name color: bl_color anchor:#center font:LFONT0 at: last(bl_return_bs).location;	
		}
	}
}

/*** end of species definition ***/
