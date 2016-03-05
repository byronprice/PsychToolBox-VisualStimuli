# PsychToolBox_VisualStimuli
Code for arbitrary generation of drifting gratings using openGL and the PsychToolBox. 

Place all files in the directory */Psychtoolbox and then try calling DriftingSinGrating.m file.  Try as is, i.e. DriftingSinGrating(), which will display 100 tiles, each with its own drifting sinusoidal grating with randomly-generated values for spatial frequency, speed, contrast, and orientation.

The WhiteNoise_ReverseCorrelation.m stimulus will present a series of flat grey screens followed by periods of white noise, used for the reverse correlation technique to infer spatial receptive fields in V1.

ReverseCorr_Analysis.m will perform the reverse correlation analysis after presentation of the stimulus set in WhiteNoise_ReverseCorrelation.m . The code assumes that pre-processed calcium  imaging data are imported with the first frame exactly synchronous with the onset of the first stimulus, recorded at Fs Hz sampling frequency, and converted to a point process with some kind of spike-detection algorithm.


