/**
* Name: PDUZone
* Description: defines the PDUZone species and its related constantes, variables, and methods.
* 				A PDUZone agent represents one entity of the PDU (Plan de déplacements urbains) 2009 division.
* Authors: Laatabi
* For the i-Maroc project.
*/

model PDUZone

import "BusStop.gaml"

global {
	
	// colors of zones
	list<rgb> PDUZ_COLORS <- [#white,#yellow,#orange,#tomato,#red,#darkred,#black];
	
	// theresholds to color PDU zones depending on the number of waiting people on bus stops
	list<int> PDUZ_WP_THRESHOLDS <- [25,50,100,200,400,750];
	
	// theresholds to color PDU zones depending on the mean waiting time on bus stops
	list<float> PDUZ_WT_THRESHOLDS <- [15#mn,30#mn,45#mn,60#mn,90#mn,120#mn];
	
	// theresholds to color PDU zones depending on the mean bus delay time on bus stops
	list<float> PDUZ_BD_THRESHOLDS <- [10#mn,15#mn,20#mn,25#mn,30#mn,45#mn];
	
}

/*******************************/
/******* PDUZone Species ******/
/*****************************/

species PDUZone schedules: [] parallel: true {
	int pduz_code;
	string pduz_name;
	District pduz_district;
	rgb pduz_wp_col <- #white;
	rgb pduz_wt_col <- #white;
	rgb pduz_bd_col <- #white;
	
	// stats
	float pduz_accumulated_traffic_delay <- 0.0;
	float pduz_accumulated_signs_delay <- 0.0;
	float pduz_accumulated_passaging_delay <- 0.0;
	
	list<int> update_color {
		
		// compute waiting people
		int wp <- BusStop where (each.bs_zone = self) sum_of(length(each.bs_waiting_people));
		
		// pick color
		pduz_wp_col <- wp < PDUZ_WP_THRESHOLDS[0] ? PDUZ_COLORS[0] : (wp < PDUZ_WP_THRESHOLDS[1] ? PDUZ_COLORS[1] :
			(wp < PDUZ_WP_THRESHOLDS[2] ? PDUZ_COLORS[2] : (wp < PDUZ_WP_THRESHOLDS[3] ? PDUZ_COLORS[3] : 
				(wp < PDUZ_WP_THRESHOLDS[4] ? PDUZ_COLORS[4] : (wp < PDUZ_WP_THRESHOLDS[5] ? PDUZ_COLORS[5] : PDUZ_COLORS[6])))));
		
		//  compute mean waiting time 
		list<Individual> indivs <- BusStop where (each.bs_zone = self) accumulate (each.bs_waiting_people);
		list<int> wtimes <- indivs where (each.ind_current_plan_index = 0) accumulate int(time - each.ind_times[0][0]);
		wtimes <<+ indivs where (each.ind_current_plan_index = 1) accumulate int(time - each.ind_times[1][0]);
		int wt <- int(mean(wtimes));
		
		pduz_wt_col <- wt < PDUZ_WT_THRESHOLDS[0] ? PDUZ_COLORS[0] : (wt < PDUZ_WT_THRESHOLDS[1] ? PDUZ_COLORS[1] :
			(wt < PDUZ_WT_THRESHOLDS[2] ? PDUZ_COLORS[2] : (wt < PDUZ_WT_THRESHOLDS[3] ? PDUZ_COLORS[3] :
				(wt < PDUZ_WT_THRESHOLDS[4] ? PDUZ_COLORS[4] : (wt < PDUZ_WT_THRESHOLDS[5] ? PDUZ_COLORS[5] : PDUZ_COLORS[6])))));
				
		int bd <- int(mean(BusStop where (each.bs_zone = self) collect mean(each.bs_bv_delays)));
		// pick color
		pduz_bd_col <- bd < PDUZ_BD_THRESHOLDS[0] ? PDUZ_COLORS[0] : (bd < PDUZ_BD_THRESHOLDS[1] ? PDUZ_COLORS[1] :
			(bd < PDUZ_BD_THRESHOLDS[2] ? PDUZ_COLORS[2] : (bd < PDUZ_BD_THRESHOLDS[3] ? PDUZ_COLORS[3] :
				(bd < PDUZ_BD_THRESHOLDS[4] ? PDUZ_COLORS[4] : (bd < PDUZ_BD_THRESHOLDS[5] ? PDUZ_COLORS[5] : PDUZ_COLORS[6])))));
		
		return [wp,wt,bd];
	}
	
	// aspects
	aspect waiting_people {
		draw shape color: pduz_wp_col border: #black;
	}
	
	aspect waiting_time {
		draw shape color: pduz_wt_col border: #black;
	}
	
	aspect bus_delay {
		draw shape color: pduz_bd_col border: #black;
	}
}

/*** end of species definition ***/