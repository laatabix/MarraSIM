/**
* Name: District
* Description: defines the District species and its related constantes and variables.
* 				A District agent represents one entity of the administrative division.
* 				In the case of Marrakesh, there are six districts: Mechouar-Kasbah, Annakhil, Guéliz, Médina, Menara, and SYBA.
* Author: Laatabi
*/

model District

global {
	// simulation starts at 06:00 morning
	float sim_start_hour <- 6#hour;
	
	// format the current time to a printable format [hh:mm:ss]
	string formatted_time { 
		int tt <- int(sim_start_hour) + int(time);
		return "[" + get_time_frag(tt, 1) + ":" + get_time_frag(tt, 2) + ":" + get_time_frag(tt, 3) + "] ";
	}
	
	// returns one fragment of a given time 
	string get_time_frag (int tt, int frag) {
		if frag = 1 { // hours
			return zero_time(int(tt / 3600));
		} else if frag = 2 { // minutes
			return zero_time(int((tt mod 3600) / 60));
		} else { // seconds
			return zero_time((tt mod 3600) mod 60);
		}
	}
	
	// adds a zero if it is only one digit (8 --> 08)
	string zero_time (int i) {
		return (i <= 9 ? "0" : "") + i;
	}		
}

species District schedules: [] {
	string dist_id;
	string dist_name;
	
	aspect default {
		draw shape color: #whitesmoke border: #gray;
	}
}