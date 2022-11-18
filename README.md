# Thermal Profiling

## Measuring gantry deflection and frame expansion

This script runs a series of defined homing and probing routines designed to
characterize how the perceived Z height of the printer changes as the printer
frame heats up. It does this by interfacing with the Moonraker API, so you will need to ensure you have Moonraker running.

First, download the script `measure_thermal_behavior.py` to your printer's Pi. My favorite way to do this is to ssh into the Pi and just clone this git repository:

`git clone https://github.com/alchemyEngine/measure_thermal_behavior`


### Edit script for your printer

You'll need to edit the script (please use a vanilla text editer, such as Nano, that doesn't fuck with line endings) to include parameters appropriate for your printer. Please also fill in the `META DATA` section - this will help us find patterns across printer configurations!

```
######### META DATA #################
# For data collection organizational purposes only. Useful when sharing dataset.
USER_ID = ''            # e.g. Discord handle
PRINTER_MODEL = ''      # e.g. 'voron_v2_350'
HOME_TYPE = ''          # e.g. 'nozzle_pin', 'microswitch_probe', etc.
PROBE_TYPE = ''         # e.g. 'klicky', 'omron', 'bltouch', etc.
X_RAILS = ''            # e.g. '1x_mgn12_front', '2x_mgn9'
BACKERS = ''            # e.g. 'steel_x_y', 'Ti_x-steel_y', 'mgn9_y'
NOTES = ''              # anything note-worthy about this particular run,
                        #     no "=" characters
#####################################

######### CONFIGURATION #############
BASE_URL = 'http://127.0.0.1:7125'  # Printer URL (e.g. http://192.168.1.15)
                                    # leave default if running locally on Pi.

BED_TEMPERATURE = 105               # Bed target temperature for measurements.

HE_TEMPERATURE = 100                # Extruder temperature for measurements.

MEASURE_INTERVAL = 1                # Interval between Z measurements [minutes]

N_SAMPLES = 3                       # Number of repeated measurements of Z
                                    # taken at each MEASURE_INTERVAL.

HOT_DURATION = 3                    # time after bed temp reached to continue
                                    # measuring [hours]

COOL_DURATION = 0                   # Time to continue measuring after heaters
                                    # are disabled [hours].

SOAK_TIME = 5                       # Time to wait for bed to heatsoak after
                                    # reaching BED_TEMPERATURE [minutes].

MEASURE_GCODE = 'G28 Z'             # G-code called on repeated Z measurements,
                                    # single line command or macro only.

TRAMMING_METHOD = "quad_gantry_level" # One of: "quad_gantry_level", "z_tilt", or None

TRAMMING_CMD = "QUAD_GANTRY_LEVEL"  # Command for QGL/Z-tilt adjustments.
                                    # e.g. "QUAD_GANTRY_LEVEL", "Z_TILT_ADJUST",
                                    # "CUSTOM_MACRO", or None.

MESH_CMD = "BED_MESH_CALIBRATE"     # Command to measure bed mesh for gantry/bed
                                    # bowing/deformation measurements.

# If using the Z_THERMAL_ADJUST module. [True/False]
Z_THERMAL_ADJUST = True

# Full config section name of the frame temperature sensor (if any). E.g:
# CHAMBER_SENSOR = "temperature_sensor chamber"
CHAMBER_SENSOR = None

# Extra temperature sensors to collect. E.g:
# EXTRA_SENSORS = {"ambient": "temperature_sensor ambient",
#                  "mug1": "temperature_sensor coffee"}
# can be left empty if none to define.
EXTRA_SENSORS = {}
#####################################
```

Note that if you want to calculate your printers frame expansion coefficient, you will need to include a frame temperature sensor definition.

If you haven't already, copy the modified `measure_thermal_behavior.py` to the Pi running Klipper/Moonraker.

## Modify printer config

You may want to adjust a few elements of your printer configuration to give the most accurate results possible. 

In particular, we have found that long/slow bed probing routines can influence results as the bed heats up the gantry extrusion over the course of the mesh probing! This often manifests as an apparent front-to-back slope in the mesh.

For our purposes, a quick probe is usually sufficient. Below are some suggested settings:

```
[probe]
##  Inductive Probe - If you use this section , please comment the [bltouch] section
##  This probe is not used for Z height, only Quad Gantry Leveling
##  In Z+ position
##  If your probe is NO instead of NC, add change pin to ^PA3
pin: ^PA3
x_offset: 0
y_offset: 18.0
z_offset: 8
speed: 10.0
lift_speed: 10.0
samples: 1
samples_result: median
sample_retract_dist: 1.5
samples_tolerance: 0.05
samples_tolerance_retries: 10


[bed_mesh]
speed: 500
horizontal_move_z: 10
mesh_min: 30,30
mesh_max: 320,320
probe_count: 7,7
mesh_pps: 2,2
relative_reference_index: 24
algorithm: bicubic
bicubic_tension: 0.2
move_check_distance: 3.0
split_delta_z: .010
fade_start: 1.0 
fade_end: 5.0
```

## Adjust printer hardware

There are a couple hardware tips we've found that help to yield repeatable and accurate results. 

#### Make sure nozzle is clean

If you are using a nozzle switch style endstop (as in stock Voron V1/V2), plastic boogers can ruin a profiling run. Make sure it is clean before the run!

#### Loosen bed screws

We have seen that over-constraint of the bed can severely impact mesh reliability at different temperatures. For optimal results, we suggest only having a single tight bed screw during profiling. 


## Run data collection

For accurate results, ensure the *entire* printer is at ambient temp. It can take a couple hours for the frame to cool down completely after a run!

Run the script with Python3:

`python3 measure_thermal_behavior.py`

You may want to run it using `nohup` so that closing your ssh connection doesn't kill the process:

`nohup python3 measure_thermal_behavior.py > out.txt &`

The script will run for about 3 hours. It will home, QGL, home again, then heat the bed up.

While the bed is heating, the toolhead will move up to 80% of maximum Z height. This is to reduce the influence of the bed heater on the X gantry extrusion as much as possible while the bed heats.

Once the bed is at temp, it will take the first mesh. Then it will collect z expansion data once per minute for the next two hours. Finally, it will do one more mesh and then cooldown.

## Processing data

The script will write the data to the folder from which it is run. 

You have two options to generate plots: run the plotting scripts on the Pi, or run them on your PC.

### Running on the RPi

You'll need to install some additional libraries to run the plotting scripts on the Pi. First, use apt-get to install pip for python3 and libatlas, which is a requirement for Numpy:

```
sudo apt-get update
sudo apt-get install python3-pip
sudo apt-get install libatlas-base-dev
```

Then, you can use pip via python3 to install the plotting script dependencies using the `requirements.txt` file from this repository:

`python3 -m pip install -r requirements.txt`


Finally, there are two processing scripts that can be run on the json results file:
1. `process_meshes.py`, which will output plots pertaining to the bed mesh measurements

    E.g: `process_meshes.py thermal_quant_{}.json`.
2. `process_frame_expansion.py`, which will output plots pertaining to thermal expansion measurements. Check `temp_coeff_fitting.png` to ensure a proper linear fit and the `temp_coeff` value for the `[z_thermal_adjust]` configuration section.

    E.g.: `process_frame_expansion.py thermal_quant_{}.json`

You can include as many json-formatted datafiles as you want as positional arguments.

### Running on the PC

To run on your PC, download the `thermal_quant_{}.json` results file. 

The rest is left as an exercise to the reader.
