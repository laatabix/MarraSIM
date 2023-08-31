/**
* Name: BusLine
* Description: defines the BusLine species and its related constantes and variables.
* 				A BusLine agent represents an outgoing-return path of a bus.
* Author: Laatabi
*/

model BusLine

import "BusConnection.gaml"

global {
	int BUS_DIRECTION_OUTGOING <- 1;
	int BUS_DIRECTION_RETURN <- 2;
	list<rgb> BL_COLORS <- [#darkblue,#darkcyan,#darkgoldenrod,#darkgray,#darkkhaki,#darkmagenta,#darkolivegreen,
				#darkorchid,#darksalmon,#darkseagreen,#darkslateblue,#darkslategray,#darkturquoise,#darkviolet];
	
	bool show_buslines <- false;
	//font LFONT0 <- font("Arial", 5, #bold);
}

species BusLine schedules: [] parallel: true {
	string bl_name;
	int bl_interval_time_m <- -1;
	float bl_comm_speed <- 30 #km/#h;
	list<BusStop> bl_outgoing_bs <- [];
	list<int> bl_outgoing_dists <- [];
	list<BusStop> bl_return_bs <- [];
	list<int> bl_return_dists <- [];
	list<BusConnection> bl_outgoing_connections <- [];
	list<BusConnection> bl_return_connections <- [];
	rgb bl_color <- one_of(BL_COLORS);
	geometry bl_shape;
	
	aspect default {
		if show_buslines {
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
	
	// create a BC from passed arguments
	action create_bc (BusStop bs1, int dir1, BusLine bl2, BusStop bs2, int dir2, int cd) {
		create BusConnection {
			bc_bus_lines <- [myself, bl2];
			bc_bus_stops <-[bs1,bs2];
			bc_bus_directions <- [dir1,dir2];
			bc_connection_distance <- cd = -1 ? bc_bus_stops[0].dist_to_bs(bc_bus_stops[1]) : cd;
			if dir1 = BUS_DIRECTION_OUTGOING {
				myself.bl_outgoing_connections <+ self;
			} else {
				myself.bl_return_connections <+ self;
			}
			if dir2 = BUS_DIRECTION_OUTGOING {
				bl2.bl_outgoing_connections <+ self;
			} else {
				bl2.bl_return_connections <+ self;
			}
		}
	}
		
	int can_link_2bs (BusStop obs, BusStop dbs) {
		int o_ix <- bl_outgoing_bs index_of obs;
		int d_ix <- bl_outgoing_bs index_of dbs;
		
		if o_ix != -1 and d_ix != -1 and o_ix < d_ix {
			return BUS_DIRECTION_OUTGOING;
		} else {
			o_ix <- bl_return_bs index_of obs;
			d_ix <- bl_return_bs index_of dbs;
			if o_ix != -1 and d_ix != -1 and o_ix < d_ix {
				return BUS_DIRECTION_RETURN;
			}
		}
		return -1;
	}
	
	BusStop previous_bs (int dir, BusStop bs) {
		if dir = BUS_DIRECTION_OUTGOING {
			int indx <- bl_outgoing_bs index_of bs;
			return indx > 0 ? bl_outgoing_bs[indx-1] : nil;
		} else {
			int indx <- bl_return_bs index_of bs;
			return indx > 0 ? bl_return_bs[indx-1] : nil;
		}
	}
	
	BusStop next_bs (int dir, BusStop bs) {
		if dir = BUS_DIRECTION_OUTGOING {
			int indx <- bl_outgoing_bs index_of bs;
			return indx < length(bl_outgoing_bs)-1 ? bl_outgoing_bs[indx+1] : nil;
		} else {
			int indx <- bl_return_bs index_of bs;
			return indx < length(bl_return_bs)-1 ? bl_return_bs[indx+1] : nil;
		}
	}
}

