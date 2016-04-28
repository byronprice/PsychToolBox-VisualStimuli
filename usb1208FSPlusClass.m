classdef usb1208FSPlusClass < singletonClass ...
        & ttlHardwareAbstractClass ...
        & daqHardwareAbstractClass ...
        & storedPreferenceClass ...
        & classThatThrowsWarnings
    
    % USB-1208FS-Plus Interface
    %
    % Mac and Linux systems use libusb-1.0 to communicate with the USB
    % device.  Compiled version of multiple c++ mex files required, see
    % README and Makefile for details.
    %
    
    properties (SetObservable,AbortSet)
        strobeDelay % set to zero to use minimum latency strobe
        AIChannelMode % Either SE or DIFF
    end
    
    properties (Hidden=true)
        dev % the device, set by openInterface method
    end
    
    properties (Constant,Hidden=true)
        singletonDesignatorKey = 'usb1208FSPlusClass';
        prefFileNameStr = 'usb1208FSPlusClass';
        archWarningID = 'usb1208FSPlusClass:ARCH';
        statusWarningID = 'usb1208FSPlusClass:badStatus';
    end
    
    properties (Hidden=true)
        % For error/warning messages
        useGUI = true;
    end
    
    properties % AI Calibration and Conversion properties
        nAI
        AIMaxCount
        range
        slope
        offset
    end
    
    properties (Constant)
        supportedArchs = {'GLNX86','GLNXA64','MACI64'};
        % Define control signal locations on DIO A
        CTRLDIO = 0;
        STARTBIT = 0;
        STOPBIT = 1;
        STROBEBIT = 2;
        % Designate DIO B for event word
        EVNTDIO = 1;
        EVNTBITS = 8;
        % 12 bit AO channels
        AOMAXCOUNT = 2^12 - 1;
        AORANGE = [0 5]; % Volts
    end
    
    methods (Static)
        
        % Provide methods to build command strings to control the digital
        % and analog ports
        
        function cmdStr = makeDOSetValueCommand(port,bit,value)
            % Format the command string to set a DIO port/bit
            if isempty(bit)
                cmdStr = sprintf('DIO{%i}:VALUE=%i',port,value);
            else
                cmdStr = sprintf('DIO{%i/%i}:VALUE=%i',port,bit,value);
            end
        end
        
        function cmdStr = makeAOSetValueCommand(channel,value)
            cmdStr = sprintf('AO{%i}:VALUE=%i',channel,value);
        end
        
    end
    
    methods
        
        function obj = usb1208FSPlusClass()
            % Open the USB-1208FS-Plus interface - dev property will be
            % empty the first time the constructor is called. In subsequent
            % calls it will not be empty due to the singleton superclass
            % constructor
            if obj.singletonNeedsConstruction
                obj.dev = 0;
                obj.strobeDelay = ttlHardwareAbstractClass.strobeTime;
                obj.preferencePropertyNames = {'strobeDelay',...
                    'AIChannelMode'};
                switch computer
                    case obj.supportedArchs
                        obj.openInterface;
                    otherwise
                        ME = MException(obj.archWarningID,...
                            'Unsupported Computer');
                        errorMsg = sprintf('%s: %s is an unsupported computer archtecture',...
                            class(obj),computer);
                        handleError(ME,true,...
                            errorMsg);
                end
                obj.loadSavedPreferences;
                obj.listenForPreferenceChanges;
            end
        end
        
        function delete(obj)
            if obj.isConstructed
                obj.hideWarnings(false);
                if obj.dev && obj.validateInterface
                    obj.closeInterface;
                end
            end
        end
        
        % TTL Interface methods
        
        function startRecording(obj)
            % sendMessage(obj,obj.makeDOSetValueCommand(obj.CTRLDIO,...
            %     obj.STARTBIT,1));
            usb1208FSPlusStartRecording(obj.dev);
        end
        
        function stopRecording(obj)
            % sendMessage(obj,obj.makeDOSetValueCommand(obj.CTRLDIO,...
            %     obj.STARTBIT,0));
            usb1208FSPlusStopRecording(obj.dev);
        end
        
        function strobeEventWord(obj,value)
            usb1208FSPlusSetEvent(obj.dev,value);
            strobe(obj);
        end
        
        function setEventWord(obj,value)
            usb1208FSPlusSetEvent(obj.dev,value);
        end
        
        function strobe(obj)
            if obj.strobeDelay > 0
                usb1208FSPlusSetStrobe(obj.dev,1);
                WaitSecs(obj.strobeDelay);
                usb1208FSPlusSetStrobe(obj.dev,0);
            else
                usb1208FSPlusStrobe(obj.dev,0);
            end
        end
        
        function isOpen = openInterface(obj)
            if obj.dev && obj.validateInterface
                % If the dev is already open and valid, do nothing
                isOpen = true;
            else
                % Open and validate the dev
                obj.dev = usb1208FSPlusOpenInterface();
                isOpen = obj.validateInterface();
            end
        end
        
        function closeInterface(obj)
            usb1208FSPlusCloseInterface(obj.dev);
            obj.dev = 0;
        end
        
        function status = setAnalogLevel(obj,value)
            if value > 1
                errordlg('usb1208FSPlusClass.setAnalogLevel: max value 1');
            end
            status = usb1208FSPlusSetAnalog(obj.dev,obj.aoChannel,value);
        end
        
        function returnValue = sendMessage(obj,message)
            [status,returnValue] = usb1208FSPlusSendMessage(obj.dev,message);
            if status ~= 1
                ME = MException(obj.statusWarningID,...
                    returnValue);
                errStr = sprintf('sendMessage(''%s'') failed',...
                    message);
                errStr = sprintf('%s.%s\n',class(obj),errStr);
                handleWarning(ME,obj.useGUI,errStr);
            end
        end
        
        function isValid = validateInterface(obj)
            if obj.dev == 0
                isValid = 0;
            else
                % Send a command and check to make sure that the DAQ
                % responds as expected
                [status,returnValue] = usb1208FSPlusSendMessage(obj.dev,...
                    '?DIO');
                isValid = status == 1 && strcmp(returnValue,'DIO=2');
            end
        end
        
        function hideWarnings(obj,trueOrFalse)
            hideWarnings@classThatThrowsWarnings(obj,trueOrFalse);
            obj.useGUI = ~obj.warningsAreSuppressed;
        end
        
        % -----------------------------------------------------------------
        % DAQ Interface Methods
        
        function status = writeAnalog(obj,channel,value)
            if value > obj.AOMAXCOUNT
                error('%s.writeAnalog: max value is %i',...
                    class(obj),obj.AOMAXCOUNT);
            end
            msg = obj.makeAOSetValueCommand(channel,value);
            status = obj.sendMessage(msg);
        end
        
        function status = setAnalogOutVoltage(obj,channel,value)
            countValue = floor(obj.AOMAXCOUNT * value / obj.AORANGE(2));
            status = obj.writeAnalog(channel,countValue);
        end
        
        function value = readAnalog(obj,channel)
            %             cmdStr = sprintf('?AI{%i}:VALUE',channel);
            %             [~,rtrnValue] = obj.sendMessage(cmdStr);
            %             data = sscanf(rtrnValue,'AI{%i}:VALUE=%i');
            %             value = data(2);
            [status,value,respStr] = usb1208FSPlusGetAI(obj.dev,channel);
            if status ~= 1
                if status ~= 1
                    ME = MException(obj.statusWarningID,respStr);
                    errStr = sprintf('%s.readAnalog failed\n',class(obj));
                    handleWarning(ME,obj.useGUI,errStr);
                end
            end
        end
        
        function scaleValue = readAnalogVoltage(obj,channel)
            value = obj.readAnalog(channel);
            calData = value * obj.slope(channel+1) + obj.offset(channel+1);
            calData = max([calData 0]);
            calData = min([calData obj.AIMaxCount]);
            totalRange = diff(obj.range(channel+1,:));
            scaleValue = calData * totalRange / (obj.AIMaxCount + 1);
            % Note: following line is a hack that seems to work for DIFF
            % mode.  Not sure why.  Also doesn't seem to work for SE mode.
            scaleValue = scaleValue - totalRange / 2;
            % fprintf('value = %d, scaled = %d\n',value,scaleValue);
        end
        
        function status = writeDigital(obj,port,bit,value)
            msg = obj.makeDOSetValueCommand(port,bit,value);
            status = obj.sendMessage(msg);
        end
        
        function data = readDigital(obj,varargin)
            data = [];
        end
        
        function set.AIChannelMode(obj,mode)
            switch mode
                case {'DIFF' 'SE'}
                    obj.AIChannelMode = mode;
                    obj.configureAI;
                otherwise
                    error('%s.AIChannelMode must be either SE or DIFF');
            end
        end
        
        function triggerON(obj,port,bit)
            cmd = obj.makeDOSetValueCommand(port,bit,1);
            obj.sendMessage(cmd);
        end
        
        function triggerOFF(obj,port,bit)
            cmd = obj.makeDOSetValueCommand(port,bit,0);
            obj.sendMessage(cmd);
        end
        
        function configureAI(obj)
            obj.sendMessage(sprintf('AI:CHMODE=%s',obj.AIChannelMode));
            rtrnStr = obj.sendMessage('?AI:CHMODE');
            chMode = sscanf(rtrnStr,'AI:CHMODE=%s');
            switch chMode
                case 'DIFF'
                    obj.AIMaxCount = 2^12 - 1; % 4 12-bit channels
                case 'SE'
                    obj.AIMaxCount = 2^11 - 1; % 8 11-bit channels
            end
            rtrnStr = obj.sendMessage('?AI');
            obj.nAI = sscanf(rtrnStr,'AI=%i');
            obj.range = zeros(obj.nAI,2);
            obj.slope = zeros(1,obj.nAI);
            obj.offset = zeros(1,obj.nAI);
            for iA = 0:obj.nAI-1
                rtrnStr = sendMessage(obj,sprintf('?AI{%i}:RANGE',iA));
                rangeStr = sscanf(rtrnStr,sprintf('AI{%i}:RANGE=%%s',iA));
                switch rangeStr
                    case 'BIP10V'
                        obj.range(iA+1,:) = [-10 10];
                    case 'BIP20V'
                        obj.range(iA+1,:) = [-20 20];
                end
                rtrnStr = sendMessage(obj,sprintf('?AI{%i}:SLOPE',iA));
                obj.slope(iA+1) = sscanf(rtrnStr,sprintf('AI{%i}:SLOPE=%%f',iA));
                rtrnStr = sendMessage(obj,sprintf('?AI{%i}:OFFSET',iA));
                obj.offset(iA+1) = sscanf(rtrnStr,sprintf('AI{%i}:OFFSET=%%f',iA));
            end
            
        end
        
        
    end
    
end