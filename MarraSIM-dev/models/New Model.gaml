/**
* Name: NewModel
* Based on the internal skeleton template. 
* Author: achra
* Tags: 
*/

model NewModel

global {
	/** Insert the global definitions, variables and actions here */
	
	init{
		create dummy number:10{
			location <- {rnd(100),rnd(50)};
			diam <- rnd(10);
			shape <- circle(diam);
		}		
		//write dummy[0].location;
		//write (dummy[0].shape.points);
		
		
		
	}
}

species dummy {
	//point location;
	int diam;
	
	aspect default {
		draw shape color: #blue depth:5;
		draw circle(4) color: #red depth:5;
	}
	
	reflex move {
		location <- location + {1,-1,2};
	}
}

experiment NewModel type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		
		display disp type:opengl {
			species dummy;
		}
	}
}
