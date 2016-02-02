function [] = MultiGrating(Parameters)
%MultiGrating.m
%   Display an arbitrary number of drifting sinusoidal gratings to the
%   screen.
% INPUT: Parameters - this will be a [z by 7] matrix, where x is the
%          desired number of drifting gratings to produce, and 9 is a 
%          set of parameters for each grating
%           Parameters(z,1) = spatial frequency in units of cycles/degree
%           Parameters(z,2) = speed in units of cycles/second, presently
%               speed must be given in whole number units
%           Parameters(z,3) = contrast (from 0 to 1)
%           Parameters(z,4) = radius of the circular grating
%                in units of degrees of arc
%           Parameters(z,5) = orientation in degrees
%           Parameters(z,6) = center position in x 
%           Parameters(z,7) = center position in y
%               the origin (0,0) is the center of the screen, with 
%               increasing x to the right, increasing y up

% Created: 16/02/02 at 24 Cummington, Boston
%  Byron Price
% Updated: 16/02/02
%  By: Byron Price

if nargin == 0
    % set Parameters for default display, 6 different patches, each
    %   with a different set of variables
    Parameters = [1,1,1,10,35,200,-200;...
        2,10,1,5,0,0,0;0.5,3,1,20,198,250,350;3,5,1,15,75,-300,-300;4,2,1,10,...
        295,-400,400;0.1,1,1,15,35,-250,100];
end

Dist_To_Screen = 30;
Display_Time = 20;

% Acquire a handle to OpenGL, so we can use OpenGL commands in our code:
global GL;

% Make sure this is running on OpenGL Psychtoolbox:
AssertOpenGL;


% Choose screen with maximum id - the secondary display:
screenid = max(Screen('Screens'));

% Open a fullscreen onscreen window on that display, choose a background
% color of 128 = gray with 50% max intensity:
win = Screen('OpenWindow', screenid,128);


% Query window size: Need this to define center and radius of expanding
% disk stimulus:
[w_pixels, h_pixels] = Screen('WindowSize', win);

maxSize = max(w_pixels,h_pixels);
% screen size in millimeters
[w_mm,h_mm] = Screen('DisplaySize',screenid);
conv_factor = (w_mm/w_pixels+h_mm/h_pixels)/2;

% Define white and black color scheme
white=WhiteIndex(screenid);
black=BlackIndex(screenid);
inc = white-black;

ifi = Screen('GetFlipInterval', win);

% Perform initial flip to gray background and sync us to the retrace:
vbl = Screen('Flip', win);

frameRate = 1/ifi;
multiplier = 1;
numFrames = multiplier*round(frameRate);
numPatches = size(Parameters,1);

% Compute each frame of the movie and convert those frames, stored in
	% MATLAB matices, into Psychtoolbox OpenGL textures using 'MakeTexture';
for ii=1:numFrames
    mix_coeff = zeros(maxSize+1,maxSize+1);
    for j=1:numPatches
        % initialize variables
        Spat_Freq = Parameters(j,1);
        Speed = Parameters(j,2);
        Contrast = Parameters(j,3);
        Radius = Parameters(j,4);
        Orientation = Parameters(j,5);
        w_center = Parameters(j,6);
        h_center = Parameters(j,7);
        
        % Conversions
        cycles_dist = Spat_Freq/((tan((2*pi)/360))*(Dist_To_Screen*10)); % convert cycles per degree to cycles per distance
        % on the screen, based on the input spatial frequency and the distance
        % to the screen in centimeters
        cycles_pixel = cycles_dist*conv_factor; % cycles per dist to cycles per pixel
        Orientation = Orientation*pi/180;
        Radius = Dist_To_Screen*tan(Radius*pi/180); % radius in degrees to radius in mm
        Radius = Radius/conv_factor;
        phase=(ii/numFrames)*2*pi*(multiplier*Speed);
        
        % the size of this meshgrid can be changed, but you'll have to also
        %  adjust the mix_coeff matrix above
        [x,y] = meshgrid(-maxSize/2:maxSize/2,-maxSize/2:maxSize/2);
        x = x-w_center;
        y = y+h_center;
        sigmasquare = 2*4*Radius*Radius; % 68-95-99 rule, 2*simga accounts for 95%
        a = sin(Orientation)*cycles_pixel*2*pi;
        b = cos(Orientation)*cycles_pixel*2*pi;
        kernel = exp(-(x.*x./sigmasquare+y.*y./sigmasquare));
        mix_coeff = mix_coeff+((0.5+0.5*sin(a*x+b*y+phase)).*kernel)*Contrast;
    end
    tex(ii)=Screen('MakeTexture',win,black+inc*mix_coeff);
end


% Convert movieDuration in seconds to duration in frames to draw:
movieDurationFrames = round(Display_Time * frameRate);
movieFrameIndices = mod(0:(movieDurationFrames-1), numFrames) + 1;

% Use realtime priority for better timing precision:
priorityLevel=MaxPriority(win);
Priority(priorityLevel);

count = 1;
% Animation loop:
while count < movieDurationFrames && ~KbCheck
    % Draw image:
    Screen('DrawTexture', win, tex(movieFrameIndices(count)));
    % Show it at next display vertical retrace. Please check DriftDemo2
    % and later, as well as DriftWaitDemo for much better approaches to
    % guarantee a robust and constant animation display timing! This is
    % very basic and not best practice!
    Screen('Flip', win,vbl+ifi/2);
    count = count+1;
end

Priority(0);
Screen('Close');

% Close window:
Screen('closeall');

end
