
classdef EnKF < Filter
    % The Ensemble Kalman Filter (EnKF).
    %
    % EnKF Methods:
    %   EnKF             - Class constructor.
    %   getName          - Get the filter name / description.
    %   setColor         - Set the filter color / plotting properties.
    %   getColor         - Get the current filter color / plotting properties.
    %   setState         - Set the system state.
    %   getState         - Get the current system state.
    %   getStateDim      - Get the dimension of the current system state.
    %   predict          - Perform a time update (prediction step).
    %   update           - Perform a measurement update (filter step) using the given measurement(s).
    %   getPointEstimate - Get a point estimate of the current system state.
    %   setEnsembleSize  - Set the size of the ensemble (i.e., the number of samples).
    %   getEnsembleSize  - Get the current ensemble size of the filter.
    %   getEstimate      - Get the current state estimate (i.e., the filter ensemble)
    
    % Literature:
    %   S. Gillijns, O. Barrero Mendoza, J. Chandrasekar, B. L. R. De Moor, D. S. Bernstein, and A. Ridley,
    %   What Is the Ensemble Kalman Filter and How Well Does It Work?,
    %   Proceedings of the 2006 American Control Conference (ACC 2006),
    %   Minneapolis, USA, June 2006.
    %
    %   Geir Evensen,
    %   Sequential data assimilation with a nonlinear quasi-geostrophic
    %   model using Monte Carlo methods to forecast error statistics,
    %   Journal of Geophysical Research: Oceans vol. 99 C5, pages 10143-10162, 1994
    
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
        function obj = EnKF(name)
            % Class constructor.
            %
            % Parameters:
            %   >> name (Char)
            %      An appropriate filter name / description of the implemented
            %      filter. The Filter subclass should set this during its
            %      construction to a meaningful default value (e.g., 'EKF'),
            %      or the user should specify an appropriate name (e.g., 
            %      'PF (10k Particles)').
            %
            %      Default name: 'EnKF'.
            %
            % Returns:
            %   << obj (AnalyticKF)
            %      A new AnalyticKF instance.
            
            if nargin < 1
                name = 'EnKF';
            end
            
            % Call superclass constructor
            obj = obj@Filter(name);
            
            obj.dimState = 0;
            obj.ensemble = [];
            
            obj.setEnsembleSize(1000);
        end
		
        function setEnsembleSize(obj, ensembleSize)
            % Set the size of the ensemble (i.e., the number of samples).
            % 
            % By default, 1000 ensemble members will be used.
            %
            % Parameters:
            %   >> ensembleSize (Positive scalar)
            %      The number of ensemble members used by the filter.
            
            if ~Checks.isPosScalar(ensembleSize)
                obj.error('InvalidEnsembleSize', ...
                          'ensembleSize must be a positive scalar.');
            end
            
            ensembleSize = ceil(ensembleSize);
            
            if isempty(obj.ensemble)
                obj.ensembleSize = ensembleSize;
            else
                obj.resample(ensembleSize);
            end
        end
		
        function ensembleSize = getEnsembleSize(obj)
            % Get the current ensemble size of the filter.
            %
            % Returns:
            %   << ensembleSize (Positive scalar)
            %      The current ensemble size used by he filter.
            
            ensembleSize = obj.ensembleSize;
        end
        
        function setState(obj, state)
            if ~Checks.isClass(state, 'Distribution')
                obj.error('UnsupportedSystemState', ...
                          'state must be a subclass of Distribution.');
            end
            
            obj.ensemble = state.drawRndSamples(obj.ensembleSize);
            
            obj.dimState = state.getDimension();
        end
        
        function state = getState(obj)
            state = DiracMixture(obj.ensemble);
        end
        
        function [pointEstimate, uncertainty] = getPointEstimate(obj)
            % Get a point estimate of the current system state.
            %
            % Returns:
            %   << pointEstimate (Column vector)
            %      Mean of the current ensemble.
            %
            %   << uncertainty (Positive definite matrix)
            %      Covariance of the current ensemble.
            
            if nargout == 1
                pointEstimate = Utils.getMeanAndCov(obj.ensemble);
            else
                [pointEstimate, uncertainty] = Utils.getMeanAndCov(obj.ensemble);
            end
        end
    end
    
    methods (Access = 'protected')
        function performPrediction(obj, sysModel)
            if Checks.isClass(sysModel, 'SystemModel')
                obj.predictArbitraryNoise(sysModel);
            elseif Checks.isClass(sysModel, 'AdditiveNoiseSystemModel')
                obj.predictAdditiveNoise(sysModel);
            elseif Checks.isClass(sysModel, 'MixedNoiseSystemModel')
                obj.predictMixedNoise(sysModel);
            else
                obj.errorSysModel('System model', ...
                                  'Additive noise system model', ...
                                  'Mixed noise system model');
            end
        end
        
        function predictArbitraryNoise(obj, sysModel)
            % Sample system noise
            noise = sysModel.noise.drawRndSamples(obj.ensembleSize);
            
            % Propagate ensemble and noise through system equation 
           	predictedEnsemble = sysModel.systemEquation(obj.ensemble, noise);
            
            % Check predicted ensemble
            obj.checkPredictedStateSamples(predictedEnsemble, obj.ensembleSize);
         	
            % Save new state estimate
            obj.ensemble = predictedEnsemble;
        end
        
        function predictAdditiveNoise(obj, sysModel)
            % Sample additive system noise
            noise = sysModel.noise.drawRndSamples(obj.ensembleSize);
         	
            dimNoise = size(noise, 1);
            
            obj.checkAdditiveSysNoise(dimNoise);
            
            % Propagate ensemble and noise through system equation 
           	predictedEnsemble = sysModel.systemEquation(obj.ensemble);
            
            % Check predicted ensemble
            obj.checkPredictedStateSamples(predictedEnsemble, obj.ensembleSize);
         	
            % Save new state estimate
            obj.ensemble = predictedEnsemble + noise;
        end
        
        function predictMixedNoise(obj, sysModel)
            % Sample system noise
            noise = sysModel.noise.drawRndSamples(obj.ensembleSize);
            
            % Sample additive system noise
            addNoise = sysModel.additiveNoise.drawRndSamples(obj.ensembleSize);
            
            dimAddNoise = size(addNoise, 1);
            
            obj.checkAdditiveSysNoise(dimAddNoise);
            
            % Propagate ensemble and noise through system equation 
           	predictedEnsemble = sysModel.systemEquation(obj.ensemble, noise);
         	
            % Check predicted ensemble
            obj.checkPredictedStateSamples(predictedEnsemble, obj.ensembleSize);
         	
            % Save new state estimate
            obj.ensemble = predictedEnsemble + addNoise;
        end
        
        function performUpdate(obj, measModel, measurements)
            if Checks.isClass(measModel, 'MeasurementModel')
                obj.updateArbitraryNoise(measModel, measurements);
            elseif Checks.isClass(measModel, 'AdditiveNoiseMeasurementModel')
                obj.updateAdditiveNoise(measModel, measurements);
            elseif Checks.isClass(measModel, 'MixedNoiseMeasurementModel')
                obj.updateMixedNoise(measModel, measurements);
            else
                obj.errorMeasModel('Measurement model', ...
                                   'Additive noise measurement model', ...
                                   'Mixed noise measurement model');
            end
        end
        
     	function updateArbitraryNoise(obj, measModel, measurements)
            [dimMeas, numMeas] = size(measurements);
            
        	measSamples = nan(dimMeas * numMeas, obj.ensembleSize);
            a = 1;
            
            for i = 1:numMeas
                b = i * dimMeas;
                
                % Sample measurement noise
                noiseSamples = measModel.noise.drawRndSamples(obj.ensembleSize);
                
                % Propagate ensemble and noise through measurement equation
                meas = measModel.measurementEquation(obj.ensemble, noiseSamples);
                
                % Check computed measurements
                obj.checkComputedMeasurements(meas, dimMeas, obj.ensembleSize);
                
                measSamples(a:b, :) = meas;
                
                a = b + 1;
            end
            
            obj.updateEnsemble(measurements(:), measSamples);
        end
        
        function updateAdditiveNoise(obj, measModel, measurements)
            [dimMeas, numMeas] = size(measurements);
            dimNoise = measModel.noise.getDimension();
            
            obj.checkAdditiveMeasNoise(dimMeas, dimNoise);
            
        	measSamples = nan(dimMeas * numMeas, obj.ensembleSize);
            a = 1;
            
            for i = 1:numMeas
                b = i * dimMeas;
                
                % Propagate ensemble and noise through measurement equation
                meas = measModel.measurementEquation(obj.ensemble);
                
                % Check computed measurements
                obj.checkComputedMeasurements(meas, dimMeas, obj.ensembleSize);
                
                % Sample additive measurement noise
                addNoiseSamples = measModel.noise.drawRndSamples(obj.ensembleSize); 
                
                measSamples(a:b, :) = meas + addNoiseSamples;
                
                a = b + 1;
            end
            
            obj.updateEnsemble(measurements(:), measSamples);
        end
        
        function updateMixedNoise(obj, measModel, measurements)
            [dimMeas, numMeas] = size(measurements);
            dimAddNoise = measModel.additiveNoise.getDimension();
            
            obj.checkAdditiveMeasNoise(dimMeas, dimAddNoise);
            
        	measSamples = nan(dimMeas * numMeas, obj.ensembleSize);
            a = 1;
            
            for i = 1:numMeas
                b = i * dimMeas;
                
                % Sample measurement noise
                noiseSamples = measModel.noise.drawRndSamples(obj.ensembleSize);
                
                % Propagate ensemble and noise through measurement equation
                meas = measModel.measurementEquation(obj.ensemble, noiseSamples);
                
                % Check computed measurements
                obj.checkComputedMeasurements(meas, dimMeas, obj.ensembleSize);
                
                % Sample additive measurement noise
                addNoiseSamples = measModel.additiveNoise.drawRndSamples(obj.ensembleSize); 
                
                measSamples(a:b, :) = meas + addNoiseSamples;
                
                a = b + 1;
            end
            
            obj.updateEnsemble(measurements(:), measSamples);
        end
        
        function updateEnsemble(obj, measurement, measSamples)
            ensembleMean = sum(obj.ensemble, 2) / obj.ensembleSize;
            
            [~, measCov, ensembleMeasCrossCov] = Utils.getMeanCovAndCrossCov(ensembleMean, ...
                                                                             obj.ensemble, ...
                                                                             measSamples);
          	
            [~, isNonPosDef] = chol(measCov);
            
            if isNonPosDef
                obj.warnIgnoreMeas('Measurement covariance matrix is not positive definite.');
                return;
            end
            
            % Compute Kalman gain
            kalmanGain = ensembleMeasCrossCov / measCov;
            
            % Compute memberwise innovation
            innovation = bsxfun(@minus, measurement, measSamples);
            
            % Update ensemble
            obj.ensemble = obj.ensemble + kalmanGain * innovation;
        end
        
        function resample(obj, ensembleSize)
            idx = randi(obj.ensembleSize, 1, ensembleSize);
            
            obj.ensembleSize = ensembleSize;
            obj.ensemble     = obj.ensemble(:, idx);
        end
    end
    
    properties (Access = 'private')
        % The actual ensemble (set of samples)
        ensemble;
        
        % The number of ensemble members
        ensembleSize;
    end
end