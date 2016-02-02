function [] = Byron_DriftingGrating(Spat_Freq,Speed,Contrast,Dist_To_Screen,Radius,Orientation,Display_Time)
%Byron_DriftingGrating.m
%  
% INPUT: Spat_Freq - desired spatial frequency in units of cycles/degree
%        Speed - speed of drifting, in units of cycles/second
%        Contrast - image contrast from 0 to 1 (no use of dynamic range to
%            full use of dynamic range)
%        Dist_To_Screen - physical distance of observer from the screen, in
%           units of cm
%        Radius - radius of the grating in degrees of arc
%        Orientation - desired orientation of the grating stimuli, 0 is for
%           a horizontal sinusoidal grating (horizontal bars across width
%           of screen) and increasing angles (0 to 360 degrees) rotates the
%           grating clockwise around the screen
%        Display_Time - time to display the stimulus on the screen in units
%           of seconds

% Created: 16/01/26 at 24 Cummington, Boston
%  Byron Price
% Updated: 16/02/02
%  By: Byron Price

if Contrast < 0 || Contrast > 1 
    display('Contrast must be between 0 and 1')
    return;
end
if Display_Time < 0 
    display('Display_Time must be greater than zero')
    return;
end

% Acquire a handle to OpenGL, so we can use OpenGL commands in our code:
global GL;

% Make sure this is running on OpenGL Psychtoolbox:
AssertOpenGL;

% Choose screen with maximum id - the secondary display:
screenid = max(Screen('Screens'));

% Open a fullscreen onscreen window on that display, choose a background
% color of 128 = gray with 50% max intensity:
win = Screen('OpenWindow', screenid,128);

% Switch color specification to use the 0.0 - 1.0 range
Screen('ColorRange', win, 1);

% Query window size in pixels
[w_pixels, h_pixels] = Screen('WindowSize', win);

% screen size in millimeters and a conversion factor to get from mm to pixels
[w_mm,h_mm] = Screen('DisplaySize',screenid);
conv_factor = (w_mm/w_pixels+h_mm/h_pixels)/2;

dgshader = [PsychtoolboxRoot '/Byron_DriftingGratingShader.vert.txt'];
GratingShader = LoadGLSLProgramFromFiles({ dgshader, [PsychtoolboxRoot '/Byron_DriftingGratingShader.frag.txt'] }, 1);

% Create a purely virtual texture 'ringtex' of size tw x th virtual pixels, i.e., the
% full size of the window. Attach the GratingShader to it
ringtex = Screen('SetOpenGLTexture', win, [], 0, GL.TEXTURE_RECTANGLE_EXT,w_pixels,h_pixels, 1, GratingShader);

% Define first and second ring color as RGBA vector with normalized color
% component range between 0.0 and 1.0, based on Contrast between 0 and 1
firstColor = [0.5-Contrast/2 0.5-Contrast/2 0.5-Contrast/2 1];
secondColor  = [0.5+Contrast/2 0.5+Contrast/2 0.5+Contrast/2 1];

% Retrieve monitor refresh duration:
ifi = Screen('GetFlipInterval', win);

% Perform initial flip to gray background and sync us to the retrace:
vbl = Screen('Flip', win);
ts = vbl;

% initialize variables
count = 0;
cycles_dist = Spat_Freq/((tan((2*pi)/360))*(Dist_To_Screen*10)); % convert cycles per degree to cycles per distance
     % on the screen, based on the input spatial frequency and the distance
     % to the screen in centimeters
cycles_pixel = cycles_dist*conv_factor; % cycles per dist to cycles per pixel
Orientation = Orientation*pi/180;
Speed = Speed*ifi;
wcenter = w_pixels/2;
hcenter = h_pixels/2;
Radius = Dist_To_Screen*tan(Radius*pi/180); % radius in degrees to radius in mm
Radius = Radius/conv_factor;

% Animation loop
runs = ceil(Display_Time/ifi);
while count < runs && ~KbCheck
    count = count + 1;
    
    % Draw the stimulus with its current parameter settings. We simply draw
    % the procedural texture as any other texture via 'DrawTexture'
    Screen('DrawTexture', win, ringtex, [], [],[], [],[],[], [], [], [firstColor(1),firstColor(2),firstColor(3),firstColor(4),... 
            secondColor(1), secondColor(2), secondColor(3), secondColor(4),cycles_pixel,count,Orientation,Speed, ...
            Radius,wcenter,hcenter,0]);
    
    % Request stimulus onset at next video refresh:
    vbl = Screen('Flip', win, vbl + ifi/2);
end

% Print some fps stats:
avgfps = count / (vbl - ts);
fprintf('Average redraw rate in Hz was: %f\n', avgfps);

Display_Time = runs/avgfps;
fprintf('Approximate display time in seconds was %f\n',Display_Time);

% Close window
Screen('CloseAll');
end

