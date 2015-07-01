
classdef MixedNoiseSystemModel < handle
    % Abstract base class for system models corrupted by a mixture additive and arbitrary noise.
    %
    % MixedNoiseSystemModel Methods:
    %   setNoise         - Set the non-additive system noise.
    %   setAdditiveNoise - Set the additive system noise.
    %   systemEquation   - The system equation.
    %   derivative       - Compute the derivative of the implemented system equation.
    %   simulate         - Simulate the temporal evolution for a given system state.
    
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
        function setNoise(obj, noise)
            % Set the non-additive system noise.
            %
            % Parameters:
            %   >> noise (Subclass of Distribution or cell array containing subclasses of Distribution)
            %      The new non-additive system noise.
            
            if Checks.isClass(noise, 'Distribution')
                obj.noise = noise;
            else
                obj.noise = JointDistribution(noise);
            end
        end
        
        function setAdditiveNoise(obj, additiveNoise)
            % Set the additive system noise.
            %
            % Parameters:
            %   >> additiveNoise (Subclass of Distribution or cell array containing subclasses of Distribution)
            %      The new additive system noise.
            
            if Checks.isClass(additiveNoise, 'Distribution')
                obj.additiveNoise = additiveNoise;
            else
                obj.additiveNoise = JointDistribution(additiveNoise);
            end
        end
        
        function [stateJacobian, ...
                  noiseJacobian] = derivative(obj, nominalState, nominalNoise)
            % Compute the derivative of the implemented system equation.
            %
            % By default, the Jacobians are computed using a difference quotient.
            %
            % Mainly used by the EKF.
            %
            % Parameters:
            %   >> nominalState (Column vector)
            %      The nominal system state vector to linearize the system equation.
            %
            %   >> nominalNoise (Column vector)
            %      The nominal system noise vector to linearize the system equation.
            %
            % Returns:
            %   << stateJacobian (Square matrix)
            %      The Jacobian of the state variables.
            %
            %   << noiseJacobian (Matrix)
            %      The Jacobian of the noise variables.
            
            [stateJacobian, ...
             noiseJacobian] = Utils.diffQuotientStateAndNoise(@obj.systemEquation, ...
                                                              nominalState, nominalNoise);
        end
        
        function predictedState = simulate(obj, state)
            % Simulate the temporal evolution for a given system state.
            %
            % Parameters:
            %   >> state (Column vector)
            %      The system state to predict.
            %
            % Returns:
            %   << predictedState (Column vector)
            %      The simulated temporal system state evolution.
            
            if ~Checks.isColVec(state)
                error('MixedNoiseSystemModel:InvalidSystemState', ...
                      'state must be a column vector.');
            end
            
            noiseSample = obj.noise.drawRndSamples(1);
            addNoiseSample = obj.additiveNoise.drawRndSamples(1);
            
            predictedState = obj.systemEquation(state, noiseSample) + addNoiseSample;
        end
    end
    
    methods (Abstract)
        % The system equation.
        %
        % Parameters:
        %   >> stateSamples (Matrix)
        %      L column-wise arranged state samples.
        %
        %   >> noiseSamples (Matrix)
        %      L column-wise arranged noise samples.
        %
        % Returns:
        %   << predictedStates (Matrix)
        %      L column-wise arranged predicted state samples.
        predictedStates = systemEquation(obj, stateSamples, noiseSamples);
    end
    
    properties (SetAccess = 'private', GetAccess = 'public')
        % The non-additive system noise.
        noise;
        
        % The additive system noise.
        additiveNoise;
    end
end
