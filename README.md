# PsychToolBox_VisualStimuli
Code for arbitrary generation of drifting gratings using openGL and the PsychToolBox. 

For the Byron_DriftingGrating set, place all three files in the directory */Psychtoolbox/ and then call the Byron_DriftingGrating.m file.  Try Byron_DriftingGrating(1,2,1,20,10,65,10) , which will give a grating with 1 cycle/degree spatial frequency, 2 cycle/second speed, contrast of 1, assumed observer position of 20 cm from the screen, 10 degrees of arc radius (converted to a size on the screen based on the distance to the screen), 65 degree orientation (horizontal bars), and displayed for 10 seconds. 

For the MultiGrating.m file, place it in the Psychtoolbox directory and then run as MultiGrating  .  You can input a matrix
of parameters in order to change the number and type of sinusoidal gratings displayed (see comments at the top of the code
for more information).

