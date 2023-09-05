# I-Maroc Project
**I-Maroc** (_**I**ntelligence artificielle/**M**athématiques **A**ppliquées, santé/envi**RO**nnement: simulation pour l’aide à la dé**C**ision_) is project that aims to design and implement computer simulations for health and environment by means of advanced artificial intelligence, data analysis, and mathematical tools. In the workpackage 3 (Urban and inter-urban mobility), we work on modeling multiple aspects of road traffic in Marrakesh to propose solutions and scenarios in order to improve mobility and reduce pollution and congestion. We present here **MarraSIM**, our agent-based model that simulates the public transport network in Marrakesh.

# MarraSIM Model
MarraSIM (Marrakesh SIMulator) is an agent-based model of road traffic and public transport in Marrakesh. We describe the structure and the dynamics of MarraSIM model using the protocol of the ODD (Overview, Design concepts, Details) standard.

## Overview

### Purpose
The purpose of the model is to simulate public transport in Marrakesh to understand the complex interactions between the transport demand, the bus network, and the Grand Taxis fleet. Using realistic data representing traffic flow, OD trips, and public transport fleet, the model allows testing different strategies that may reduce waiting and travel times, increase public transport efficiency, and limit the environmental burden of road traffic in Marrakesh.

### Entities, state variables, and scales
The model simulates a day (06:00 - 23:00) of public transport journeys in Marrakesh. The time step represents one minute. Bus vehicles move between bus stops to take and drop off people in outgoing and return journeys between a start point and a terminus. To simulate these dynamics, 11 agents are implemented to represent the city environment and the active agents. The following figure depicts the class diagram of the model.

<p align="center">
  <img width="800" height="504" alt="MarraSIM class diagram" src="https://github.com/laatabix/MarraSIM/assets/15381143/528ec2fb-b09b-489f-a7fb-abbb90990256">
<br/><i>UML Class diagram of the MarraSIM model.</i>
</p>

**Building** : these agents represent all types of buildings in the city (residential, industrial, commercial, ...). In the current version of the model, buildings are included for visualization purposes only.

**District** : represents one entity of the city's administrative division. In Marrakesh, there are six districts: Médina, Guéliz, Annakhil, Méchouar-Kasbah, Sidi Youssef Ben Ali (SYBA), and Ménara. Each district is identified by a code and a name.

<p align="center">
  <img width="440" height="355" alt="Administrative zoning of Marrakesh" src="https://github.com/laatabix/MarraSIM/assets/15381143/a626c016-c7d0-4db0-bb2e-b2ae8e0defcb">
  <br/><i>Administrative districts of Marrakesh.</i>
</p>

**PDUZone** : represents one entity of the adopted division in the PDU (Plan de D\'eplacements Urbains) document. The PDU is a big study that was conducted in 2009 to describe and evaluate the urban mobility and population movement in Marrakesh. The study divided the city into 27 zones based on multiple criteria of geography and urban fabric. We use this zoning since all the data presented in the PDU document is based on it. Each PDU zone is identified by a code and a name and may belong to one or multiple administrative districts.

<p align="center">
  <img width="440" height="355" alt="PDU zoning of Marrakesh" src="https://github.com/laatabix/MarraSIM/assets/15381143/41a43e8f-a5eb-4161-b4c5-e1b77ea601e5">
  <br/><i>The 27 PDU zones of Marrakesh.</i>
</p>

**Individual** : represents one passenger that has a PDU zone as origin and another one as a destination. Each individual has to take a bus or a taxi to reach its destination while minimizing travel time and cost. Each individual has four main attributes:
  - *ind_moving* : a boolean that indicates whether the individual has started its journey or not.
  - *ind_arrived* : a boolean that indicates whether the individual has reached its destination or not.
  - *ind_waiting_time* : an integer that indicates how much time (in seconds) the individual has waited in the bus stop before taking a transport mean.
  - *ind_trip_time* : an integer that indicates how much time (in seconds) the individual has traveled to reach its destination. This time starts when taking the first transport mean and ends when leaving the last transport mean.

**BusStop** : represents a location where a bus can take or drop off individuals. A bus stop has a name and may be an ordinary in-between stop, or a departure/terminus for one or multiple bus lines.

**RoadSegment** : represents one segment of the road network. All roads are divided into segments of 100m maximum. If a road segment is in the urban zone (represented by the boolean attribute *rs_in_city*, it can have a traffic density of four levels corresponding to the levels of the Google Traffic API:
  - ![](https://placehold.co/10x10/008000/008000.png) Normal with no traffic delays (green).
  - ![](https://placehold.co/10x10/ffa500/ffa500.png) Medium traffic (orange).
  - ![](https://placehold.co/10x10/ff0000/ff0000.png) High traffic (red).
  - ![](https://placehold.co/10x10/8b0000/8b0000.png) Heavy traffic (dark red).

<p align="center">
  <img width="440" height="355" alt="Urban roads of Marrakesh" src="https://github.com/laatabix/MarraSIM/assets/15381143/4261175a-b6ca-49ca-9110-9ea0d16d91e7">
  <br/><i>Urban road segments in Marrakesh.</i>
</p>

**TrafficSignal** : represents a sign that regulates traffic and may be stop sign or a traffic light.

**BusLine** : represents two paths of outgoing and return bus stops between a start (departure) and end (terminus) points. Each bus line is named and has the two following characteristics:
  - *bl_interval_time* : indicates the theoretical interval time between buses of the same line.
  - *bl_commercial_speed* : indicates the average speed of buses while considering the constraints of bus stops, traffic lights, and congestion.

**BusVehicle** : represents a vehicle that serves a bus line. The same bus line can be served by multiple vehicles. Each bus vehicle has the following attributes:
  - *bv_direction* : indicates whether a bus is currently in an outgoing or return direction.
  - *bv_speed* : indicates the true speed of a moving bus.
  - *bv_max_capacity* : indicates the maximum number of passengers that the bus can take.
  - *bv_moving* : a boolean to indicate whether a bus is currently moving or not.

**BusConnection** : determines a location where passengers can transfer between two bus lines. This connection may be in the same bus stop if the two bus lines intersect, or in two different but close bus stops otherwise. The proximity in this model is defined as a 400 m circle. The connections are computed to minimize the total journey distance, hence, only the best connections are considered.

**BusTrip** : represents a trip between an origin and a destination bus stops using one or two bus lines. The following attributes characterize a bus trip:
  - *bt_type* : indicates whether the trip is using one or two bus lines.
  - *bt_bus_directions* : stores the direction (outgoing or return) of each bus used in the trip.
  - *bt_bus_distances* : stores the traveled distances by the buses used in the trip.
  - *bt_walk_distance* : indicates the walk distance between bus stops if the trip includes a bus connection.

### Process overview and scheduling

# Preliminary results
