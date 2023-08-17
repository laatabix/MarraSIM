/**
* Name: PDUZone
* Description: defines the PDUZone species and its related constantes and variables.
* 				A PDUZone agent represents one entity of the PDU (Plan de déplacements urbains) 2009 division.
* Author: Laatabi
*/

model PDUZone

import "BusStop.gaml"

global {
	list<rgb> PDUZ_COLORS <- [#white,#yellow,#orange,#tomato,#red,#darkred,#black];
	list<int> PDUZ_WP_THRESHOLDS <- [10,50,100,200,400,750];
	list<float> PDUZ_WT_THRESHOLDS <- [5#mn,10#mn,15#mn,20#mn,25#mn,30#mn];
}

species PDUZone schedules: [] parallel: true {
	int zone_id;
	string zone_name;
	District zone_district;
	rgb zone_col <- #whitesmoke;
	rgb wp_col <- #white;
	rgb wt_col <- #white;
		
	aspect waiting_people {
		draw shape color: wp_col border: #black;
	}
	
	aspect waiting_time {
		draw shape color: wt_col border: #black;
	}
	
	action update_color {
		int wp <- BusStop where (each.bs_zone = self) sum_of(length(each.bs_waiting_people));
		wp_col <- wp < PDUZ_WP_THRESHOLDS[0] ? PDUZ_COLORS[0] : (wp < PDUZ_WP_THRESHOLDS[1] ? PDUZ_COLORS[1] :
			(wp < PDUZ_WP_THRESHOLDS[2] ? PDUZ_COLORS[2] : (wp < PDUZ_WP_THRESHOLDS[3] ? PDUZ_COLORS[3] : 
				(wp < PDUZ_WP_THRESHOLDS[4] ? PDUZ_COLORS[4] : (wp < PDUZ_WP_THRESHOLDS[5] ? PDUZ_COLORS[5] : PDUZ_COLORS[6])))));
		
		int wt <- int(mean(BusStop where (each.bs_zone = self) accumulate (each.bs_waiting_people accumulate each.ind_waiting_time)));
		wt_col <- wt < PDUZ_WT_THRESHOLDS[0] ? PDUZ_COLORS[0] : (wt < PDUZ_WT_THRESHOLDS[1] ? PDUZ_COLORS[1] :
			(wt < PDUZ_WT_THRESHOLDS[2] ? PDUZ_COLORS[2] : (wt < PDUZ_WT_THRESHOLDS[3] ? PDUZ_COLORS[3] :
				(wt < PDUZ_WT_THRESHOLDS[4] ? PDUZ_COLORS[4] : (wt < PDUZ_WT_THRESHOLDS[5] ? PDUZ_COLORS[5] : PDUZ_COLORS[6])))));
	}
}