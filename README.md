# Example RTL for ADXL362 Sensor Demonstration

This repository contains an example of RTL designed for demonstration purposes. The code provides a foundation that can be further extended to suit more complex use cases.

## Overview

The provided RTL implementation configures the **ADXL362** sensor, a low-power 3-axis MEMS accelerometer, to operate in **measurement mode**. Once configured, the design continuously reads data from the **x-axis register**.

## Key Features

- **Sensor Configuration**          : Initializes the ADXL362 sensor into measurement mode.
- **Continuous Data Acquisition**   : Continues reading x-axis register data.
- **Modular Design**                : The RTL is structured to be easily extended.

## Getting Started

To use this example:

1. Clone the repository:
   ```bash
   git clone https://github.com/GaloSG95/adxl362_master
2. Compilation
   ```bash
   cd adxl362_master
   . questa
3. Simulation
   ```bash
   cd adxl362_master
   . questa adxl362_master_tb