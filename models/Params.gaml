/**
* Name: Params
* Description: this file stores general and main parameters.
* Authors: Laatabi
* For the i-Maroc project. 
*/

model Params

global {
	
	/********* Simulation *********/
	// whether to save simulation data (to /outputs) or not
	bool save_data_on <- false;
	// display or not buslines (instead of roads with traffic levels)
	bool show_buslines <- false;
	// display or not BRT lines
	bool show_brt_lines <- false; 
	/******************************/ 


	/********* Road Traffic *********/
	// use or not congestion from Google Traffic
	bool traffic_on <- false;
	/******************************/
	
	
	/********* Bus network *********/
	// allow ticket transfer between busses of the same trip (when false, promotes 1L-trips over 2L-trips) 
	bool transfer_on <- false; 
	
	// individuals have information about bus timetables
	bool time_tables_on <- false; 

	// whether BRT lines are activated or not
	bool use_brt_lines <- false;
	/******************************/
	
}

