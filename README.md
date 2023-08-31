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

**District** : represents one entity of the city's administrative division. In Marrakesh, there are six districts: Médina, Guéliz, Annakhil, Méchouar-Kasbah, Sidi Youssef Ben Ali (SYBA), and Ménara.

<p align="center">
  <img width="440" height="355" src="https://github.com/laatabix/MarraSIM/assets/15381143/a626c016-c7d0-4db0-bb2e-b2ae8e0defcb">
</p>



