# MarraSIM Model
MarraSIM (Marrakesh SIMulator) is an agent-based model of road traffic and public transport in Marrakesh. We describe the MarraSIM model using the structure of the ODD (Overview, Design concepts, Details) protocol.

## Overview

### Purpose
The purpose of the model is to simulate public transport in Marrakesh to understand the complex interactions between the transport demand, the bus network, and the Grand Taxis fleet. Using realistic data representing traffic flow, OD trips, and public transport fleet, the model allows testing different strategies that may reduce waiting and travel times, increase public transport efficiency, and limit the environmental burden of road traffic in Marrakesh.

### Entities, state variables, and scales
The model simulates a day (06:00 - 23:00) of public transport journeys in Marrakesh. The time step represents one minute. Bus vehicles move between bus stops to take and drop off people in outgoing and return journeys between a start point and a terminus. To simulate these dynamics, 11 agents are implemented to represent the city environment and the active agents. The following figure depicts the class diagram of the model.

<p align="center">
  <img width="800" height="504" src="https://github.com/laatabix/MarraSIM/assets/15381143/e59d7cfc-776e-4382-924e-a8ae7967f4c1">
</p>

**Building** : these agents represent all types of buildings in the city (residential, industrial, commercial, ...). In the current version of the model, buildings are included for visualization purposes only.

**District** : represents one entity of the city's administrative division. In Marrakesh, there are six districts: Médina, Guéliz, Annakhil, Méchouar-Kasbah, Sidi Youssef Ben Ali (SYBA), and Ménara. Each district is identified by a code and a name.

<p align="center">
  <img width="440" height="355" src="https://github.com/laatabix/MarraSIM/assets/15381143/a626c016-c7d0-4db0-bb2e-b2ae8e0defcb">
</p>

**PDUZone** : represents one entity of the adopted division in the PDU (Plan de D\'eplacements Urbains) document. The PDU is a big study that was conducted in 2009 to describe and evaluate the urban mobility and population movement in Marrakesh. The study divided the city into 27 zones based on multiple criteria of geography and urban fabric. We use this zoning since all the data presented in the PDU document is based on it. Each PDU zone is identified by a code and a name and may belong to one or multiple administrative districts.

<p align="center">
  <img width="440" height="355" src="https://github.com/laatabix/MarraSIM/assets/15381143/38223da0-64a9-4e9d-88f8-1defb79f8874">
</p>

**Individual** : represents one passenger that has a PDU zone as origin and another one as a destination. Each individual has to take a bus or a taxi to reach its destination while minimizing travel time and cost. Each individual has four main attributes:

  *ind_moving* : a boolean that indicates whether the individual has started its journey or not.
  
  *ind_arrived* : a boolean that indicates whether the individual has reached its destination or not.
  
  *ind_waiting_time* : an integer that indicates how much time (in seconds) the individual has waited in the bus stop before taking a transport mean.
  
  *ind_trip_time* : an integer that indicates how much time (in seconds) the individual has traveled to reach its destination. This time starts when taking the first transport mean and ends when leaving the last transport mean.
