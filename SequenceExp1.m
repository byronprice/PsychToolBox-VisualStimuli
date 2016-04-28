function [] = SequenceExp1(Dist_To_Screen,Display_Time,Parameters)
%SequenceExp1.m
%  Display a sequence of drifting gratings on the screen.
% INPUT: Parameters - vector of size x-by-8 ... where the 8 values represent
%          parameters for the grating display (in the following order) and
%          where x is the arbitrarily chosen number of gratings to display
%
%           Spat_Freq - desired spatial frequency in units of cycles/degree
%           Speed - speed of drifting grating, in units of cycles/second
%           Contrast - image contrast from 0 to 1 (no use of dynamic range to
%            full use of dynamic range)
%           Orientation - desired orientation of the grating stimuli, 0 is for
%               a horizontal sinusoidal grating (horizontal bars across width
%               of screen) and increasing angles (0 to 360 degrees) rotates the
%               grating clockwise around the screen
%           xLeft - x position (width) on the screen for left side of the grating
%           xRight - x position for right side
%           yTop - y position (height) for top of grating
%           yBottom - y position for bottom of grating
%               the origin (0,0) is at the top left of the screen and
%               only positive values are acceptable, so top is smaller than
%               bottom
%
%        Dist_To_Screen - physical distance of observer from the screen, in
%           units of cm
%        Display_Time - time to display the stimulus on the screen in units
%           of seconds

% Created: 2016/04/28 at 24 Cummington, Boston
%  Byron Price
% Updated: 2016/04/28
%  By: Byron Price


% Acquire a handle to OpenGL, so we can use OpenGL commands in our code:
global GL;

% Make sure this is running on OpenGL Psychtoolbox:
AssertOpenGL;

% Choose screen with maximum id - the secondary display:
screenid = max(Screen('Screens'));

% Open a fullscreen onscreen window on that display, choose a background
% color of 128 = gray with 50% max intensity:
[win,~] = Screen('OpenWindow', screenid,0);

% Switch color specification to use the 0.0 - 1.0 range
Screen('ColorRange', win, 1);

% Query window size in pixels
[w_pixels, h_pixels] = Screen('WindowSize', win);

if nargin == 0
    Display_Time = 100;
    Dist_To_Screen = 30;
    N = 4;
    Parameters = zeros(N,8);

    Parameters(1,:) = [0.2,0,1,45,0,w_pixels,0,h_pixels];
    Parameters(2,:) = [0.2,0,1,100,0,w_pixels,0,h_pixels];
    Parameters(3,:) = [0.2,0,1,10,0,w_pixels,0,h_pixels];
    Parameters(4,:) = [0.2,0,1,165,0,w_pixels,0,h_pixels];
end
numGratings = size(Parameters,1);

% Retrieve monitor refresh duration
ifi = Screen('GetFlipInterval', win);

% screen size in millimeters and a conversion factor to get from mm to pixels
[w_mm,h_mm] = Screen('DisplaySize',screenid);
conv_factor = (w_mm/w_pixels+h_mm/h_pixels)/2;

% initialize variables and perform unit conversions
Parameters(:,1) = (Parameters(:,1)./((tan((2*pi)/360))*(Dist_To_Screen*10))).*conv_factor; % convert cycles per degree to cycles per distance
     % on the screen, based on the input spatial frequency and the distance
     % to the screen in centimeters, then cycles per dist to cycles per
     % pixel
Parameters(:,2) = Parameters(:,2).*ifi;
%Parameters(:,4) = (Dist_To_Screen.*tan(Parameters(:,4).*(pi/180)))./conv_factor; % radius in degrees to radius in mm
Parameters(:,4) = Parameters(:,4).*(pi/180);

dgshader = [PsychtoolboxRoot '/DriftingSinGratingShader.vert.txt'];
GratingShader = LoadGLSLProgramFromFiles({ dgshader, [PsychtoolboxRoot '/DriftingSinGratingShader.frag.txt'] }, 1);


% Define first and second ring color as RGBA vector with normalized color
% component range between 0.0 and 1.0, based on Contrast between 0 and 1
% create all textures in the same window (win), each of the appropriate
% size
firstColor = zeros(numGratings,4);
secondColor = zeros(numGratings,4);
gratingTex = zeros(numGratings,1);
width = zeros(numGratings,1);
height = zeros(numGratings,1);
for ii=1:numGratings
    width(ii) = abs(Parameters(ii,5)-Parameters(ii,6));
    height(ii) = abs(Parameters(ii,7)-Parameters(ii,8));
    gratingTex(ii,1) = Screen('SetOpenGLTexture', win, [], 0, GL.TEXTURE_3D,round(width(ii)),...
        round(height(ii)), 1, GratingShader);
    firstColor(ii,:) = [0.5-Parameters(ii,3)/2 0.5-Parameters(ii,3)/2 0.5-Parameters(ii,3)/2 1];
    secondColor(ii,:) = [0.5+Parameters(ii,3)/2 0.5+Parameters(ii,3)/2 0.5+Parameters(ii,3)/2 1];
end

% Perform initial flip to gray background and sync us to the retrace:
vbl = Screen('Flip', win);
ts = vbl; 

% Animation loop
count = 0;
runs = ceil(Display_Time/ifi);
while count < runs && ~KbCheck
 
    % Draw all textures with its parameter settings. Draw
    % the procedural texture as any other texture via 'DrawTexture'
    jj = mod(count,4)+1;
    Screen('DrawTexture', win,gratingTex(jj,1), [],[Parameters(jj,5) Parameters(jj,7) ...
        Parameters(jj,6) Parameters(jj,8)],...
        [], [],[],[firstColor(jj,1) firstColor(jj,2) firstColor(jj,3) firstColor(jj,4)],...
        [], [], [secondColor(jj,1),secondColor(jj,2), secondColor(jj,3),secondColor(jj,4),...
        Parameters(jj,1),Parameters(jj,2),Parameters(jj,4),count,width(jj)/2,height(jj)/2,0,0]);
    % Request stimulus onset at next video refresh:
    vbl = Screen('Flip', win, vbl + .200);
    Screen('DrawTexture', win,gratingTex(jj,1), [],[Parameters(jj,5) Parameters(jj,7) ...
        Parameters(jj,6) Parameters(jj,8)],...
        [], [],[],[firstColor(jj,1) firstColor(jj,2) firstColor(jj,3) firstColor(jj,4)],...
        [], [], [firstColor(jj,1),firstColor(jj,2), firstColor(jj,3),firstColor(jj,4),...
        Parameters(jj,1),Parameters(jj,2),Parameters(jj,4),count,width(jj)/2,height(jj)/2,0,0]);
    vbl = Screen('Flip',win,vbl+0.15);
    count = count+1;
    if jj == 4
        WaitSecs(1.35);
    end
end

% Print some fps stats:
avgfps = count / (vbl - ts);
fprintf('Average redraw rate in Hz was: %f\n', avgfps);

Display_Time = runs/avgfps;
fprintf('Approximate display time in seconds was %f\n',Display_Time);

% Close window
Screen('CloseAll');
end
