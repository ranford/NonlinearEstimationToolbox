
classdef LinearSystemModel < SystemModel & AnalyticSystemModel
    % Linear system model corrupted by linear transformed additive noise.
    %
    % LinearSystemModel Methods:
    %   LinearSystemModel        - Class constructor.
    %   setNoise                 - Set the system noise.
    %   systemEquation           - The system equation.
    %   derivative               - Compute the derivative of the implemented system equation.
    %   simulate                 - Simulate the temporal evolution for a given system state.
    %   analyticPredictedMoments - Analytic calculation of the first two moments of the predicted state distribution.
    %   setSystemMatrix          - Set the system matrix.
    %   setSystemInput           - Set the system input vector.
    %   setSystemNoiseMatrix     - Set the system noise matrix.
    
    % >> This function/class is part of the Nonlinear Estimation Toolbox
    %
    %    For more information, see https://bitbucket.org/nonlinearestimation/toolbox
    %
    %    Copyright (C) 2015  Jannik Steinbring <jannik.steinbring@kit.edu>
    %
    %                        Institute for Anthropomatics and Robotics
    %                        Chair for Intelligent Sensor-Actuator-Systems (ISAS)
    %                        Karlsruhe Institute of Technology (KIT), Germany
    %
    %                        http://isas.uka.de
    %
    %    This program is free software: you can redistribute it and/or modify
    %    it under the terms of the GNU General Public License as published by
    %    the Free Software Foundation, either version 3 of the License, or
    %    (at your option) any later version.
    %
    %    This program is distributed in the hope that it will be useful,
    %    but WITHOUT ANY WARRANTY; without even the implied warranty of
    %    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %    GNU General Public License for more details.
    %
    %    You should have received a copy of the GNU General Public License
    %    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
	methods
        function obj = LinearSystemModel(sysMatrix, sysNoiseMatrix)
            % Class constructor.
            %
            % Parameters:
            %   >> sysMatrix (Square matrix or empty matrix)
            %      The system matrix.
            %      An empty matrix means the identity matrix of appropriate dimensions.
            %      Default: Empty matrix.
            %
            %   >> sysNoiseMatrix (Matrix or empty matrix)
            %      The system noise matrix.
            %      An empty matrix means the identity matrix of appropriate dimensions.
            %      Default: Empty matrix.
            %
            % Returns:
            %   << obj (LinearSystemModel)
            %      A new LinearSystemModel instance.
            
            if nargin < 1
                obj.setSystemMatrix([]);
            else
                obj.setSystemMatrix(sysMatrix);
            end
            
            if nargin < 2
                obj.setSystemNoiseMatrix([]);
            else
                obj.setSystemNoiseMatrix(sysNoiseMatrix);
            end
            
            obj.setSystemInput([]);
        end
        
        function setSystemMatrix(obj, sysMatrix)
            % Set the system matrix.
            %
            % By default, the system matrix is an empty matrix
            % (i.e., an identity matrix of appropriate dimensions).
            %
            % Parameters:
            %   >> sysMatrix (Square matrix or empty matrix)
            %      The new system matrix.
            %      An empty matrix means the identity matrix of appropriate dimensions.
            
            if ~Checks.isSquareMat(sysMatrix) && ...
               ~isempty(sysMatrix)
                error('LinearSystemModel:InvalidSystemMatrix', ...
                      'sysMatrix must be a square matrix or an empty matrix.');
            end
            
            obj.sysMatrix = sysMatrix;
        end
        
        function setSystemInput(obj, sysInput)
            % Set the system input vector.
            %
            % By default, the system input is an empty matrix.
            %
            % Parameters:
            %   >> sysInput (Column vector or empty matrix)
            %      The new system input vector.
            %      An empty matrix means no input vector.
            
            if ~Checks.isColVec(sysInput) && ...
               ~isempty(sysInput)
                error('LinearSystemModel:InvalidSystemInput', ...
                      'sysInput must be a column vector or an empty matrix.');
            end
            
            obj.sysInput = sysInput;
        end
        
        function setSystemNoiseMatrix(obj, sysNoiseMatrix)
            % Set the system noise matrix.
            %
            % This is not the system noise covariance matrix!
            %
            % By default, the noise matrix is an empty matrix
            % (i.e., an identity matrix of appropriate dimensions).
            %
            % Parameters:
            %   >> sysNoiseMatrix (Matrix or empty matrix)
            %      The new system noise matrix.
            %      An empty matrix means the identity matrix of appropriate dimensions.
            
            if ~Checks.isMat(sysNoiseMatrix) && ...
               ~isempty(sysNoiseMatrix)
                error('LinearSystemModel:InvalidSystemNoiseMatrix', ...
                      'sysNoiseMatrix must be a matrix or an empty matrix.');
            end
            
            obj.sysNoiseMatrix = sysNoiseMatrix;
        end
    end
    
    methods (Sealed)
        function predictedStates = systemEquation(obj, stateSamples, noiseSamples)
            dimState = size(stateSamples, 1);
            dimNoise = size(noiseSamples, 1);
            
            if isempty(obj.sysMatrix)
                predictedStates = stateSamples;
            else
                obj.checkSysMatrix(dimState);
                
                predictedStates = obj.sysMatrix * stateSamples;
            end
            
            if isempty(obj.sysNoiseMatrix)
                obj.checkSysNoise(dimState, dimNoise);
                
                predictedStates = predictedStates + noiseSamples;
            else
                obj.checkSysNoiseMatrix(dimState, dimNoise);
                
                predictedStates = predictedStates + obj.sysNoiseMatrix * noiseSamples;
            end
            
            if ~isempty(obj.sysInput)
                obj.checkSysInput(dimState);
                
                predictedStates = bsxfun(@plus, predictedStates, obj.sysInput);
            end
        end
        
        function [predictedStateMean, ...
                  predictedStateCov] = analyticPredictedMoments(obj, stateMean, stateCov)
            [noiseMean, noiseCov] = obj.noise.getMeanAndCovariance();
            dimState = size(stateMean, 1);
            dimNoise = size(noiseMean, 1);
            
            if isempty(obj.sysMatrix)
                predictedStateMean = stateMean;
                predictedStateCov  = stateCov;
            else
                obj.checkSysMatrix(dimState);
                
                predictedStateMean = obj.sysMatrix * stateMean;
                predictedStateCov  = obj.sysMatrix * stateCov * obj.sysMatrix';
            end
            
            if isempty(obj.sysNoiseMatrix)
                obj.checkSysNoise(dimState, dimNoise);
                
                predictedStateMean = predictedStateMean + noiseMean;
                predictedStateCov  = predictedStateCov  + noiseCov;
            else
                obj.checkSysNoiseMatrix(dimState, dimNoise);
                
                predictedStateMean = predictedStateMean + obj.sysNoiseMatrix * noiseMean;
                predictedStateCov  = predictedStateCov + obj.sysNoiseMatrix * noiseCov * obj.sysNoiseMatrix';
            end
            
            if ~isempty(obj.sysInput)
                obj.checkSysInput(dimState);
                
                predictedStateMean = predictedStateMean + obj.sysInput;
            end
        end
    end
    
    methods (Access = 'private')
        function checkSysMatrix(obj, dimState)
            dimSysMatrix = size(obj.sysMatrix, 1);
            
            if dimState ~= dimSysMatrix
                error('LinearSystemModel:IncompatibleSystemMatrix', ...
                      'System state and system matrix with incompatible dimensions.');
            end
        end
        
        function checkSysNoiseMatrix(obj, dimState, dimNoise)
            [sysNoiseMatrixRows, sysNoiseMatrixCols] = size(obj.sysNoiseMatrix);
            
            if dimState ~= sysNoiseMatrixRows
                error('LinearSystemModel:IncompatibleSystemNoiseMatrix', ...
                      'System state and system noise matrix with incompatible dimensions.');
            end
            
            if dimNoise ~= sysNoiseMatrixCols
                error('LinearSystemModel:IncompatibleSystemNoiseMatrix', ...
                      'System noise and system noise matrix with incompatible dimensions.');
            end
        end
        
        function checkSysInput(obj, dimState)
            dimSysInput = size(obj.sysInput, 1);
            
            if dimState ~= dimSysInput
                error('LinearSystemModel:IncompatibleSystemInput', ...
                      'System state and system intput with incompatible dimensions.');
            end
        end
        
        function checkSysNoise(~, dimState, dimNoise)
            if dimState ~= dimNoise
                error('LinearSystemModel:IncompatibleSystemNoise', ...
                      'System state and system noise with incompatible dimensions.');
            end
        end
    end
    
    properties (SetAccess = 'private', GetAccess = 'public')
        % System matrix.
        sysMatrix;
        
        % System input vector.
        sysInput;
        
        % System noise matrix.
        sysNoiseMatrix;
    end
end