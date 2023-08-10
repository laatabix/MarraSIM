/**
* Name: PDUZone
* Description: defines the PDUZone species and its related constantes and variables.
* 				A PDUZone agent represents one entity of the PDU (Plan de déplacements urbains) 2009 division.
* Author: Laatabi
*/

model PDUZone

import "BusStop.gaml"

species PDUZone schedules: [] parallel: true {
	int zone_id;
	string zone_name;
	District zone_district;
	rgb zone_col <- #whitesmoke;
	rgb wp_col <- #white;
	rgb wt_col <- #white;
	
	list<rgb> scale_colors <- [#white,#lightyellow,#yellow,#orange,#darkorange,#red,#darkred];
	list<int> wp_thresholds <- [10,50,100,200,400,750];
	list<float> wt_thresholds <- [5#mn,10#mn,15#mn,20#mn,25#mn,30#mn];
		
	aspect waiting_people {
		draw shape color: wp_col border: #black;
	}
	
	aspect waiting_time {
		draw shape color: wt_col border: #black;
	}
	
	action update_color {
		int wp <- BusStop where (each.bs_zone = self) sum_of(length(each.bs_waiting_people));
		wp_col <- wp < wp_thresholds[0] ? scale_colors[0] : (wp < wp_thresholds[1] ? scale_colors[1] :
			(wp < wp_thresholds[2] ? scale_colors[2] : (wp < wp_thresholds[3] ? scale_colors[3] : 
				(wp < wp_thresholds[4] ? scale_colors[4] : (wp < wp_thresholds[5] ? scale_colors[5] : scale_colors[6])))));
		
		int wt <- int(mean(BusStop where (each.bs_zone = self) accumulate (each.bs_waiting_people accumulate each.ind_waiting_time)));
		wt_col <- wt < wt_thresholds[0] ? scale_colors[0] : (wt < wt_thresholds[1] ? scale_colors[1] :
			(wt < wt_thresholds[2] ? scale_colors[2] : (wt < wt_thresholds[3] ? scale_colors[3] :
				(wt < wt_thresholds[4] ? scale_colors[4] : (wt < wt_thresholds[5] ? scale_colors[5] : scale_colors[6])))));
	}
}