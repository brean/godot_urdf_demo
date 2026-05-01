# Godot URDF Demo
URDF for Godot 4.6 using the native XML-parser and updated stl importer.

## included and modified libraries:
 - Godot URDF by @askarkg12, [BSD-3 license](https://github.com/askarkg12/godot_urdf/blob/main/LICENSE): https://github.com/askarkg12/godot_urdf/
 - godot-stl-io by @onze, [MIT license](https://github.com/onze/godot-stl-io/blob/development/addons/stl-io/license.txt): https://github.com/onze/godot-stl-io/blob/development/addons/stl-io/

## Usage
Just clone this repo, open it as project in Godot and press play on the main Scene.
You can drive around the turtlebot robot using the W A S D keys.

From the URDF Generic6DOFJoint3D will be generated for all Joints that can be used by the Robot Controller for a Differential Drive / Skid Steering robot with either 2 or 4 wheels based on the [GodotMechanicsProject by @TechnoLukas](https://github.com/TechnoLukas/GodotMechanicusProj)

If you want to load your own robot, just put it in the urdf-folder, godot will import it automatically.

You can then either use the auto-loaded robot from the URDF or manually create a robot from a node that has the urdf_loader.gd-script attached, which makes it easy to modify the robot after loading.

## Screenshots / Examples
### Driving around
<img width="1920" height="1200" alt="Screenshot from 2026-02-20 17-18-26" src="https://github.com/user-attachments/assets/addfc1b3-90c3-45f4-9fe8-780c24ba3bd0" />
Fig. 1: The main Scene with the controllable turtlebot in the front. Note that the original URDF for the Turtlebot 3 defines the caster wheel in the back as box, a sphere would be more realistic.

### Importing a quadruped
<img width="1920" height="1200" alt="Screenshot from 2026-02-20 17-15-43" src="https://github.com/user-attachments/assets/586d5640-7d39-4768-8559-0a358ed7a609" />
Fig 2: The imported Spot Robot from Boston Dynamics (with custom configured collision meshes). Note that it is missing a controller so the robot will just collapse in on itself when you put it on any surface.
